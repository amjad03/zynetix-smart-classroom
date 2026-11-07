import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../blocks/math_text.dart';
import '../../core/services.dart';
import '../../engine/mastery.dart';
import '../../engine/model.dart';
import 'help.dart';
import 'kit.dart';
import 'now.dart';
import 'school.dart';

const _pad = 140.0;

/// The chapter's questions the class can answer aloud: single-answer ones with options.
List<Question> quizQuestions(InstalledPack pack, {String? topicId, int n = 5}) {
  bool ok(Question q) => q.options.length >= 2 && !q.isMulti && !q.isNumeric;
  final topic = [for (final q in pack.questions.values) if (ok(q) && q.topicId == topicId) q];
  final rest = [for (final q in pack.questions.values) if (ok(q) && q.topicId != topicId) q];
  return [...topic, ...rest].take(n).toList();
}

/// Home's "Quiz the class": five questions on the lesson in hand.
Future<void> openSimpleQuiz(BuildContext context, ClassNow c) async {
  final l = ServicesScope.of(context).config.lang;
  final qs = c.hasLesson ? quizQuestions(c.pack!, topicId: c.lesson!.topicId) : const <Question>[];
  if (qs.isEmpty) {
    toast(context, tr(l, 'No questions for this lesson yet. Open Teach a lesson to pick a chapter.', 'ಈ ಪಾಠಕ್ಕೆ ಇನ್ನೂ ಪ್ರಶ್ನೆಗಳಿಲ್ಲ.'));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SimpleQuizScreen(pack: c.pack!, questions: qs)));
}

/// 09 · Quiz the class: the question big, then tap the roll numbers who got it right. Done saves
/// the marks (by roll number) to the class's results and mastery, and gives the houses XP.
class SimpleQuizScreen extends StatefulWidget {
  const SimpleQuizScreen({super.key, required this.pack, required this.questions, this.practice = false, this.onDone});
  final InstalledPack pack;
  final List<Question> questions;

  /// Practice: marks are not saved.
  final bool practice;
  final VoidCallback? onDone;
  @override
  State<SimpleQuizScreen> createState() => _SimpleQuizScreenState();
}

class _SimpleQuizScreenState extends State<SimpleQuizScreen> {
  late final Services s = ServicesScope.of(context);
  int qi = 0;
  bool shown = false;
  final Set<int> right = {};
  final _done = GlobalKey(), _grid = GlobalKey(), _show = GlobalKey();
  final List<UndoItem> _mine = [];

  Question get q => widget.questions[qi];

  @override
  void dispose() {
    // Taps on a closed quiz cannot be undone any more.
    final mine = _mine.toSet();
    s.school.dropUndo(mine.contains);
    super.dispose();
  }

  void _tap(int roll) {
    void flip() => setState(() => right.contains(roll) ? right.remove(roll) : right.add(roll));
    final was = right.contains(roll);
    flip();
    s.school.pushUndo(L10n(was ? 'Unmarked roll $roll' : 'Marked roll $roll right', was ? 'ರೋಲ್ $roll ಗುರುತು ತೆಗೆದದ್ದು' : 'ರೋಲ್ $roll ಸರಿ ಎಂದು ಗುರುತು'), () {
      if (mounted) flip();
    });
    _mine.add(s.school.lastUndo!);
  }

