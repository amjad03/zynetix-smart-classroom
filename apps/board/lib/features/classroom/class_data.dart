import '../../engine/model.dart';

/// The data the whole-class modes show: explainers, exam questions, formula sheets, mock-test
/// patterns, a coding sample, the class plan, teams and mastery. It is read from JSON in the
/// shape the Zynetix School content uses (src/content/... in quest-academy), so a later importer
/// can write the same files into a content pack. Class records hold roll numbers only: no names,
/// photos or anything else that identifies a student.
class ClassSamples {
  ClassSamples({
    required this.subject,
    required this.year,
    required this.explainers,
    required this.questions,
    required this.formulas,
    required this.mocks,
    required this.code,
    required this.plan,
    required this.teams,
    required this.mastery,
    required this.askAi,
  });

  final L10n subject, year;
  final List<ClassExplainer> explainers;
  final List<ClassQuestion> questions;
  final List<FormulaSheetData> formulas;
  final List<MockPattern> mocks;
  final CodeSample code;
  final ClassPlanData plan;
  final TeamsData teams;
  final MasteryData mastery;
  final AskAiSample askAi;

  factory ClassSamples.fromJson(Map<String, dynamic> j) => ClassSamples(
    subject: L10n.of(j['subject']),
    year: L10n.of(j['year']),
    explainers: [for (final e in _maps(j['explainers'])) ClassExplainer.fromJson(e)],
    questions: [for (final e in _maps(j['questions'])) ClassQuestion.fromJson(e)],
    formulas: [for (final e in _maps(j['formulas'])) FormulaSheetData.fromJson(e)],
    mocks: [for (final e in _maps(j['mocks'])) MockPattern.fromJson(e)],
    code: CodeSample.fromJson(j['code'] as Map<String, dynamic>),
    plan: ClassPlanData.fromJson(j['plan'] as Map<String, dynamic>),
    teams: TeamsData.fromJson(j['teams'] as Map<String, dynamic>),
    mastery: MasteryData.fromJson(j['mastery'] as Map<String, dynamic>),
    askAi: AskAiSample.fromJson(j['askAi'] as Map<String, dynamic>),
  );
}

List<Map<String, dynamic>> _maps(Object? v) => [for (final e in (v as List?) ?? const []) e as Map<String, dynamic>];
List<String> _strings(Object? v) => [for (final e in (v as List?) ?? const []) '$e'];
List<int> _ints(Object? v) => [for (final e in (v as List?) ?? const []) (e as num).toInt()];

/// One step of an explainer's "Watch it": the scene to draw, its title and the narration line.
class ExplainerStep {
  ExplainerStep(this.scene, this.title, this.say);
  final String scene;
  final L10n title, say;
}

/// A comic frame of an explainer's "Story".
class StoryFrame {
  StoryFrame(this.speech, this.caption);
  final L10n speech, caption;
}

/// A concept explainer: a misconception to clear, steps to watch, a mission to try, a story and
/// an everyday analogy ("It's like").
class ClassExplainer {
  ClassExplainer({required this.id, required this.title, required this.tagline, required this.chapter, required this.myth, required this.truth, required this.steps, required this.mission, required this.missionSteps, required this.story, required this.likeHeadline, required this.likePairs, required this.likeLimits, required this.examLink});
  final String id;
  final L10n title, tagline, chapter, myth, truth, mission, likeHeadline, likeLimits;

  /// The exam form of the idea (inline TeX), shown under the narration.
  final L10n examLink;
  final List<ExplainerStep> steps;
  final List<L10n> missionSteps;
  final List<StoryFrame> story;
  final List<(L10n, L10n)> likePairs;

