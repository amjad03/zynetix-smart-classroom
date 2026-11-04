import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../blocks/math_text.dart';
import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';
import '../engine/session_log.dart';
import 'participation.dart';
import 'smartboard.dart';

/// Exam names on the board. JEE is JEE Main.
const examNames = <String, String>{'KCET': 'KCET', 'COMEDK': 'COMEDK', 'NEET': 'NEET', 'JEE': 'JEE Main', 'JEE_ADV': 'JEE Advanced', 'PUC': 'II PUC Board', 'CBSE': 'CBSE Board', 'ISC': 'ISC Board'};

/// The subjects each entrance exam tests (board exams test all of the section's subjects).
const examSubjects = <String, List<String>>{
  'KCET': ['physics', 'chemistry', 'maths', 'biology'],
  'COMEDK': ['physics', 'chemistry', 'maths'],
  'NEET': ['physics', 'chemistry', 'biology'],
  'JEE': ['physics', 'chemistry', 'maths'],
  'JEE_ADV': ['physics', 'chemistry', 'maths'],
};

const _examColors = <String, Color>{
  'KCET': Color(0xFF1565C0),
  'COMEDK': Color(0xFF00838F),
  'NEET': Color(0xFF2E7D32),
  'JEE': Color(0xFFC62828),
  'JEE_ADV': Color(0xFF6A1B9A),
  'PUC': Color(0xFFEF6C00),
  'CBSE': Color(0xFFEF6C00),
  'ISC': Color(0xFFEF6C00),
};

/// The exams that fit a section: NEET needs biology, JEE and COMEDK need maths, KCET needs one
/// of PCMB; the section's own board exam (PUC, CBSE or ISC) is always there.
List<String> examsFor(List<String> subjects, String board) {
  bool has(String s) => subjects.contains(s);
  return [if (examSubjects['KCET']!.any(has)) 'KCET', if (has('maths')) 'COMEDK', if (has('biology')) 'NEET', if (has('maths')) 'JEE', if (has('maths')) 'JEE_ADV', boardExam(board)];
}

/// The board exam a section sits: II PUC (Karnataka), CBSE or ISC.
String boardExam(String board) => switch (board) { 'cbse' => 'CBSE', 'isc' => 'ISC', _ => 'PUC' };

/// The section's subjects that [exam] tests, in the section's order.
List<String> examSubjectsFor(String exam, List<String> subjects) => [
  for (final s in subjects)
    if (examSubjects[exam]?.contains(s) ?? true) s,
];

/// A question with the pack (chapter) it comes from.
class ExamItem {
  ExamItem(this.pack, this.q);
  final InstalledPack pack;
  final Question q;
  String get subject => pack.chapter.subject;
}

/// Every installed question tagged [exam] in the section's subjects for that exam (both years).
List<ExamItem> examPool(Services s, String exam) {
  final subjects = examSubjectsFor(exam, s.subjects);
  return [
    for (final p in s.store.packs)
      if (subjects.contains(p.chapter.subject) && p.chapter.forBoard(s.config.board))
        for (final q in p.questions.values)
          if (q.exams.contains(exam)) ExamItem(p, q),
  ];
}

/// Chapter test: [count] questions from one chapter, shuffled.
List<ExamItem> chapterTest(List<ExamItem> pool, String chapterId, Random rnd, {int count = 10}) => ([
  for (final i in pool)
    if (i.pack.chapter.id == chapterId) i,
]..shuffle(rnd)).take(count).toList();

/// Mock test: [count] questions mixed across subjects, taken in turn from each subject.
List<ExamItem> mockTest(List<ExamItem> pool, Random rnd, {int count = 30}) {
  final bySubject = <String, List<ExamItem>>{};
  for (final i in pool) {
    (bySubject[i.subject] ??= []).add(i);
  }
  for (final l in bySubject.values) {
    l.shuffle(rnd);
  }
  final out = <ExamItem>[];
  while (out.length < count && bySubject.values.any((l) => l.isNotEmpty)) {
    for (final l in bySubject.values) {
      if (l.isNotEmpty && out.length < count) out.add(l.removeLast());
    }
  }
  return out..shuffle(rnd);
}

/// Where Exam Practice is: choosing the exam, the test, the chapter; running; results.
enum ExamStage { exam, mode, chapter, run, results }

/// Exam Practice: pick an exam, then a 10-question chapter test or a timed 30-question mock,
/// answered by the class with the monitor pad, then the results with answers and explanations.
class ExamPracticeScreen extends StatefulWidget {
  const ExamPracticeScreen({super.key, this.random});
  final Random? random;
  @override
  State<ExamPracticeScreen> createState() => ExamPracticeScreenState();
}

