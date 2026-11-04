import 'dart:math';

import '../../core/services.dart';
import '../../engine/mastery.dart';
import '../../engine/model.dart';
import '../../engine/period.dart';

// Pure logic behind the insight screens: quiz outcomes and re-teaching, the topic catalogue,
// exam readiness, the next-period plan and worksheet picks. No widgets here, so it is unit-tested.

/// The class's result on one quiz block, from the answers recorded while it ran.
class QuizOutcome {
  QuizOutcome({required this.total, required this.correct, required this.missed, required this.wrongRolls, required this.rightRolls});
  final int total, correct;

  /// Question ids answered wrong, in order, once each.
  final List<String> missed;

  /// Roll numbers that answered wrong / right (roll call only).
  final Set<int> wrongRolls, rightRolls;

  double get score => total == 0 ? 1 : correct / total;

  /// Below this share right, the board offers (or in Self-Learning, runs) a re-teach.
  static const threshold = 0.6;
  bool get needsReteach => total > 0 && score < threshold;

  /// The answers to [questionIds] in a session log's answers (the last answer per question
  /// counts, so going back over a quiz does not count twice).
  factory QuizOutcome.from(List<Map<String, dynamic>> answers, List<String> questionIds) {
    final ids = questionIds.toSet();
    final last = <String, Map<String, dynamic>>{};
    final wrong = <int>{}, right = <int>{};
    for (final a in answers) {
      final q = a['questionId'] as String?;
      if (q == null || !ids.contains(q)) continue;
      last[q] = a;
    }
    for (final a in last.values) {
      final roll = a['roll'] as int?;
      if (roll == null) continue;
      (a['correct'] == true ? right : wrong).add(roll);
    }
    final missed = [
      for (final q in questionIds)
        if (last[q] != null && last[q]!['correct'] != true) q,
    ];
    return QuizOutcome(
      total: last.length,
      correct: last.values.where((a) => a['correct'] == true).length,
      missed: missed.toSet().toList(),
      wrongRolls: wrong,
      rightRolls: right.difference(wrong),
    );
  }
}

/// Block types that explain a topic in a different way from talk and text.
const approachTypes = [BlockType.simulation, BlockType.virtualLab, BlockType.model3d, BlockType.interactive, BlockType.whiteboard, BlockType.example];

/// The block to re-teach with: a different approach from the same lesson, preferring a type
/// the class has not seen this session, then a block not yet shown, then any approach block;
/// a concept or trick block when the lesson has no other approach. Null when there is nothing.
Block? reteachBlock(Lesson lesson, Iterable<String> shownIds) {
  final shown = shownIds.toSet();
  final shownTypes = {
    for (final b in lesson.blocks)
      if (shown.contains(b.id)) b.type,
  };
  for (final keep in <bool Function(Block)>[(b) => !shownTypes.contains(b.type), (b) => !shown.contains(b.id), (_) => true]) {
    for (final t in approachTypes) {
      final hit = lesson.blocks.where((b) => b.type == t && keep(b)).firstOrNull;
      if (hit != null) return hit;
    }
  }
  return lesson.blocks.where((b) => b.type == BlockType.trick).firstOrNull ?? lesson.blocks.where((b) => b.type == BlockType.concept).firstOrNull;
}

/// Pairs for peer teaching after a quiz: the board's stuck/strong buddies on the topic, plus
/// roll numbers who just got it wrong, each with someone who has it (strong on the topic, or
/// right in this quiz). Roll numbers only.
List<(int stuck, int buddy)> pairUp(MasteryStore m, String topicId, QuizOutcome? o) {
  final pairs = [...m.buddies(topicId)];
  final paired = {for (final p in pairs) p.$1};
  final helpers = [
    ...m.strong(topicId),
    for (final r in o?.rightRolls ?? const <int>{})
      if (!m.strong(topicId).contains(r)) r,
  ];
  final stuck = (o?.wrongRolls ?? const <int>{}).where((r) => !paired.contains(r) && !helpers.contains(r)).toList()..sort();
  if (helpers.isEmpty) return pairs;
  for (var i = 0; i < stuck.length; i++) {
    pairs.add((stuck[i], helpers[(i + pairs.length) % helpers.length]));
  }
  return pairs;
}