  void _doneQuestion() {
    final n = s.config.rollCount;
    if (!widget.practice) {
      final now = s.clock();
      final wrong = [for (var r = 1; r <= n; r++) if (!right.contains(r)) r];
      final result = QuizResult(id: 'q${now.microsecondsSinceEpoch}', at: now, questionId: q.id, topicId: q.topicId ?? '', chapterId: q.chapterId ?? widget.pack.chapter.id, right: right.toList()..sort(), wrong: wrong);
      s.school.addQuiz(result);
      s.mastery.recordAll([
        for (var r = 1; r <= n; r++) Response(roll: r, questionId: q.id, topicId: q.topicId ?? '', chapterId: result.chapterId, correct: right.contains(r), source: 'roll_call', at: now),
      ]);
      // Ten XP a right answer to the roll number's house.
      final houses = s.school.houses;
      for (final (i, h) in houses.indexed) {
        final xp = right.where(h.has).length * 10;
        if (xp > 0) s.school.addXp(i, xp);
      }
      s.school.markStreakDay(now);
      s.school.pushUndo(L10n('Saved question ${qi + 1}', 'ಪ್ರಶ್ನೆ ${qi + 1} ಉಳಿಸಿದ್ದು'), () {
        s.school.removeQuiz(result.id);
        final hs = s.school.houses;
        for (final (i, h) in hs.indexed) {
          final xp = result.right.where(h.has).length * 10;
          if (xp > 0) hs[i] = hs[i].copyWith(xp: math.max(0, hs[i].xp - xp));
        }
        s.school.setHouses(hs);
      });
    }
    if (qi == widget.questions.length - 1) {
      widget.onDone?.call();
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      qi++;
      shown = false;
      right.clear();
    });
  }

  HelpInfo _help() => right.isEmpty
      ? HelpInfo(
          next: const L10n('Read the question out. Then tap the roll numbers who got it right.', 'ಪ್ರಶ್ನೆಯನ್ನು ಓದಿ. ನಂತರ ಸರಿ ಉತ್ತರಿಸಿದ ರೋಲ್ ನಂಬರ್‌ಗಳನ್ನು ಒತ್ತಿ.'),
          detail: const L10n('Everyone you don’t tap counts as not right yet.', 'ನೀವು ಒತ್ತದವರು ಇನ್ನೂ ಸರಿಯಿಲ್ಲ ಎಂದು ಎಣಿಕೆ.'),
          target: _grid,
          undo: () => null,
        )
      : HelpInfo(next: const L10n('When you have marked everyone, tap Done.', 'ಎಲ್ಲರನ್ನೂ ಗುರುತಿಸಿದ ಮೇಲೆ “ಮುಗಿಯಿತು” ಒತ್ತಿ.'), detail: const L10n('Tapped the wrong number? Tap it again, or use Undo.', 'ತಪ್ಪು ನಂಬರ್ ಒತ್ತಿದಿರಾ? ಮತ್ತೆ ಒತ್ತಿ ಅಥವಾ ರದ್ದು ಬಳಸಿ.'), target: _done);

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final phone = usePhoneLayout(context);
      final n = s.config.rollCount;
      final keyLetters = ['A', 'B', 'C', 'D', 'E', 'F'];
      final mathStyle = tx(phone ? 34 : 42, c: S.ink, w: FontWeight.w500, h: 1.2);
      final question = Container(
        padding: EdgeInsets.fromLTRB(phone ? 36 : 60, phone ? 36 : 56, phone ? 36 : 60, phone ? 36 : 56),
        decoration: BoxDecoration(color: S.lavender, borderRadius: BorderRadius.circular(56)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(l, 'Read it out to the class', 'ತರಗತಿಗೆ ಓದಿ ಹೇಳಿ'), style: tx(34, c: S.eyebrow, w: FontWeight.w600)),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MathText(q.stem.t(l), style: hd(phone ? 52 : 72, l: l)),
                const SizedBox(height: 36),
                for (final (k, o) in q.options.indexed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.fromLTRB(20, 18, 28, 18),
                    decoration: BoxDecoration(color: shown && k == q.answer ? S.mint : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: shown && k == q.answer ? S.green : Colors.transparent, width: 4)),
                    child: Row(children: [
                      Container(width: 76, height: 76, decoration: BoxDecoration(color: shown && k == q.answer ? S.green : S.soft, shape: BoxShape.circle), alignment: Alignment.center, child: Text(keyLetters[k], style: tx(38, c: shown && k == q.answer ? Colors.white : S.violet, w: FontWeight.w700, h: 1))),
                      const SizedBox(width: 26),
                      Expanded(child: MathText(o.t(l), style: mathStyle)),
                    ]),
                  ),
                if (shown && (q.solution.isNotEmpty || q.explanation != null)) ...[
                  const SizedBox(height: 12),
                  Text(tr(l, 'Solution', 'ಪರಿಹಾರ'), style: tx(32, c: S.eyebrow, w: FontWeight.w600)),
                  for (final st in q.solution.isNotEmpty ? q.solution : [q.explanation!]) Padding(padding: const EdgeInsets.only(top: 8), child: MathText(st.t(l), style: tx(phone ? 28 : 34, c: S.cardText))),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            KeyedSubtree(
              key: _show,
              child: ZxButton(shown ? tr(l, 'Hide the answer', 'ಉತ್ತರ ಮರೆಮಾಡಿ') : tr(l, 'Show the answer', 'ಉತ್ತರ ತೋರಿಸಿ'), key: const ValueKey('showAnswer'), icon: shown ? Icons.visibility_off_rounded : Icons.visibility_rounded, bg: Colors.white, fg: S.ink, height: phone ? 100 : 120, size: phone ? 30 : 36, onTap: () => setState(() => shown = !shown)),
            ),
            const SizedBox(width: 20),
            if (!shown && !phone) Flexible(child: Tag(tr(l, 'Answer hidden', 'ಉತ್ತರ ಮರೆಯಲ್ಲಿದೆ'), icon: Icons.lock_outline_rounded, size: 30)),
          ]),
        ]),
      );
      Widget cell(int r, double w, double h) {
        final on = right.contains(r);
        return Press(
          key: ValueKey('roll-$r'),
          radius: 32,
          onTap: () => _tap(r),
          child: Container(
            width: w, height: h,
            decoration: BoxDecoration(color: on ? S.mint : S.mist, borderRadius: BorderRadius.circular(32), border: Border.all(color: on ? S.green : Colors.transparent, width: 4)),
            child: Stack(children: [
              Center(child: Text('$r', style: hd(math.min(64, h * .45), c: on ? S.green : S.ink))),
              if (on) Positioned(top: 12, right: 12, child: Icon(Icons.check_circle_rounded, size: math.min(40, h * .28), color: S.green)),
            ]),
          ),
        );
      }

      final grid = LayoutBuilder(
        key: _grid,
        builder: (context, box) {
          const gap = 20.0;
          final cols = phone ? 6 : 8;
          final rows = (n / cols).ceil();
          final w = (box.maxWidth - gap * (cols - 1)) / cols;
          final h = phone ? 100.0 : math.max(90.0, math.min(150.0, (box.maxHeight - gap * (rows - 1)) / rows));
          return SingleChildScrollView(child: Wrap(spacing: gap, runSpacing: gap, children: [for (var r = 1; r <= n; r++) cell(r, w, h)]));
        },
      );
      final counts = Wrap(spacing: 16, runSpacing: 12, children: [
        Tag(tr(l, '${right.length} got it right', '${right.length} ಸರಿ'), icon: Icons.check_circle_rounded, bg: S.greenSoft, fg: S.green, size: 34),
        Tag(tr(l, '${n - right.length} not yet', '${n - right.length} ಇನ್ನೂ ಇಲ್ಲ'), bg: S.mist, size: 34),
      ]);
      final done = KeyedSubtree(
        key: _done,
        child: ZxButton(tr(l, 'Done', 'ಮುಗಿಯಿತು'), key: const ValueKey('quizDone'), icon: Icons.check_rounded, bg: S.violet, height: phone ? 130 : 170, size: phone ? 40 : 52, shadow: true, onTap: _doneQuestion),
      );
      final progress = StepProgress(step: qi + 1, of: widget.questions.length, dark: false, width: phone ? 200 : 420, size: phone ? 26 : 34, lang: l);
      final top = Row(children: [
        ZxButton(widget.practice ? tr(l, 'Back to practice', 'ಅಭ್ಯಾಸಕ್ಕೆ') : tr(l, 'Back', 'ಹಿಂದೆ'), key: const ValueKey('quizBack'), icon: Icons.arrow_back_rounded, bg: S.mist, fg: S.ink, height: phone ? 96 : 120, size: phone ? 28 : 36, onTap: () => Navigator.of(context).maybePop()),
        SizedBox(width: phone ? 20 : 40),
        if (!phone) Text(tr(l, 'Quiz the class', 'ತರಗತಿಗೆ ಪ್ರಶ್ನೆ'), style: hd(64, l: l)),
        const Spacer(),
        if (phone) Flexible(flex: 4, child: progress) else progress,
        SizedBox(width: phone ? 16 : 24),
        HelpChip(info: _help),
      ]);
      if (phone) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                top,
                const SizedBox(height: 24),
                Expanded(flex: 5, child: question),
                const SizedBox(height: 24),
                Text(tr(l, 'Tap who got it right', 'ಸರಿ ಉತ್ತರಿಸಿದವರನ್ನು ಒತ್ತಿ'), style: hd(44, l: l)),
                const SizedBox(height: 16),
                Expanded(flex: 4, child: grid),
                const SizedBox(height: 16),
                counts,
                const SizedBox(height: 16),
                done,
              ]),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.white,
        body: DesignCanvas(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_pad, 60, _pad, 60),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              top,
              const SizedBox(height: 52),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(width: 1060, child: question),
                  const SizedBox(width: 80),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(l, 'Tap the roll numbers who got it right', 'ಸರಿ ಉತ್ತರಿಸಿದ ರೋಲ್ ನಂಬರ್‌ಗಳನ್ನು ಒತ್ತಿ'), style: hd(72, l: l)),
                      const SizedBox(height: 14),
                      Text(tr(l, 'Everyone you don’t tap counts as not right yet. Tap again to undo.', 'ನೀವು ಒತ್ತದವರು ಇನ್ನೂ ಸರಿಯಿಲ್ಲ. ರದ್ದುಮಾಡಲು ಮತ್ತೆ ಒತ್ತಿ.'), style: tx(38)),
                      const SizedBox(height: 40),
                      Expanded(child: grid),
                      const SizedBox(height: 28),
                      Row(children: [Expanded(child: counts), const SizedBox(width: 24), SizedBox(width: 640, child: done)]),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
    },
  );
}
