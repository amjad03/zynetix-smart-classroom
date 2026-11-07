import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../core/services.dart';
import '../../core/strings.dart' show subjectName, yearLabel;
import '../../engine/model.dart';
import '../classroom/class_data.dart';
import 'now.dart';
import 'school.dart';

/// What the class tools carry in the app itself: entrance-exam paper patterns and the coding
/// lab's programs, each with a recorded run (assets/classroom/).
class ClassContent {
  ClassContent(this.mocks, this.programs);
  final List<MockPattern> mocks;
  final List<Program> programs;

  static ClassContent? _cached;
  static ClassContent get empty => ClassContent(const [], const []);

  static Future<ClassContent> load([AssetBundle? bundle]) async {
    if (_cached != null) return _cached!;
    final b = bundle ?? rootBundle;
    try {
      final p = jsonDecode(await b.loadString('assets/classroom/patterns.json')) as Map<String, dynamic>;
      final c = jsonDecode(await b.loadString('assets/classroom/programs.json')) as Map<String, dynamic>;
      return _cached = ClassContent(
        [for (final m in (p['mocks'] as List)) MockPattern.fromJson(m as Map<String, dynamic>)],
        [for (final m in (c['programs'] as List)) Program.fromJson(m as Map<String, dynamic>)],
      );
    } catch (_) {
      return empty;
    }
  }
}

/// A Python program for the coding lab, with the output it prints (its recorded run).
class Program {
  Program(this.file, this.sample);
  final String file;
  final CodeSample sample;
  factory Program.fromJson(Map<String, dynamic> j) => Program(
    j['file'] as String,
    CodeSample(L10n.of(j['title']), L10n.of(j['chapter']), L10n.of(j['task']), j['code'] as String, [for (final o in j['output'] as List) '$o'], const []),
  );
}

/// The chapters of [subject] that have a pack on this board, this section's year first.
List<InstalledPack> subjectPacks(Services s, String subject) => [
  for (final y in [s.config.year, s.config.year == 'puc1' ? 'puc2' : 'puc1'])
    for (final c in s.chapters(subject, y)) ?s.store.byChapter(c.id),
];

ClassQuestion classQuestion(Question q, L10n chapter) => ClassQuestion(
  id: q.id,
  chapter: chapter,
  exams: q.exams,
  stem: q.stem,
  options: q.options,
  answer: q.answer,
  steps: q.solution.isNotEmpty ? q.solution : [?q.explanation],
  idealTime: switch (q.difficulty) {
    'easy' => 45,
    'hard' => 120,
    _ => 75,
  },
  difficulty: switch (q.difficulty) {
    'easy' => 1,
    'hard' => 3,
    _ => 2,
  },
);

/// The formulas a chapter's lessons write on the board (concept blocks with a formula).
FormulaSheetData formulaSheet(InstalledPack p, String board) {
  final items = <FormulaItem>[];
  final seen = <String>{};
  for (final t in p.chapter.topicsFor(board)) {
    for (final b in p.lessons[t.id]?.blocks ?? const <Block>[]) {
      final tex = b.raw['formula'];
      if (b.type != BlockType.concept || tex is! String || tex.trim().isEmpty || !seen.add(tex)) continue;
      items.add(FormulaItem(L10n.maybe(b.raw['title']) ?? t.title, tex, L10n.maybe(b.raw['body']) ?? const L10n('')));
    }
  }
  return FormulaSheetData(p.chapter.title, items);
}