class ExamPracticeScreenState extends State<ExamPracticeScreen> {
  late final Services s = ServicesScope.of(context);
  late final Random rnd = widget.random ?? Random();
  ExamStage stage = ExamStage.exam;
  String? exam;
  String? subject;
  bool mock = false;
  int minutesPerQuestion = 1;
  List<ExamItem> pool = const [], items = const [];
  final _pools = <String, List<ExamItem>>{};
  SessionRecorder? recorder;
  late ClassRoom room = ClassRoom(rollCount: s.config.rollCount);
  Timer? _clock;
  int secondsLeft = 0;
  bool timeUp = false;

  List<ExamItem> poolOf(String e) => _pools[e] ??= examPool(s, e);

  @override
  void dispose() {
    _clock?.cancel();
    if (stage == ExamStage.run) recorder?.close(completed: false);
    super.dispose();
  }

  void pickExam(String e) => setState(() {
    exam = e;
    pool = poolOf(e);
    stage = ExamStage.mode;
  });

  void start(List<ExamItem> chosen, {required bool isMock}) {
    if (chosen.isEmpty) return;
    final first = chosen.first;
    recorder = SessionRecorder.raw(
      outbox: s.outbox,
      sectionId: s.config.sectionId,
      mode: 'teacher',
      chapterId: first.pack.chapter.id,
      topicId: first.q.topicId ?? first.pack.chapter.topics.firstOrNull?.id ?? first.pack.chapter.id,
      lessonId: 'exam-practice.${exam!.toLowerCase()}',
      packVersion: first.pack.version,
      now: s.clock,
      mastery: s.mastery,
    );
    room = ClassRoom(rollCount: s.config.rollCount);
    _clock?.cancel();
    secondsLeft = chosen.length * minutesPerQuestion * 60;
    timeUp = false;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => secondsLeft--);
      if (secondsLeft <= 0) {
        timeUp = true;
        finish();
      }
    });
    setState(() {
      mock = isMock;
      items = chosen;
      stage = ExamStage.run;
    });
  }

  void finish() {
    _clock?.cancel();
    recorder?.close(completed: true);
    if (mounted) setState(() => stage = ExamStage.results);
  }

  void _back() {
    switch (stage) {
      case ExamStage.exam || ExamStage.results:
        Navigator.pop(context);
      case ExamStage.mode:
        setState(() => stage = ExamStage.exam);
      case ExamStage.chapter:
        setState(() => stage = ExamStage.mode);
      case ExamStage.run:
        _clock?.cancel();
        recorder?.close(completed: false);
        setState(() => stage = ExamStage.mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = s.config.lang, text = Theme.of(context).textTheme;
    final title = switch (stage) {
      ExamStage.exam => tr('examPractice', l),
      ExamStage.mode || ExamStage.chapter => '${tr('examPractice', l)} · ${examNames[exam]}',
      ExamStage.run => '${examNames[exam]} · ${tr(mock ? 'mockTest' : 'chapterTest', l)}',
      ExamStage.results => '${tr('results', l)} · ${examNames[exam]}',
    };
    return PopScope(
      canPop: stage == ExamStage.exam || stage == ExamStage.results,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: Z.tap + 16,
          leading: IconButton(key: const ValueKey('examBack'), iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: _back),
          title: Text(title, style: context.narrow ? text.headlineMedium : text.headlineLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (stage == ExamStage.run) ...[
              _Clock(secondsLeft: secondsLeft, lang: l),
              const SizedBox(width: 20),
              BigButton(collapse: true, key: const ValueKey('endTest'), icon: Icons.flag_outlined, label: tr('endTest', l), filled: false, onPressed: finish),
              const SizedBox(width: 20),
            ],
            const SmartboardButton(),
            const SizedBox(width: 24),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.all(context.narrow ? 20 : 40),
          child: switch (stage) {
            ExamStage.exam => _examPicker(l, text),
            ExamStage.mode => _modePicker(l, text),
            ExamStage.chapter => _chapterPicker(l, text),
            ExamStage.run => QuizRunner(
              key: ValueKey('exam:${recorder.hashCode}'),
              questions: [for (final i in items) i.q],
              mode: QuizMode.monitor,
              lang: l,
              recorder: recorder!,
              room: room,
              onDone: finish,
            ),
            ExamStage.results => _Results(items: items, answers: [for (final a in (recorder?.log['answers'] as List? ?? const [])) (a as Map).cast<String, dynamic>()], lang: l, timeUp: timeUp),
          },
        ),
      ),
    );
  }

  Widget _examPicker(Lang l, TextTheme text) {
    final exams = examsFor(s.subjects, s.config.board);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('chooseExam', l), style: text.headlineSmall),
        const SizedBox(height: Z.gap),
        Expanded(
          child: GridView(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 700, mainAxisExtent: 250, mainAxisSpacing: Z.gap, crossAxisSpacing: Z.gap),
            children: [
              for (final e in exams)
                _BigCard(
                  key: ValueKey('exam:$e'),
                  color: _examColors[e]!,
                  title: examNames[e]!,
                  sub: '${poolOf(e).length} ${tr('questions', l)} · ${examSubjectsFor(e, s.subjects).map((x) => subjectName(x, l)).join(', ')}',
                  onTap: poolOf(e).isEmpty ? null : () => pickExam(e),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modePicker(Lang l, TextTheme text) {
    if (pool.isEmpty) return Center(child: Text(tr('noQuestions', l), style: text.headlineMedium));
    final mins = Row(
      children: [
        Text(tr('minPerQuestion', l), style: text.bodyLarge),
        const SizedBox(width: 24),
        IconButton.filledTonal(key: const ValueKey('minus'), iconSize: 56, onPressed: minutesPerQuestion > 1 ? () => setState(() => minutesPerQuestion--) : null, icon: const Icon(Icons.remove)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text('$minutesPerQuestion', key: const ValueKey('minutes'), style: text.displayLarge),
        ),
        IconButton.filledTonal(key: const ValueKey('plus'), iconSize: 56, onPressed: minutesPerQuestion < 2 ? () => setState(() => minutesPerQuestion++) : null, icon: const Icon(Icons.add)),
      ],
    );
    final portrait = context.portrait;
    Widget card(Widget c) => portrait ? SizedBox(height: 250, child: c) : Expanded(child: c);
    return ListView(
      children: [
        SizedBox(
          height: portrait ? null : 300,
          child: Flex(
            direction: portrait ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              card(
                _BigCard(
                  key: const ValueKey('chapterTest'),
                  icon: Icons.menu_book_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  title: tr('chapterTest', l),
                  sub: tr('chapterTestSub', l),
                  onTap: () => setState(() {
                    subject ??= examSubjectsFor(exam!, s.subjects).firstOrNull;
                    stage = ExamStage.chapter;
                  }),
                ),
              ),
              portrait ? const SizedBox(height: 32) : const SizedBox(width: 40),
              card(
                _BigCard(
                  key: const ValueKey('mockTest'),
                  icon: Icons.timer_outlined,
                  color: _examColors[exam]!,
                  title: tr('mockTest', l),
                  sub: tr('mockTestSub', l),
                  onTap: () => start(mockTest(pool, rnd), isMock: true),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: mins),
      ],
    );
  }

  Widget _chapterPicker(Lang l, TextTheme text) {
    final subjects = examSubjectsFor(exam!, s.subjects);
    final counts = <String, int>{};
    final chapters = <String, InstalledPack>{};
    for (final i in pool) {
      if (i.subject != subject) continue;
      counts[i.pack.chapter.id] = (counts[i.pack.chapter.id] ?? 0) + 1;
      chapters[i.pack.chapter.id] = i.pack;
    }
    final list = chapters.values.toList()..sort((a, b) => a.chapter.year != b.chapter.year ? a.chapter.year.compareTo(b.chapter.year) : a.chapter.number.compareTo(b.chapter.number));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(tr('chooseSubject', l), style: text.headlineSmall),
            const SizedBox(width: Z.gap),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(minimumSize: const Size(200, Z.tap), textStyle: zText(30)),
                  segments: [for (final x in subjects) ButtonSegment(value: x, label: Text(subjectName(x, l)))],
                  selected: {?subject},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => subject = v.firstOrNull ?? subject),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Z.gap),
        Text(tr('chooseChapter', l), style: text.bodyLarge),
        const SizedBox(height: 12),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text(tr('noQuestions', l), style: text.headlineMedium))
              : ListView(
                  children: [
                    for (final p in list)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          key: ValueKey('chapter:${p.chapter.id}'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => start(chapterTest(pool, p.chapter.id, rnd), isMock: false),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: Z.tap),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                              child: Row(
                                children: [
                                  Text(yearLabel(p.chapter.year, s.config.board, l), style: text.bodyMedium?.copyWith(color: Z.muted)),
                                  const SizedBox(width: 24),
                                  Expanded(child: Text('${p.chapter.number}. ${p.chapter.title.t(l)}', style: text.headlineMedium)),
                                  Text('${counts[p.chapter.id]} ${tr('questions', l)}', style: text.bodyMedium),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.play_circle_fill, size: 64, color: Z.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock({required this.secondsLeft, required this.lang});
  final int secondsLeft;
  final Lang lang;
  @override
  Widget build(BuildContext context) {
    final left = max(0, secondsLeft);
    final low = left <= 60;
    return Container(
      key: const ValueKey('examClock'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(color: low ? Z.wrongBg : Z.panel, borderRadius: BorderRadius.circular(Z.radius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 44, color: low ? Z.wrongText : Z.ink2),
          const SizedBox(width: 12),
          Text(
            '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}',
            style: zText(44, FontWeight.w600).copyWith(color: low ? Z.wrongText : Z.ink),
          ),
        ],
      ),
    );
  }
}

/// A choice card: a white panel, its icon on a pale blue tile, a Poppins name and one line.
/// [color] is ignored (kept so callers read the same); colour is only for meaning.
class _BigCard extends StatelessWidget {
  const _BigCard({super.key, required this.color, required this.title, required this.sub, this.icon, this.onTap});
  final Color color;
  final String title, sub;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.5 : 1,
    child: Material(
      color: Z.panel,
      borderRadius: BorderRadius.circular(Z.panelRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(Z.panelRadius),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.narrow ? 28 : 44),
          child: Row(
            children: [
              Container(
                width: context.narrow ? 104 : 128,
                height: context.narrow ? 104 : 128,
                decoration: BoxDecoration(color: Z.tagBg, borderRadius: BorderRadius.circular(32)),
                child: Icon(icon ?? Icons.emoji_events_outlined, size: context.narrow ? 56 : 68, color: Z.primary),
              ),
              SizedBox(width: context.narrow ? 24 : 36),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(title, style: zTitle(context.narrow ? 42 : 48)),
                    ),
                    const SizedBox(height: 8),
                    Text(sub, style: zText(context.narrow ? 26 : 28, FontWeight.w400).copyWith(color: Z.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Score, accuracy per subject, and every question with its correct answer and explanation.
class _Results extends StatelessWidget {
  const _Results({required this.items, required this.answers, required this.lang, required this.timeUp});
  final List<ExamItem> items;
  final List<Map<String, dynamic>> answers;
  final Lang lang;
  final bool timeUp;

  static String correctAnswer(Question q, Lang l) {
    if (q.isNumeric) return '${formatNumber(q.numericAnswer ?? double.nan)}${(q.tolerance ?? 0) > 0 ? ' ± ${formatNumber(q.tolerance!)}' : ''}';
    final idx = q.correctSet.toList()..sort();
    return idx.map((i) => '${'ABCD'[i]}. ${i < q.options.length ? q.options[i].t(l) : ''}').join('   ');
  }

  @override
  Widget build(BuildContext context) {
    final l = lang, text = Theme.of(context).textTheme;
    // The class's answer is the first one per question; later per-roll answers (hands up) only
    // feed the mastery map.
    final byId = <String, bool>{};
    for (final a in answers) {
      byId.putIfAbsent(a['questionId'] as String, () => a['correct'] == true);
    }
    final score = items.where((i) => byId[i.q.id] == true).length;
    final subjects = <String, (int, int)>{};
    for (final i in items) {
      final (r, n) = subjects[i.subject] ?? (0, 0);
      subjects[i.subject] = (r + (byId[i.q.id] == true ? 1 : 0), n + 1);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (timeUp) Text(tr('timeUp', l), style: text.bodyLarge?.copyWith(color: Z.wrong)),
              Text(tr('score', l), style: text.headlineMedium),
              Text(
                '$score / ${items.length}',
                key: const ValueKey('examScore'),
                style: text.displayLarge?.copyWith(fontSize: 120, color: Z.ink),
              ),
              Text('${items.isEmpty ? 0 : (score * 100 / items.length).round()}%', style: text.headlineLarge),
              const SizedBox(height: 32),
              Text(tr('accuracy', l), style: text.headlineMedium),
              const SizedBox(height: 12),
              for (final e in subjects.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${subjectName(e.key, l)}  ${e.value.$1} / ${e.value.$2}', style: text.bodyLarge),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: e.value.$2 == 0 ? 0 : e.value.$1 / e.value.$2,
                        minHeight: 22,
                        borderRadius: BorderRadius.circular(11),
                        color: Z.correct,
                        backgroundColor: Z.wrong.withValues(alpha: 0.35),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              BigButton(key: const ValueKey('examDone'), icon: Icons.done_all, label: tr('done', l), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        const SizedBox(width: 40),
        Expanded(
          child: ListView(
            children: [
              for (final (n, i) in items.indexed)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          byId[i.q.id] == null ? Icons.remove_circle_outline : (byId[i.q.id]! ? Icons.check_circle : Icons.cancel),
                          size: 52,
                          color: byId[i.q.id] == null ? Z.track : (byId[i.q.id]! ? Z.correct : Z.wrong),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MathText('${n + 1}. ${i.q.stem.t(l)}', style: text.bodyLarge?.copyWith(fontSize: 30)),
                              const SizedBox(height: 8),
                              Text(
                                '${tr('correctAnswer', l)}: ${correctAnswer(i.q, l)}',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Z.correct),
                              ),
                              if (i.q.explanation != null) ...[const SizedBox(height: 6), MathText(i.q.explanation!.t(l), style: text.bodyMedium)],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
