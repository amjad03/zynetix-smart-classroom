import 'package:flutter/material.dart';
import 'package:kinetix_ink/kinetix_ink.dart' show InkCanvas, InkController, InkStyle, InkTool;

import '../../core/services.dart';
import '../../engine/model.dart';
import 'help.dart';
import 'kit.dart';
import 'lesson.dart' show FinishClassScreen, stageGradient;
import 'quiz.dart';
import 'school.dart';

const _pad = 140.0;
const _sun = Color(0xFFFFC857);

Future<void> openPractice(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PracticeClassScreen()));

/// The pretend lesson: why things fall, in four steps.
const _steps = [
  (L10n('Why do things fall?', 'ವಸ್ತುಗಳು ಏಕೆ ಬೀಳುತ್ತವೆ?'), L10n('Hold up a pen and let it go. Ask the class: why did it go down, not up?', 'ಒಂದು ಪೆನ್ ಎತ್ತಿ ಬಿಡಿ. ತರಗತಿಯನ್ನು ಕೇಳಿ: ಅದು ಏಕೆ ಕೆಳಗೆ ಹೋಯಿತು, ಮೇಲೆ ಅಲ್ಲ?')),
  (L10n('Everything falls towards the Earth.', 'ಎಲ್ಲವೂ ಭೂಮಿಯ ಕಡೆಗೆ ಬೀಳುತ್ತದೆ.'), L10n('A stone and a leaf both fall down, never up. That pull is called gravity.', 'ಕಲ್ಲು ಮತ್ತು ಎಲೆ ಎರಡೂ ಕೆಳಗೆ ಬೀಳುತ್ತವೆ, ಮೇಲೆ ಎಂದಿಗೂ ಅಲ್ಲ. ಆ ಸೆಳೆತವೇ ಗುರುತ್ವ.')),
  (L10n('The Earth pulls everything.', 'ಭೂಮಿ ಎಲ್ಲವನ್ನೂ ಸೆಳೆಯುತ್ತದೆ.'), L10n('The pull is the same for everyone in this room: about 9.8 m/s² of speeding up every second.', 'ಈ ಕೋಣೆಯಲ್ಲಿ ಎಲ್ಲರಿಗೂ ಸೆಳೆತ ಒಂದೇ: ಪ್ರತಿ ಸೆಕೆಂಡಿಗೆ ಸುಮಾರು 9.8 m/s².')),
  (L10n('So why does a leaf fall slowly?', 'ಹಾಗಾದರೆ ಎಲೆ ಏಕೆ ನಿಧಾನವಾಗಿ ಬೀಳುತ್ತದೆ?'), L10n('Air pushes back on the wide leaf. With no air, a leaf and a stone land together.', 'ಅಗಲವಾದ ಎಲೆಯನ್ನು ಗಾಳಿ ಹಿಂದಕ್ಕೆ ತಳ್ಳುತ್ತದೆ. ಗಾಳಿ ಇಲ್ಲದಿದ್ದರೆ ಎಲೆ ಮತ್ತು ಕಲ್ಲು ಒಟ್ಟಿಗೆ ಬೀಳುತ್ತವೆ.')),
];

final _pretendChapter = Chapter(id: 'practice', subject: 'physics', year: 'puc1', number: 0, title: const L10n('Practice', 'ಅಭ್ಯಾಸ'), topics: const []);
final _pretendPack = InstalledPack(
  id: 'practice',
  version: '0',
  chapter: _pretendChapter,
  lessons: const {},
  questions: {
    'p1': Question(
      id: 'p1',
      topicId: 'practice.t1',
      stem: const L10n('You drop a stone and a feather where there is no air. Which lands first?', 'ಗಾಳಿ ಇಲ್ಲದ ಕಡೆ ಕಲ್ಲು ಮತ್ತು ಗರಿ ಬಿಟ್ಟರೆ ಯಾವುದು ಮೊದಲು ಬೀಳುತ್ತದೆ?'),
      options: const [L10n('They land together', 'ಒಟ್ಟಿಗೆ ಬೀಳುತ್ತವೆ'), L10n('The stone', 'ಕಲ್ಲು'), L10n('The feather', 'ಗರಿ'), L10n('Neither falls', 'ಯಾವುದೂ ಬೀಳುವುದಿಲ್ಲ')],
      answer: 0,
      exams: const [],
      difficulty: 'easy',
      explanation: const L10n('With no air pushing back, gravity speeds both up the same.', 'ಗಾಳಿಯ ತಡೆ ಇಲ್ಲದಿದ್ದರೆ ಗುರುತ್ವ ಎರಡನ್ನೂ ಸಮನಾಗಿ ವೇಗಗೊಳಿಸುತ್ತದೆ.'),
    ),
  },
  mediaDir: '',
);

