import 'package:flutter/material.dart';

import '../../blocks/math_text.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../engine/mastery.dart';
import '../../engine/model.dart';
import '../app/school.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'strings.dart';

enum QuizPhase { ask, mark, reveal }

/// A class quiz with no phones and no answer cards: the question goes on the board, the class
/// answers aloud or on paper, and the teacher taps each roll number right or wrong. Reveal shows
/// how much of the class got it, the worked solution and the roll numbers to revisit.
class ClassQuizScreen extends StatefulWidget {
  const ClassQuizScreen({super.key, required this.samples, this.questionIndex = 0});
  final ClassSamples samples;
  final int questionIndex;

  @override
  State<ClassQuizScreen> createState() => _ClassQuizScreenState();
}

class _ClassQuizScreenState extends State<ClassQuizScreen> {
  late int qi = widget.questionIndex;
  QuizPhase phase = QuizPhase.ask;
  List<Mark> marks = const [];

  /// The quiz runs on the chapter's questions (the first five in the sample).
  List<ClassQuestion> get questions => widget.samples.questions.take(5).toList();
  ClassQuestion get q => questions[qi];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (marks.isEmpty) marks = List.filled(ServicesScope.of(context).config.rollCount, Mark.none);
  }

  /// Every tap can be undone from "What do I do now?" while the quiz is open.
  void _remember(L10n what) {
    final before = marks, at = qi;
    final school = ServicesScope.of(context).school;
    school.pushUndo(what, () {
      if (mounted && qi == at) setState(() => marks = before);
    });
    _undos.add(school.lastUndo!);
  }

  final List<UndoItem> _undos = [];

  @override
  void dispose() {
    final mine = _undos.toSet();
    _school?.dropUndo(mine.contains);
    super.dispose();
  }

  SchoolStore? _school;

  void _cycle(int roll) {
    _school = ServicesScope.of(context).school;
    final next = Mark.values[(marks[roll - 1].index + 1) % 3];
    _remember(L10n('Roll $roll marked ${next.name == 'none' ? 'blank' : next.name}', 'ರೋಲ್ $roll ಗುರುತು ಬದಲಾಗಿದೆ'));
    setState(() {
      marks = [...marks];
      marks[roll - 1] = next;
    });
  }

  void _fill(Mark m, {bool onlyEmpty = false}) {
    _school = ServicesScope.of(context).school;
    _remember(const L10n('Marked the rest of the class', 'ಉಳಿದವರನ್ನು ಗುರುತಿಸಿದ್ದು'));
    setState(() => marks = [for (final x in marks) onlyEmpty && x != Mark.none ? x : m]);
  }

  /// Saves this question's marks by roll number (blank ones are left out) to the class's
  /// results and mastery, gives the houses XP and keeps the class streak.
  final Set<int> _saved = {};
  void _save() {
    if (_saved.contains(qi)) return;
    _saved.add(qi);
    final s = ServicesScope.of(context);
    final now = s.clock();
    final right = [for (var r = 1; r <= marks.length; r++) if (marks[r - 1] == Mark.right) r];
    final wrong = [for (var r = 1; r <= marks.length; r++) if (marks[r - 1] == Mark.wrong) r];
    if (right.isEmpty && wrong.isEmpty) return;
    final hit = _questionSource(s, q.id);
    final result = QuizResult(id: 'q${now.microsecondsSinceEpoch}', at: now, questionId: q.id, topicId: hit?.topicId ?? '', chapterId: hit?.chapterId ?? '', right: right, wrong: wrong);
    s.school.addQuiz(result);
    s.mastery.recordAll([
      for (final r in right) Response(roll: r, questionId: q.id, topicId: result.topicId, chapterId: result.chapterId, correct: true, source: 'roll_call', at: now),
      for (final r in wrong) Response(roll: r, questionId: q.id, topicId: result.topicId, chapterId: result.chapterId, correct: false, source: 'roll_call', at: now),
    ]);
    for (final (i, h) in s.school.houses.indexed) {
      final xp = right.where(h.has).length * 10;
      if (xp > 0) s.school.addXp(i, xp);
    }
    s.school.markStreakDay(now);
  }

  /// The pack question a class question came from (for its topic and chapter).
  Question? _questionSource(Services s, String id) {
    for (final p in s.store.packs) {
      final q = p.questions[id];
      if (q != null) return Question(id: q.id, chapterId: q.chapterId ?? p.chapter.id, topicId: q.topicId, stem: q.stem, options: q.options, answer: q.answer, exams: q.exams, difficulty: q.difficulty);
    }
    return null;
  }

  int _count(Mark m) => marks.where((x) => x == m).length;

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final narrow = context.narrow;
      final last = qi == questions.length - 1;
      return ClassScaffold(
        crumbs: [widget.samples.subject.t(l), widget.samples.year.t(l), q.chapter.t(l)],
        title: ct('classQuiz', l),
        trailing: [if (!narrow) BarChip('${ct('question', l)} ${qi + 1} / ${questions.length}')],
        bottomLeft: [
          BigButton(icon: Icons.arrow_back, label: ct('back', l), filled: false, collapse: true, onPressed: phase == QuizPhase.ask ? null : () => setState(() => phase = QuizPhase.values[phase.index - 1])),
          if (phase == QuizPhase.ask && !narrow) BarChip(ct('thinkFor', l, {'s': q.idealTime}), icon: Icons.hourglass_bottom),
          if (phase == QuizPhase.mark && !narrow) Text(ct('privacy', l), style: zText(28, FontWeight.w500).copyWith(color: Z.muted)),
        ],
        bottomRight: [
          switch (phase) {
            QuizPhase.ask => BigButton(key: const ValueKey('quizMark'), icon: Icons.how_to_reg_outlined, label: ct('markRolls', l), onPressed: () => setState(() => phase = QuizPhase.mark)),
            QuizPhase.mark => BigButton(key: const ValueKey('quizReveal'), icon: Icons.visibility_outlined, label: ct('reveal', l), onPressed: () {
              _save();
              setState(() => phase = QuizPhase.reveal);
            }),
            QuizPhase.reveal => BigButton(
              key: const ValueKey('quizNext'),
              icon: Icons.arrow_forward,
              trailingIcon: true,
              label: ct('nextQuestion', l),
              onPressed: last
                  ? null
                  : () => setState(() {
                      qi++;
                      phase = QuizPhase.ask;
                      marks = List.filled(marks.length, Mark.none);
                    }),
            ),
          },
        ],
        body: switch (phase) {
          QuizPhase.ask => _ask(context, l),
          QuizPhase.mark => _mark(context, l),
          QuizPhase.reveal => _reveal(context, l),
        },
      );
    },
  );

  Widget _examTags(Lang l) => Wrap(spacing: 12, runSpacing: 12, children: [for (final e in q.exams) ZTag.neutral(e)]);

  Widget _ask(BuildContext context, Lang l) {
    final narrow = context.narrow, portrait = context.portrait;
    final options = [
      for (final (i, o) in q.options.indexed)
        _OptionCard(letter: optionLetters[i], text: o.t(l), size: narrow ? 36 : 60),
    ];
    return ZPanel(
      padding: EdgeInsets.all(narrow ? 32 : 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ZTag('${ct('classQuiz', l)} · ${ct('question', l)} ${qi + 1}'),
              const SizedBox(width: 16),
              if (!narrow) Expanded(child: _examTags(l)),
            ],
          ),
          SizedBox(height: narrow ? 24 : 40),
          MathText(q.stem.t(l), style: zText(narrow ? 38 : 60, FontWeight.w500).copyWith(color: Z.ink, height: 1.4)),
          SizedBox(height: narrow ? 28 : 48),
          Expanded(
            child: portrait
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final o in options) Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: o))])
                : Column(
                    children: [
                      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: options[0]), const SizedBox(width: 28), Expanded(child: options[1])])),
                      const SizedBox(height: 28),
                      Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: options[2]), const SizedBox(width: 28), Expanded(child: options[3])])),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _counts(Lang l, {double size = 34}) => Wrap(
    spacing: 16,
    runSpacing: 12,
    children: [
      _CountPill(ct('right', l), _count(Mark.right), Z.correct, Z.correctBg, size: size),
      _CountPill(ct('wrong', l), _count(Mark.wrong), Z.wrongText, Z.wrongBg, size: size),
      _CountPill(ct('notMarked', l), _count(Mark.none), Z.ink2, Z.segTrack, size: size),
    ],
  );

  Widget _mark(BuildContext context, Lang l) {
    final narrow = context.narrow, portrait = context.portrait;
    final fills = Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        BigButton(key: const ValueKey('fillRight'), icon: Icons.done_all, label: ct('allRight', l), filled: false, onPressed: () => _fill(Mark.right)),
        BigButton(key: const ValueKey('fillWrong'), icon: Icons.close, label: ct('allWrong', l), filled: false, onPressed: () => _fill(Mark.wrong)),
        BigButton(key: const ValueKey('fillRest'), icon: Icons.playlist_add_check, label: ct('restRight', l), filled: false, onPressed: () => _fill(Mark.right, onlyEmpty: true)),
        BigButton(key: const ValueKey('fillClear'), icon: Icons.backspace_outlined, label: ct('clear', l), filled: false, onPressed: () => _fill(Mark.none)),
      ],
    );
    final grid = ZPanel(
      padding: EdgeInsets.all(narrow ? 24 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _counts(l, size: narrow ? 28 : 34),
          SizedBox(height: narrow ? 16 : 24),
          if (!narrow) ...[fills, const SizedBox(height: 16)],
          Text(ct('tapCycles', l), style: zText(narrow ? 24 : 28, FontWeight.w500).copyWith(color: Z.muted)),
          SizedBox(height: narrow ? 16 : 24),
          Expanded(
            child: RollGrid(
              count: marks.length,
              gap: narrow ? 10 : 16,
              cell: (r) => RollCell(key: ValueKey('roll-$r'), roll: r, mark: marks[r - 1], onTap: () => _cycle(r)),
            ),
          ),
          if (narrow) ...[const SizedBox(height: 16), fills],
        ],
      ),
    );
    final question = ZPanel(
      padding: EdgeInsets.all(narrow ? 28 : 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZTag('${ct('question', l)} ${qi + 1}'),
          const SizedBox(height: 20),
          MathText(q.stem.t(l), style: zText(narrow ? 30 : 40, FontWeight.w500).copyWith(color: Z.ink, height: 1.4), maxLines: portrait ? 3 : null),
          if (!portrait) ...[
            const SizedBox(height: 28),
            for (final (i, o) in q.options.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    _Letter(optionLetters[i], size: 64),
                    const SizedBox(width: 20),
                    Expanded(child: MathText(o.t(l), style: zText(36, FontWeight.w500).copyWith(color: Z.ink))),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    if (portrait) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [question, const SizedBox(height: 20), Expanded(child: grid)]);
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 4, child: question), const SizedBox(width: 32), Expanded(flex: 9, child: grid)]);
  }

  Widget _reveal(BuildContext context, Lang l) {
    final right = _count(Mark.right), wrong = _count(Mark.wrong), none = _count(Mark.none);
    final marked = right + wrong;
    final pct = marked == 0 ? 0 : (100 * right / marked).round();
    final wrongRolls = [for (var r = 1; r <= marks.length; r++) if (marks[r - 1] == Mark.wrong) r];
    final unmarked = [for (var r = 1; r <= marks.length; r++) if (marks[r - 1] == Mark.none) r];
    final narrow = context.narrow;
    Widget bar() => ClipRRect(
      borderRadius: BorderRadius.circular(Z.radius),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            if (right > 0) Expanded(flex: right, child: Container(color: Z.correct)),
            if (wrong > 0) Expanded(flex: wrong, child: Container(color: Z.wrong)),
            if (none > 0) Expanded(flex: none, child: Container(color: Z.track)),
          ],
        ),
      ),
    );
    final summary = ZPanel(
      padding: EdgeInsets.all(narrow ? 28 : 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(ct('classGot', l)),
          Text('$pct%', key: const ValueKey('quizPct'), style: zTitle(narrow ? 96 : 150, FontWeight.w700).copyWith(color: pct >= 70 ? Z.correct : Z.wrong, height: 1.1)),
          Text(ct('ofMarked', l, {'r': right, 'n': marked}), style: zText(narrow ? 30 : 36, FontWeight.w500).copyWith(color: Z.ink2)),
          const SizedBox(height: 28),
          bar(),
          const SizedBox(height: 20),
          _counts(l, size: narrow ? 26 : 30),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Z.correctBg, borderRadius: BorderRadius.circular(Z.radius), border: Border.all(color: Z.correct, width: 3)),
            child: Row(
              children: [
                _Letter(optionLetters[q.answer], size: 80, color: Z.correct),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(ct('answerIs', l), color: Z.correctLabel),
                      MathText(q.options[q.answer].t(l), style: zText(narrow ? 36 : 48, FontWeight.w700).copyWith(color: Z.correct)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final solution = ZPanel(
      padding: EdgeInsets.all(narrow ? 28 : 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(ct('solution', l)),
          const SizedBox(height: 20),
          MathText(q.stem.t(l), style: zText(narrow ? 26 : 30, FontWeight.w400).copyWith(color: Z.muted, height: 1.4), maxLines: 3),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, s) in q.steps.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 26),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 32, backgroundColor: Z.segTrack, child: Text('${i + 1}', style: zText(30, FontWeight.w700).copyWith(color: Z.ink2))),
                          const SizedBox(width: 24),
                          Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: MathText(s.t(l), style: zText(narrow ? 32 : 40, FontWeight.w400).copyWith(color: Z.ink, height: 1.45)))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final revisit = ZPanel(
      padding: EdgeInsets.all(narrow ? 28 : 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ct('revisit', l), style: zTitle(38)),
          const SizedBox(height: 20),
          Wrap(spacing: 14, runSpacing: 14, children: [for (final r in wrongRolls) RollChip(r, size: 38)]),
          if (unmarked.isNotEmpty) ...[
            const SizedBox(height: 32),
            Kicker(ct('notAsked', l)),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 14, children: [for (final r in unmarked) RollChip(r, size: 32, color: Z.ink2, background: Z.segTrack)]),
          ],
          const Spacer(),
          BigButton(icon: Icons.people_alt_outlined, label: ct('pairUp', l), filled: false, onPressed: () {}),
        ],
      ),
    );
    if (context.portrait) {
      return ListView(children: [SizedBox(height: 900, child: summary), const SizedBox(height: 20), SizedBox(height: 900, child: solution), const SizedBox(height: 20), SizedBox(height: 600, child: revisit)]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 5, child: summary), const SizedBox(width: 32), Expanded(flex: 7, child: solution), const SizedBox(width: 32), Expanded(flex: 4, child: revisit)]);
  }
}

class _Letter extends StatelessWidget {
  const _Letter(this.letter, {this.size = 88, this.color});
  final String letter;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color ?? Z.segTrack, borderRadius: BorderRadius.circular(Z.radius)),
    child: Text(letter, style: zText(size * 0.48, FontWeight.w700).copyWith(color: color == null ? Z.ink2 : Colors.white)),
  );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.letter, required this.text, required this.size});
  final String letter, text;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size * 0.7),
    decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.radius), border: Border.all(color: Z.line, width: 3)),
    child: Row(
      children: [
        _Letter(letter, size: size * 1.8),
        SizedBox(width: size * 0.6),
        Expanded(child: MathText(text, style: zText(size, FontWeight.w500).copyWith(color: Z.ink))),
      ],
    ),
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.label, this.n, this.color, this.bg, {this.size = 34});
  final String label;
  final int n;
  final Color color, bg;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size * 0.7, vertical: size * 0.3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Z.radius)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$n', style: zText(size * 1.4, FontWeight.w700).copyWith(color: color)),
        SizedBox(width: size * 0.35),
        Text(label, style: zText(size, FontWeight.w600).copyWith(color: color)),
      ],
    ),
  );
}