/// Seconds a Self-Learning period can give to one automatic re-teach of [block]: its usual
/// time, capped by what is left after the remaining steps and a minute of homework. Zero when
/// there is not time for a useful one (under 45 s).
int reteachSeconds(Block block, {required int secondsLeft, required int remainingPlanned}) {
  final want = min(PeriodPlanner.estimate(block) + 8, 240);
  final room = secondsLeft - remainingPlanned - 60;
  final s = min(want, room);
  return s < PeriodPlanner.minMediaSeconds ? 0 : s;
}

/// A short revision of a lesson (about [seconds] long): its recap, trick, one worked or drawn
/// explanation and its class quiz, as many as fit, in lesson order. Never empty for a lesson
/// with blocks.
List<Block> reviseBlocks(Lesson lesson, {int seconds = 300}) {
  final pick = <Block>{};
  var used = 0;
  for (final t in [BlockType.recap, BlockType.trick, BlockType.whiteboard, BlockType.example, BlockType.classQuiz, BlockType.concept]) {
    final b = lesson.blocks.where((b) => b.type == t).firstOrNull;
    if (b == null) continue;
    final e = PeriodPlanner.estimate(b);
    if (pick.isNotEmpty && used + e > seconds) continue;
    pick.add(b);
    used += e;
  }
  if (pick.isEmpty && lesson.blocks.isNotEmpty) pick.add(lesson.blocks.first);
  return [for (final b in lesson.blocks) if (pick.contains(b)) b];
}

/// One topic of this section's syllabus, with where it sits.
class TopicRef {
  TopicRef(this.topic, this.chapter);
  final Topic topic;
  final Chapter chapter;
  String get id => topic.id;
  String get subject => chapter.subject;
  String get year => chapter.year;
}

/// Every topic this section studies: its subjects, its year first then the other, as its
/// curriculum teaches them.
List<TopicRef> sectionTopics(Services s) {
  final years = [s.config.year, s.config.year == 'puc1' ? 'puc2' : 'puc1'];
  return [
    for (final y in years)
      for (final subj in s.subjects)
        for (final ch in s.chapters(subj, y))
          for (final t in ch.topicsFor(s.config.board)) TopicRef(t, ch),
  ];
}

/// The chapter id of a topic id (`<chapter>.t3`).
String chapterOf(String topicId) {
  final i = topicId.lastIndexOf('.');
  return i < 0 ? topicId : topicId.substring(0, i);
}

// ---------------------------------------------------------------------------------------------
// Exam readiness

enum Exam {
  kcet('KCET', 'KCET', ['physics', 'chemistry', 'maths', 'biology']),
  comedk('COMEDK', 'COMEDK', ['physics', 'chemistry', 'maths']),
  neet('NEET', 'NEET', ['physics', 'chemistry', 'biology']),
  jeeMain('JEE', 'JEE Main', ['physics', 'chemistry', 'maths']),
  jeeAdv('JEE_ADV', 'JEE Advanced', ['physics', 'chemistry', 'maths']),
  cuet('CUET', 'CUET', null),
  board('PUC', 'PUC board', null);

  const Exam(this.tag, this.label, this.subjects);

  /// The tag questions carry in packs (`exams`).
  final String tag;
  final String label;

  /// The exam's subjects; null = every subject the section studies.
  final List<String>? subjects;

  /// The board exam follows the section's curriculum (PUC, CBSE or ISC).
  String tagFor(String curriculum) => this != board ? tag : switch (curriculum) { 'cbse' => 'CBSE', 'isc' => 'ISC', _ => tag };
  String labelFor(String curriculum) => this != board ? label : switch (curriculum) { 'cbse' => 'CBSE board', 'isc' => 'ISC board', _ => label };
}

enum Band { ready, onTrack, needsWork, noData }

/// An indicative readiness estimate: the average mastery over the exam's topics that have
/// answers, and how much of the exam's syllabus has answers at all. Not a rank prediction.
class Readiness {
  Readiness({required this.exam, required this.score, required this.coverage, required this.evidenced, required this.topics});
  final Exam exam;

  /// 0..1 average over topics with answers (weighted by how many answers each rests on).
  final double score;

  /// Share of the exam's topics with at least one answer.
  final double coverage;
  final int evidenced, topics;