/// 05 · Practice class: a pretend lesson whose checklist ticks itself as the teacher tries
/// things. Nothing here is saved.
class PracticeClassScreen extends StatefulWidget {
  const PracticeClassScreen({super.key});
  @override
  State<PracticeClassScreen> createState() => _PracticeClassScreenState();
}

class _PracticeClassScreenState extends State<PracticeClassScreen> {
  int step = 0;
  bool pen = false;
  final done = <int>{0};
  final ink = InkController(style: const InkStyle(tool: InkTool.pen, color: _sun, width: 8));
  final _write = GlobalKey(), _quiz = GlobalKey(), _next = GlobalKey(), _finish = GlobalKey();

  @override
  void initState() {
    super.initState();
    ink.addListener(() {
      if (ink.canUndo && !done.contains(2)) setState(() => done.add(2));
    });
  }

  @override
  void dispose() {
    ink.dispose();
    super.dispose();
  }

  int get _now => [0, 1, 2, 3, 4].firstWhere((i) => !done.contains(i), orElse: () => 5);

  void _nextStep() {
    if (step < _steps.length - 1) {
      setState(() {
        step++;
        done.add(1);
        ink.clear();
      });
    }
  }

  Future<void> _quizNow() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SimpleQuizScreen(pack: _pretendPack, questions: _pretendPack.questions.values.toList(), practice: true, onDone: () => done.add(3))));
    if (mounted) setState(() {});
  }

  void _finishNow() {
    final s = ServicesScope.of(context);
    setState(() => done.add(4));
    final r = ClassRecord(
      id: 'practice',
      at: s.clock(),
      subject: 'physics',
      topicId: 'practice',
      topic: _steps.first.$1,
      chapter: const L10n('Practice class', 'ಅಭ್ಯಾಸ ತರಗತಿ'),
      stepsSeen: step + 1,
      stepsTotal: _steps.length,
      minutes: 3,
      homework: s.config.lang == Lang.kn ? 'ಒಂದು ಪೆನ್ ಮತ್ತು ಕಾಗದ ಒಟ್ಟಿಗೆ ಬಿಡಿ. ಯಾವುದು ಮೊದಲು ಬೀಳುತ್ತದೆ?' : 'Drop a pen and a sheet of paper together. Which lands first?',
      rollCount: s.config.rollCount,
    );
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FinishClassScreen(recordId: 'practice', practice: r)));
  }

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final phone = usePhoneLayout(context);
      final tasks = [
        (tr(l, 'Open the lesson', 'ಪಾಠ ತೆರೆಯಿರಿ'), tr(l, 'Done. Well done!', 'ಆಯಿತು. ಚೆನ್ನಾಗಿದೆ!'), ''),
        (tr(l, 'Go to the next step', 'ಮುಂದಿನ ಹಂತಕ್ಕೆ ಹೋಗಿ'), tr(l, 'Done. You tapped Next.', 'ಆಯಿತು. ನೀವು “ಮುಂದೆ” ಒತ್ತಿದಿರಿ.'), tr(l, 'Tap Next at the bottom right.', 'ಕೆಳಗೆ ಬಲಭಾಗದಲ್ಲಿ “ಮುಂದೆ” ಒತ್ತಿ.')),
        (tr(l, 'Write one word on the board', 'ಬೋರ್ಡ್‌ನಲ್ಲಿ ಒಂದು ಪದ ಬರೆಯಿರಿ'), tr(l, 'Done. Nice writing!', 'ಆಯಿತು. ಚೆನ್ನಾಗಿ ಬರೆದಿರಿ!'), tr(l, 'Tap Write at the bottom, then write any word.', 'ಕೆಳಗೆ “ಬರೆಯಿರಿ” ಒತ್ತಿ, ಯಾವುದೇ ಪದ ಬರೆಯಿರಿ.')),
        (tr(l, 'Quiz the class', 'ತರಗತಿಗೆ ಪ್ರಶ್ನೆ ಕೇಳಿ'), tr(l, 'Done. Marks are easy!', 'ಆಯಿತು. ಗುರುತಿಸುವುದು ಸುಲಭ!'), tr(l, 'Tap Quiz and pretend to mark a few roll numbers.', '“ಪ್ರಶ್ನೆ” ಒತ್ತಿ, ಕೆಲವು ರೋಲ್ ನಂಬರ್ ಗುರುತಿಸಿ.')),
        (tr(l, 'Finish class', 'ತರಗತಿ ಮುಗಿಸಿ'), tr(l, 'Done. You are ready!', 'ಆಯಿತು. ನೀವು ಸಿದ್ಧ!'), tr(l, 'Tap Finish class to see your summary.', 'ಸಾರಾಂಶ ನೋಡಲು “ತರಗತಿ ಮುಗಿಸಿ” ಒತ್ತಿ.')),
      ];
      final now = _now;
      final targets = [null, _next, _write, _quiz, _finish];
      HelpInfo help() => now >= 5
          ? const HelpInfo(next: L10n('You have tried everything. Tap Leave practice and start your real class.', 'ಎಲ್ಲಾ ಪ್ರಯತ್ನಿಸಿದಿರಿ. “ಅಭ್ಯಾಸ ಬಿಡಿ” ಒತ್ತಿ, ನಿಜವಾದ ತರಗತಿ ಪ್ರಾರಂಭಿಸಿ.'))
          : HelpInfo(next: L10n(tasks[now].$3.isEmpty ? tasks[now].$1 : tasks[now].$3, tasks[now].$3.isEmpty ? tasks[now].$1 : tasks[now].$3), target: targets[now], undo: () => ink.canUndo ? LocalUndo(const L10n('What you wrote', 'ನೀವು ಬರೆದದ್ದು'), ink.undo) : null);
      Widget glow(int i, Widget w) => i == now
          ? Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(46), boxShadow: const [BoxShadow(color: Color(0xAAFFC857), blurRadius: 50, spreadRadius: 6)]), child: w)
          : w;
      final k = phone ? .6 : 1.0;
      final stage = Container(
        decoration: stageGradient.copyWith(borderRadius: BorderRadius.circular(56)),
        padding: EdgeInsets.fromLTRB(72 * k, 56 * k, 72 * k, 48 * k),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(tr(l, 'Pretend lesson · Why do things fall?', 'ಅಭ್ಯಾಸ ಪಾಠ · ವಸ್ತುಗಳು ಏಕೆ ಬೀಳುತ್ತವೆ?'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(38 * k, c: const Color(0xFFC9CBE6), w: FontWeight.w600))),
            StepProgress(step: step + 1, of: _steps.length, width: 380 * k, size: 32 * k, lang: l),
          ]),
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_steps[step].$1.t(l), key: const ValueKey('practiceStep'), style: hd(104 * k, c: Colors.white, l: l)),
                  SizedBox(height: 28 * k),
                  Text(_steps[step].$2.t(l), style: tx(46 * k, c: const Color(0xFFE6E8FF))),
                ]),
              ),
              if (pen) Positioned.fill(child: InkCanvas(controller: ink, transparent: true)),
            ]),
          ),
          (phone ? (List<Widget> c) => Wrap(spacing: 16, runSpacing: 16, children: [for (final w in c) if (w is! Spacer) w]) : (List<Widget> c) => Row(children: c))([
            ZxButton(tr(l, 'Back', 'ಹಿಂದೆ'), icon: Icons.arrow_back_rounded, bg: const Color(0x26FFFFFF), height: 150 * k, size: 44 * k, onTap: step == 0 ? null : () => setState(() => step--)),
            const Spacer(),
            KeyedSubtree(key: _write, child: glow(2, Press(key: const ValueKey('practiceWrite'), radius: 36, onTap: () => setState(() => pen = !pen), child: ToolButton(tr(l, 'Write', 'ಬರೆಯಿರಿ'), Icons.edit_rounded, bg: pen || now == 2 ? _sun : const Color(0x1FFFFFFF), fg: pen || now == 2 ? S.ink : Colors.white, width: 240 * (phone ? .8 : 1), height: 150 * (phone ? .8 : 1))))),
            SizedBox(width: 24 * k),
            KeyedSubtree(key: _quiz, child: glow(3, Press(key: const ValueKey('practiceQuiz'), radius: 36, onTap: _quizNow, child: ToolButton(tr(l, 'Quiz', 'ಪ್ರಶ್ನೆ'), Icons.quiz_rounded, width: 240 * (phone ? .8 : 1), height: 150 * (phone ? .8 : 1), bg: now == 3 ? _sun : const Color(0x1FFFFFFF), fg: now == 3 ? S.ink : Colors.white)))),
            const Spacer(),
            KeyedSubtree(
              key: step == _steps.length - 1 ? _finish : _next,
              child: glow(
                step == _steps.length - 1 ? 4 : 1,
                step == _steps.length - 1
                    ? ZxButton(tr(l, 'Finish class', 'ತರಗತಿ ಮುಗಿಸಿ'), key: const ValueKey('practiceFinish'), trailing: Icons.flag_rounded, bg: S.violet, height: 150 * k, size: 48 * k, onTap: _finishNow)
                    : ZxButton(tr(l, 'Next', 'ಮುಂದೆ'), key: const ValueKey('practiceNext'), trailing: Icons.arrow_forward_rounded, bg: S.violet, height: 150 * k, size: 48 * k, onTap: _nextStep),
              ),
            ),
          ]),
        ]),
      );
      final list = Container(
        padding: EdgeInsets.fromLTRB(60 * k, 56 * k, 60 * k, 52 * k),
        decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(56)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(l, 'Your practice', 'ನಿಮ್ಮ ಅಭ್ಯಾಸ'), style: hd(76 * k, l: l)),
          SizedBox(height: 14 * k),
          Row(children: [
            Text(tr(l, '${done.length} of 5 done', '5 ರಲ್ಲಿ ${done.length} ಆಯಿತು'), key: const ValueKey('practiceCount'), style: tx(36 * k, c: S.green, w: FontWeight.w700)),
            SizedBox(width: 24 * k),
            Expanded(
              child: Container(
                height: 18 * k,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(color: S.line, borderRadius: BorderRadius.circular(99)),
                child: FractionallySizedBox(widthFactor: done.length / 5, child: Container(decoration: BoxDecoration(color: S.green, borderRadius: BorderRadius.circular(99)))),
              ),
            ),
          ]),
          SizedBox(height: 36 * k),
          Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (i, (t, ok, hint)) in tasks.indexed)
            Container(
              margin: EdgeInsets.only(bottom: 18 * k),
              padding: EdgeInsets.fromLTRB(28 * k, 24 * k, 28 * k, 24 * k),
              decoration: BoxDecoration(
                color: i == now ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(36),
                border: i == now ? Border.all(color: S.violet, width: 5) : null,
                boxShadow: i == now ? S.shadowSoft : null,
              ),
              child: Row(children: [
                Tick(done: done.contains(i), now: i == now, n: i + 1, size: 80 * k),
                SizedBox(width: 30 * k),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(42 * k, c: done.contains(i) ? S.muted : S.ink, w: FontWeight.w700, h: 1.2).copyWith(decoration: done.contains(i) ? TextDecoration.lineThrough : null, decorationColor: S.muted)),
                    if (done.contains(i) || i == now) Text(done.contains(i) ? ok : hint, style: tx(30 * k, c: done.contains(i) ? S.green : S.violet, w: FontWeight.w500, h: 1.3)),
                  ]),
                ),
              ]),
            ),
          ]))),
          SizedBox(height: 12 * k),
          SafeLine(maxLines: 2, tr(l, 'You can’t break anything — this is just practice.', 'ನೀವು ಏನನ್ನೂ ಹಾಳುಮಾಡಲಾರಿರಿ — ಇದು ಕೇವಲ ಅಭ್ಯಾಸ.'), size: 36 * k),
        ]),
      );
      final header = Container(
        padding: EdgeInsets.fromLTRB(44 * k, 22 * k, 22 * k, 22 * k),
        decoration: BoxDecoration(color: S.butter, borderRadius: BorderRadius.circular(999)),
        child: Row(children: [
          Icon(Icons.school_rounded, size: 56 * k, color: S.ink),
          SizedBox(width: 20 * k),
          Expanded(
            child: Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(tr(l, 'Practice class', 'ಅಭ್ಯಾಸ ತರಗತಿ'), maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(54 * k, l: l)),
              if (!phone) ...[
                Tag(tr(l, '3 minutes', '3 ನಿಮಿಷ'), icon: Icons.timer_outlined, size: 30),
                Tag(tr(l, 'Nothing here is saved', 'ಇಲ್ಲಿ ಏನೂ ಉಳಿಯುವುದಿಲ್ಲ'), icon: Icons.lock_open_rounded, size: 30),
              ],
            ]),
          ),
          HelpChip(info: help),
          SizedBox(width: 20 * k),
          ZxButton(tr(l, 'Leave practice', 'ಅಭ್ಯಾಸ ಬಿಡಿ'), key: const ValueKey('leavePractice'), icon: Icons.close_rounded, bg: Colors.white, fg: S.ink, height: 112 * k, size: 34 * k, onTap: () => Navigator.of(context).maybePop()),
        ]),
      );
      if (phone) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: 24), Expanded(flex: 5, child: stage), const SizedBox(height: 24), Expanded(flex: 5, child: list)]),
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
              header,
              const SizedBox(height: 44),
              Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: stage), const SizedBox(width: 48), SizedBox(width: 1000, child: list)])),
            ]),
          ),
        ),
      );
    },
  );
}
