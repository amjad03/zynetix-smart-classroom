// Dart mirror of packages/lesson-schema (the source of truth). Packs are validated when they are
// built, so the board reads them leniently: a missing optional field never stops a lesson.

/// Board language: English or Kannada. Text falls back to English.
enum Lang { en, kn }

class L10n {
  const L10n(this.en, [this.kn]);
  final String en;
  final String? kn;

  static L10n of(Object? v) => v is Map ? L10n(v['en'] as String? ?? '', v['kn'] as String?) : const L10n('');
  static L10n? maybe(Object? v) => v is Map ? of(v) : null;
  static List<L10n> list(Object? v) => [for (final e in (v as List?) ?? const []) of(e)];

  String t(Lang lang) => lang == Lang.kn && (kn?.isNotEmpty ?? false) ? kn! : en;
}

enum BlockType {
  intro('intro'),
  concept('concept'),
  model3d('3d_model'),
  simulation('simulation'),
  virtualLab('virtual_lab'),
  example('example'),
  classQuiz('class_quiz'),
  pyq('pyq'),
  trick('trick'),
  recap('recap');

  const BlockType(this.wire);
  final String wire;
  static BlockType? parse(String s) => values.where((t) => t.wire == s).firstOrNull;
}

enum QuizMode { monitor, rollCall, team }

QuizMode _mode(Object? v) => switch (v) { 'roll_call' => QuizMode.rollCall, 'team' => QuizMode.team, _ => QuizMode.monitor };

/// One lesson block. Common fields are typed; type-specific fields are read through getters.
class Block {
  Block(this.type, this.raw);
  final BlockType type;
  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;
  L10n? get title => L10n.maybe(raw['title']);
  L10n? get narration => L10n.maybe(raw['narration']);
  int? get seconds => raw['seconds'] as int?;
  bool get optional => raw['optional'] == true;
  /// Curricula this block is for (null = all).
  List<String>? get boards => (raw['boards'] as List?)?.cast<String>();
  bool forBoard(String board) => boards == null || boards!.contains(board);

  L10n f(String key) => L10n.of(raw[key]);
  L10n? maybe(String key) => L10n.maybe(raw[key]);
  List<L10n> list(String key) => L10n.list(raw[key]);
  String? s(String key) => raw[key] as String?;
  List<String> ids(String key) => [for (final e in (raw[key] as List?) ?? const []) e as String];
  QuizMode get quizMode => _mode(raw['mode']);
  int get secondsPerQuestion => raw['secondsPerQuestion'] as int? ?? 45;

  /// Blocks the board does not know (from a newer schema) are skipped, never fatal.
  static Block? fromJson(Map<String, dynamic> j) {
    final t = BlockType.parse(j['type'] as String? ?? '');
    return t == null ? null : Block(t, j);
  }
}

class Lesson {
  Lesson({required this.id, required this.chapterId, required this.topicId, required this.title, required this.minutes, required this.blocks});
  final String id, chapterId, topicId;
  final L10n title;
  final int minutes;
  final List<Block> blocks;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        chapterId: j['chapterId'] as String,
        topicId: j['topicId'] as String,
        title: L10n.of(j['title']),
        minutes: j['minutes'] as int? ?? 40,
        blocks: [for (final b in j['blocks'] as List) ?Block.fromJson(b as Map<String, dynamic>)],
      );
}

class Question {
  Question({required this.id, required this.topicId, required this.stem, required this.options, required this.answer, this.explanation, required this.exams, required this.difficulty, this.pyqExam, this.pyqYear, this.pyqVerified = false, this.format = 'mcq', this.passage});
  final String id;
  final String? topicId;
  final L10n stem;
  final List<L10n> options;
  final int answer;
  final L10n? explanation;
  final List<String> exams;
  final String difficulty;
  final String? pyqExam;
  final int? pyqYear;
  final bool pyqVerified;
  /// mcq, assertion_reason or case_based.
  final String format;
  /// The case a case_based question is about.
  final L10n? passage;

  factory Question.fromJson(Map<String, dynamic> j) {
    final p = j['pyq'] as Map<String, dynamic>?;
    return Question(
      id: j['id'] as String,
      topicId: j['topicId'] as String?,
      stem: L10n.of(j['stem']),
      options: L10n.list(j['options']),
      answer: j['answer'] as int,
      explanation: L10n.maybe(j['explanation']),
      exams: [for (final e in (j['exams'] as List?) ?? const []) e as String],
      difficulty: j['difficulty'] as String? ?? 'medium',
      pyqExam: p?['exam'] as String?,
      pyqYear: p?['year'] as int?,
      pyqVerified: p?['verified'] == true,
      format: j['format'] as String? ?? 'mcq',
      passage: L10n.maybe(j['passage']),
    );
  }
}

class Topic {
  Topic(this.id, this.title, this.ncert, [this.boards]);
  final String id;
  final L10n title;
  final String? ncert;
  /// Curricula that teach this topic; the chapter's when null.
  final List<String>? boards;
}

class Chapter {
  Chapter({required this.id, required this.subject, required this.year, required this.number, required this.title, required this.topics, this.boards = const ['kar_pu', 'cbse']});
  final String id, subject, year;
  final List<String> boards;

  bool forBoard(String board) => boards.contains(board);
  List<Topic> topicsFor(String board) => [for (final t in topics) if ((t.boards ?? boards).contains(board)) t];
  final int number;
  final L10n title;
  final List<Topic> topics;

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: j['id'] as String,
        subject: j['subject'] as String,
        year: j['year'] as String,
        number: j['number'] as int,
        title: L10n.of(j['title']),
        topics: [for (final t in (j['topics'] as List?) ?? const []) Topic(t['id'] as String, L10n.of(t['title']), t['ncert'] as String?, (t['boards'] as List?)?.cast<String>())],
        boards: (j['boards'] as List?)?.cast<String>() ?? const ['kar_pu', 'cbse'],
      );
}

/// An installed pack: one chapter, its lessons and questions, and where its media lives.
class InstalledPack {
  InstalledPack({required this.id, required this.version, required this.chapter, required this.lessons, required this.questions, required this.mediaDir});
  final String id, version;
  final Chapter chapter;
  final Map<String, Lesson> lessons; // by topicId
  final Map<String, Question> questions;
  final String mediaDir;

  List<Question> questionsFor(Iterable<String> ids) => [for (final i in ids) ?questions[i]];
  List<Question> topicQuestions(String topicId) => [for (final q in questions.values) if (q.topicId == topicId) q];

  /// The lesson as taught on a board following [board]: blocks for other curricula removed.
  Lesson lessonFor(Lesson l, String board) =>
      Lesson(id: l.id, chapterId: l.chapterId, topicId: l.topicId, title: l.title, minutes: l.minutes, blocks: [for (final b in l.blocks) if (b.forBoard(board)) b]);
}