  // The same rules as the college dashboard (services/api/src/outcomes.ts), so a section reads
  // the same band on the board and on the principal's screen.
  static const minTopics = 3, minCoverage = 0.2, readyCoverage = 0.6;

  Band get band {
    if (topics == 0 || evidenced < minTopics || coverage < minCoverage) return Band.noData;
    if (score >= 0.75 && coverage >= readyCoverage) return Band.ready;
    if (score >= 0.5) return Band.onTrack;
    return Band.needsWork;
  }
}

/// Which topics count for which exam, worked out once per screen from the installed packs.
class ExamScope {
  ExamScope._(this.curriculum, this.byExam);
  final String curriculum;
  final Map<Exam, List<String>> byExam;

  /// Exams this section can sit (at least one of their subjects is taught here), in order.
  List<Exam> get exams => [for (final e in Exam.values) if (byExam[e]?.isNotEmpty ?? false) e];

  /// A topic is in an exam when its subject is, and, where its chapter has a pack, some
  /// question on the topic is tagged for that exam (a topic with no questions follows its pack).
  factory ExamScope.of(Services s, {List<TopicRef>? topics}) {
    final all = topics ?? sectionTopics(s);
    final cur = s.config.board;
    final tagsByTopic = <String, Set<String>>{}, tagsByPack = <String, Set<String>>{};
    for (final p in s.store.packs) {
      final pt = tagsByPack[p.chapter.id] = <String>{};
      for (final q in p.questions.values) {
        pt.addAll(q.exams);
        if (q.topicId != null) (tagsByTopic[q.topicId!] ??= <String>{}).addAll(q.exams);
      }
    }
    final out = <Exam, List<String>>{};
    for (final e in Exam.values) {
      final tag = e.tagFor(cur);
      out[e] = [
        for (final t in all)
          if ((e.subjects?.contains(t.subject) ?? true) &&
              (!tagsByPack.containsKey(t.chapter.id) || (tagsByTopic[t.id]?.contains(tag) ?? tagsByPack[t.chapter.id]!.contains(tag))))
            t.id,
      ];
    }
    return ExamScope._(cur, out);
  }

  /// Readiness for the class (every answer) or one roll number.
  Readiness readiness(MasteryStore m, Exam e, {int? roll}) {
    final ts = byExam[e] ?? const [];
    var sum = 0.0, w = 0.0, ev = 0;
    for (final t in ts) {
      final est = roll == null ? m.classTopic(t) : m.rollTopic(roll, t);
      if (est == null || est.n == 0) continue;
      ev++;
      final wt = min(est.n, 5).toDouble();
      sum += est.p * wt;
      w += wt;
    }
    return Readiness(exam: e, score: w == 0 ? 0 : sum / w, coverage: ts.isEmpty ? 0 : ev / ts.length, evidenced: ev, topics: ts.length);
  }
}

// ---------------------------------------------------------------------------------------------
// Trend

/// Share right in one week (weeks start on Monday).
class WeekPoint {
  WeekPoint(this.weekStart, this.right, this.total);
  final DateTime weekStart;
  final int right, total;
  double get score => total == 0 ? 0 : right / total;
}

/// The last [weeks] weeks with answers from [roll] (or the whole class when null), oldest first.
List<WeekPoint> weeklyTrend(Iterable<Response> rs, {int? roll, int weeks = 8}) {
  final byWeek = <DateTime, List<int>>{};
  for (final r in rs) {
    if (roll != null && r.roll != roll) continue;
    final d = r.at.toLocal();
    final start = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
    final v = byWeek.putIfAbsent(start, () => [0, 0]);
    if (r.correct) v[0]++;
    v[1]++;
  }
  final keys = byWeek.keys.toList()..sort();
  return [for (final k in keys.skip(max(0, keys.length - weeks))) WeekPoint(k, byWeek[k]![0], byWeek[k]![1])];
}

// ---------------------------------------------------------------------------------------------
// Worksheets