/// The class tools' data for [subject], from the installed packs and this board's records.
ClassSamples buildSamples(Services s, ClassContent content, {String? subject}) {
  final now = classNow(s);
  final subj = subject ?? now.subject;
  final packs = subjectPacks(s, subj);
  final school = s.school..rollCount = s.config.rollCount;
  final board = s.config.board;
  final rolls = s.config.rollCount;
  final taught = s.config.taught.toSet();

  // The chapter in hand first, then the rest in syllabus order.
  final current = now.subject == subj && now.pack != null ? now.pack! : packs.firstOrNull;
  final ordered = [?current, for (final p in packs) if (p != current) p];

  bool usable(Question q) => q.options.length >= 2 && !q.isMulti && !q.isNumeric;
  final questions = <ClassQuestion>[];
  for (final p in ordered.take(3)) {
    final qs = p.questions.values.where(usable).toList();
    // The topic in hand first.
    qs.sort((a, b) => (a.topicId == now.lesson?.topicId ? 0 : 1).compareTo(b.topicId == now.lesson?.topicId ? 0 : 1));
    questions.addAll(qs.take(12).map((q) => classQuestion(q, p.chapter.title)));
    if (questions.length >= 20) break;
  }

  final formulas = [
    for (final p in ordered.where((p) => p == current || p.chapter.topicsFor(board).any((t) => taught.contains(t.id))).take(6))
      if (formulaSheet(p, board) case final f when f.items.isNotEmpty) f,
  ];
  if (formulas.isEmpty) {
    for (final p in ordered) {
      final f = formulaSheet(p, board);
      if (f.items.isNotEmpty) {
        formulas.add(f);
        break;
      }
    }
  }

  // The plan: every chapter of the year, about a week per two topics, worked back from the exam.
  final year = s.config.year;
  final yearChapters = s.chapters(subj, year);
  final today = s.clock();
  final ay = today.month >= 6 ? today.year : today.year - 1;
  final plan = ClassPlanData(
    exam: L10n(school.examName.isEmpty ? '${yearLabel(year, board, Lang.en)} annual exam · ${subjectName(subj, Lang.en)}' : school.examName, school.examName.isEmpty ? '${yearLabel(year, board, Lang.kn)} ವಾರ್ಷಿಕ ಪರೀಕ್ಷೆ · ${subjectName(subj, Lang.kn)}' : school.examName),
    examDate: school.examDate ?? DateTime(ay + 1, 3, 1),
    start: DateTime(ay, 6, 1),
    today: DateTime(today.year, today.month, today.day),
    revisionWeeks: school.revisionWeeks,
    chapters: [
      for (final (i, c) in yearChapters.indexed)
        PlanChapter(
          i + 1,
          c.title,
          math.max(1, (c.topicsFor(board).length / 2).ceil()),
          c.topicsFor(board).isEmpty ? 0 : c.topicsFor(board).where((t) => taught.contains(t.id)).length / c.topicsFor(board).length,
        ),
    ],
  );

  // Teams: houses by roll range, their XP and how they did in class quizzes.
  final quizzes = school.quizzes;
  final houses = school.houses;
  final todayKey = dayKey(today);
  final todays = quizzes.where((q) => dayKey(q.at) == todayKey);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final days = school.streakDays.toSet();
  final teams = TeamsData(
    teams: [
      for (final h in houses)
        TeamRow(h.name, h.rolls, h.xp, quizzes.fold(0, (a, q) => a + q.right.where(h.has).length), quizzes.fold(0, (a, q) => a + q.right.where(h.has).length + q.wrong.where(h.has).length)),
    ],
    streakDays: school.streak,
    week: [for (var d = 0; d < 6; d++) days.contains(dayKey(monday.add(Duration(days: d))))],
    periodXp: todays.fold(0, (a, q) => a + q.right.length * 10),
    goalXp: rolls * 20,
    feed: [
      for (final q in quizzes.reversed.take(4))
        for (final r in q.right.take(2)) (r, 10, const L10n('Right in the class quiz', 'ತರಗತಿ ಪ್ರಶ್ನೆಯಲ್ಲಿ ಸರಿ')),
    ].take(6).toList(),
  );

  return ClassSamples(
    subject: L10n(subjectName(subj, Lang.en), subjectName(subj, Lang.kn)),
    year: L10n(yearLabel(year, board, Lang.en), yearLabel(year, board, Lang.kn)),
    explainers: const [],
    questions: questions,
    formulas: formulas,
    mocks: content.mocks,
    code: content.programs.isEmpty ? CodeSample(const L10n(''), const L10n(''), const L10n(''), '', const [], const []) : content.programs.first.sample,
    plan: plan,
    teams: teams,
    mastery: classMastery(s, subj),
  );
}

/// Class mastery for [subject] from every answer marked on this board: chapters × kinds of
/// question (easy recall, apply, hard), and roll numbers × chapters. Empty before any quiz.
MasteryData classMastery(Services s, String subject) {
  final rolls = s.config.rollCount;
  final packs = {for (final p in subjectPacks(s, subject)) p.chapter.id: p};
  final byChapter = <String, List<(int?, bool, String)>>{};
  for (final r in s.mastery.responses) {
    final p = packs[r.chapterId];
    if (p == null) continue;
    (byChapter[r.chapterId] ??= []).add((r.roll, r.correct, p.questions[r.questionId]?.difficulty ?? 'medium'));
  }
  final chapters = [for (final p in packs.values) if (byChapter.containsKey(p.chapter.id)) p];
  int pct(Iterable<bool> xs) => xs.isEmpty ? -1 : (100 * xs.where((x) => x).length / xs.length).round();
  const kinds = ['easy', 'medium', 'hard'];
  final weak = s.mastery.weakTopics(n: 5, where: (t) => chapters.any((p) => p.lessons.containsKey(t)));
  final revise = [
    for (final t in weak)
      if (chapters.indexWhere((p) => p.lessons.containsKey(t)) case final ci when ci >= 0)
        (chapters[ci].lessons[t]!.title, ci, ((s.mastery.classTopic(t)?.p ?? 0) * 100).round()),
  ];
  // Nothing weak yet: the chapter with the lowest score is the one to revise.
  if (revise.isEmpty && chapters.isNotEmpty) {
    final scores = [for (final p in chapters) pct([for (final x in byChapter[p.chapter.id]!) x.$2])];
    var lo = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] < scores[lo]) lo = i;
    }
    revise.add((chapters[lo].chapter.title, lo, scores[lo]));
  }
  return MasteryData(
    chapters: [for (final p in chapters) p.chapter.title],
    skills: const [L10n('Recall', 'ನೆನಪು'), L10n('Apply', 'ಅನ್ವಯ'), L10n('Think hard', 'ಆಳ ಚಿಂತನೆ')],
    bySkill: [
      for (final p in chapters) [for (final k in kinds) pct([for (final x in byChapter[p.chapter.id]!) if (x.$3 == k) x.$2])],
    ],
    byRoll: [
      for (final p in chapters) [for (var r = 1; r <= rolls; r++) pct([for (final x in byChapter[p.chapter.id]!) if (x.$1 == r) x.$2])],
    ],
    revise: revise,
  );
}