  factory ClassExplainer.fromJson(Map<String, dynamic> j) => ClassExplainer(
    id: j['id'] as String,
    title: L10n.of(j['title']),
    tagline: L10n.of(j['tagline']),
    chapter: L10n.of(j['chapter']),
    myth: L10n.of((j['misconception'] as Map)['myth']),
    truth: L10n.of((j['misconception'] as Map)['truth']),
    steps: [for (final s in _maps(j['watch'])) ExplainerStep(s['scene'] as String? ?? '', L10n.of(s['title']), L10n.of(s['say']))],
    mission: L10n.of((j['mission'] as Map?)?['goal']),
    missionSteps: L10n.list((j['mission'] as Map?)?['steps']),
    story: [for (final s in _maps(j['story'])) StoryFrame(L10n.of(s['speech']), L10n.of(s['caption']))],
    likeHeadline: L10n.of((j['like'] as Map?)?['headline']),
    likePairs: [for (final p in ((j['like'] as Map?)?['pairs'] as List? ?? const [])) (L10n.of((p as List)[0]), L10n.of(p[1]))],
    likeLimits: L10n.of((j['like'] as Map?)?['limits']),
    examLink: L10n.of(j['examLink']),
  );
}

/// An exam question (MCQ) with its worked solution, tagged with the exams it suits.
class ClassQuestion {
  ClassQuestion({required this.id, required this.chapter, required this.exams, required this.stem, required this.options, required this.answer, required this.steps, required this.idealTime, required this.difficulty});
  final String id;
  final L10n chapter, stem;
  final List<String> exams;
  final List<L10n> options;
  final int answer, idealTime, difficulty;
  final List<L10n> steps;

  factory ClassQuestion.fromJson(Map<String, dynamic> j) => ClassQuestion(
    id: j['id'] as String,
    chapter: L10n.of(j['chapter']),
    exams: _strings(j['exams']),
    stem: L10n.of(j['q']),
    options: L10n.list(j['options']),
    answer: (j['answer'] as num).toInt(),
    steps: L10n.list(j['steps']),
    idealTime: (j['idealTime'] as num?)?.toInt() ?? 60,
    difficulty: (j['difficulty'] as num?)?.toInt() ?? 1,
  );
}

class FormulaItem {
  FormulaItem(this.name, this.tex, this.note);
  final L10n name, note;
  final String tex;
}

/// A chapter's formula sheet.
class FormulaSheetData {
  FormulaSheetData(this.chapter, this.items);
  final L10n chapter;
  final List<FormulaItem> items;

  factory FormulaSheetData.fromJson(Map<String, dynamic> j) => FormulaSheetData(
    L10n.of(j['chapter']),
    [for (final i in _maps(j['items'])) FormulaItem(L10n.of(i['name']), i['tex'] as String, L10n.of(i['note']))],
  );
}

class MockSection {
  MockSection(this.subject, this.count, this.plus, this.minus);
  final String subject;
  final int count;
  final num plus, minus;
}

/// An entrance-exam paper pattern (KCET, NEET, JEE Main, COMEDK).
class MockPattern {
  MockPattern({required this.id, required this.exam, required this.title, required this.blurb, required this.minutes, required this.sections, required this.minutesPerSection});
  final String id, exam;
  final L10n title, blurb;
  final int minutes;
  final int? minutesPerSection;
  final List<MockSection> sections;

  int get questions => sections.fold(0, (a, s) => a + s.count);
  num get maxMarks => sections.fold<num>(0, (a, s) => a + s.count * s.plus);
  String get marking {
    final s = sections.first;
    return s.minus == 0 ? '+${s.plus} · no negative' : '+${s.plus} / −${s.minus}';
  }

  factory MockPattern.fromJson(Map<String, dynamic> j) => MockPattern(
    id: j['id'] as String,
    exam: j['exam'] as String,
    title: L10n.of(j['title']),
    blurb: L10n.of(j['blurb']),
    minutes: (j['minutes'] as num).toInt(),
    minutesPerSection: (j['minutesPerSection'] as num?)?.toInt(),
    sections: [for (final s in _maps(j['sections'])) MockSection(s['subject'] as String, (s['count'] as num).toInt(), s['plus'] as num, s['minus'] as num)],
  );
}

/// A Python program with the output it prints (PUC Computer Science).
class CodeSample {
  CodeSample(this.title, this.chapter, this.task, this.code, this.output, this.watch);
  final L10n title, chapter, task;
  final String code;
  final List<String> output;

  /// The variables at the highlighted line, for tracing.
  final List<String> watch;
  factory CodeSample.fromJson(Map<String, dynamic> j) => CodeSample(L10n.of(j['title']), L10n.of(j['chapter']), L10n.of(j['task']), j['code'] as String, _strings(j['output']), _strings(j['watch']));
}