/// Up to [count] questions weighted to weak topics: the class's (or [roll]'s) weakest topics get
/// more questions (weight 1 − estimate). With no weak topics yet, the topics taught most
/// recently. Questions come from the installed packs; [rnd] makes the pick repeatable.
List<Question> pickWorksheet(Services s, {int? roll, int count = 10, Random? rnd}) {
  final m = s.mastery, r = rnd ?? Random();
  List<String> weak;
  if (roll == null) {
    weak = m.weakTopics(n: 6);
  } else {
    final mine = m.rollTopics(roll).entries.where((e) => e.value.p < 0.75).toList()..sort((a, b) => a.value.p.compareTo(b.value.p));
    weak = [for (final e in mine.take(6)) e.key];
    if (weak.isEmpty) weak = m.weakTopics(n: 6);
  }
  final topics = [...weak];
  for (final t in s.config.taught.reversed) {
    if (topics.length >= 6) break;
    if (!topics.contains(t)) topics.add(t);
  }
  double weight(String t) {
    final e = roll == null ? m.classTopic(t) : (m.rollTopic(roll, t) ?? m.classTopic(t));
    return 1.1 - (e?.p ?? 0.5);
  }

  final pools = <String, List<Question>>{};
  for (final t in topics) {
    final pack = s.store.byChapter(chapterOf(t)) ?? s.lessonFor(t)?.pack;
    final qs = pack?.topicQuestions(t) ?? <Question>[];
    if (qs.isNotEmpty) pools[t] = qs..shuffle(r);
  }
  if (pools.isEmpty) return const [];
  final total = pools.keys.fold(0.0, (a, t) => a + weight(t));
  final quota = {for (final t in pools.keys) t: max(1, (count * weight(t) / total).round())};
  final out = <Question>[];
  final taken = {for (final t in pools.keys) t: 0};
  // Weakest first, one at a time: up to each topic's quota, then from whatever is left.
  final order = pools.keys.toList()..sort((a, b) => weight(b).compareTo(weight(a)));
  for (final capped in [true, false]) {
    var progress = true;
    while (out.length < count && progress) {
      progress = false;
      for (final t in order) {
        if (out.length >= count) break;
        if (pools[t]!.isEmpty || (capped && taken[t]! >= quota[t]!)) continue;
        out.add(pools[t]!.removeAt(0));
        taken[t] = taken[t]! + 1;
        progress = true;
      }
    }
  }
  return out;
}

/// The answer to show in a key: option letter(s) or the number.
String answerKey(Question q) {
  if (q.isNumeric) {
    final v = q.numericAnswer;
    if (v == null) return '-';
    final s = v == v.roundToDouble() ? v.round().toString() : v.toString();
    return q.tolerance != null && q.tolerance! > 0 ? '$s (± ${q.tolerance})' : s;
  }
  final letters = (q.correctSet.toList()..sort()).map((i) => String.fromCharCode(65 + i));
  return letters.join(', ');
}

/// Inline `$…$` LaTeX made readable as plain text for paper.
String plainMath(String s) {
  if (!s.contains(r'$')) return s;
  var t = s.replaceAll(r'$', '');
  t = t.replaceAllMapped(RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'), (m) => '(${m[1]})/(${m[2]})');
  t = t.replaceAllMapped(RegExp(r'\\sqrt\{([^{}]*)\}'), (m) => '√(${m[1]})');
  const words = {r'\times': '×', r'\cdot': '·', r'\pi': 'π', r'\theta': 'θ', r'\alpha': 'α', r'\beta': 'β', r'\lambda': 'λ', r'\mu': 'μ', r'\omega': 'ω', r'\Delta': 'Δ', r'\leq': '≤', r'\geq': '≥', r'\le': '≤', r'\ge': '≥', r'\neq': '≠', r'\infty': '∞', r'\rightarrow': '→', r'\to': '→', r'\pm': '±', r'\degree': '°', r'\circ': '°', r'\,': ' ', r'\;': ' ', r'\left': '', r'\right': ''};
  for (final e in words.entries) {
    t = t.replaceAll(e.key, e.value);
  }
  t = t.replaceAllMapped(RegExp(r'\^\{([^{}]*)\}'), (m) => '^(${m[1]})').replaceAllMapped(RegExp(r'_\{([^{}]*)\}'), (m) => '_${m[1]}');
  t = t.replaceAllMapped(RegExp(r'\\(text|mathrm|mathbf)\{([^{}]*)\}'), (m) => m[2]!);
  return t.replaceAll(RegExp(r'[{}]'), '');
}