/// One chapter in the syllabus plan.
class PlanChapter {
  PlanChapter(this.no, this.title, this.weeks, this.done);
  final int no;
  final L10n title;
  final int weeks;

  /// Share of the chapter taught so far (0–1).
  final double done;
}

/// The syllabus worked back from the exam date.
class ClassPlanData {
  ClassPlanData({required this.exam, required this.examDate, required this.start, required this.today, required this.chapters, required this.revisionWeeks});
  final L10n exam;
  final DateTime examDate, start, today;
  final List<PlanChapter> chapters;
  final int revisionWeeks;

  factory ClassPlanData.fromJson(Map<String, dynamic> j) => ClassPlanData(
    exam: L10n.of(j['exam']),
    examDate: DateTime.parse(j['examDate'] as String),
    start: DateTime.parse(j['start'] as String),
    today: DateTime.parse(j['today'] as String),
    revisionWeeks: (j['revisionWeeks'] as num?)?.toInt() ?? 3,
    chapters: [for (final (i, c) in _maps(j['chapters']).indexed) PlanChapter(i + 1, L10n.of(c['title']), (c['weeks'] as num).toInt(), (c['done'] as num?)?.toDouble() ?? 0)],
  );
}

class TeamRow {
  TeamRow(this.name, this.rolls, this.xp, this.right, this.asked);
  final L10n name;
  final List<int> rolls;
  final int xp, right, asked;
}

/// Teams by bench rows or houses: XP for the period and the class streak. Roll numbers only.
class TeamsData {
  TeamsData({required this.teams, required this.streakDays, required this.week, required this.periodXp, required this.goalXp, required this.feed});
  final List<TeamRow> teams;
  final int streakDays, periodXp, goalXp;

  /// Mon–Sat: whether the class met its goal that day.
  final List<bool> week;

  /// Recent points: roll number, points and why.
  final List<(int, int, L10n)> feed;

  factory TeamsData.fromJson(Map<String, dynamic> j) => TeamsData(
    teams: [for (final t in _maps(j['teams'])) TeamRow(L10n.of(t['name']), _ints(t['rolls']), (t['xp'] as num).toInt(), (t['right'] as num).toInt(), (t['asked'] as num).toInt())],
    streakDays: (j['streakDays'] as num).toInt(),
    week: [for (final b in (j['week'] as List)) b == true],
    periodXp: (j['periodXp'] as num).toInt(),
    goalXp: (j['goalXp'] as num).toInt(),
    feed: [for (final f in _maps(j['feed'])) ((f['roll'] as num).toInt(), (f['xp'] as num).toInt(), L10n.of(f['why']))],
  );
}

/// Class mastery: chapters × skills (class averages) and roll numbers × chapters.
class MasteryData {
  MasteryData({required this.chapters, required this.skills, required this.bySkill, required this.byRoll, required this.revise});
  final List<L10n> chapters, skills;

  /// [chapter][skill] → 0–100.
  final List<List<int>> bySkill;

  /// [chapter][roll − 1] → 0–100, or −1 when the roll number has not answered yet.
  final List<List<int>> byRoll;

  /// Weak topics to revise next: topic, chapter index, class score.
  final List<(L10n, int, int)> revise;

  factory MasteryData.fromJson(Map<String, dynamic> j) => MasteryData(
    chapters: L10n.list(j['chapters']),
    skills: L10n.list(j['skills']),
    bySkill: [for (final r in (j['bySkill'] as List)) _ints(r)],
    byRoll: [for (final r in (j['byRoll'] as List)) _ints(r)],
    revise: [for (final r in _maps(j['revise'])) (L10n.of(r['topic']), (r['chapter'] as num).toInt(), (r['score'] as num).toInt())],
  );
}

/// A teacher's question to ZYN-AI and its hint-first answer, with the lesson's own hints for
/// when the board is offline.
class AskAiSample {
  AskAiSample(this.question, this.hints, this.answer, this.offlineHints, this.lesson);
  final L10n question, answer, lesson;
  final List<L10n> hints, offlineHints;
  factory AskAiSample.fromJson(Map<String, dynamic> j) => AskAiSample(L10n.of(j['question']), L10n.list(j['hints']), L10n.of(j['answer']), L10n.list(j['offlineHints']), L10n.of(j['lesson']));
}
