import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kinetix_ink/kinetix_ink.dart' show InkCanvas, InkController, InkStyle, InkTool;

import '../../blocks/block_view.dart';
import '../../core/services.dart';
import '../../engine/auto_play.dart';
import '../../engine/lesson_controller.dart';
import '../../engine/model.dart';
import '../../engine/session_log.dart';
import '../insight/reteach.dart' show teacherQuizDone;
import '../participation.dart' show ClassRoom;
import 'help.dart';
import 'kit.dart';
import 'now.dart';
import 'school.dart';

const _pad = 140.0;
const _stageA = Color(0xFF0E1033), _stageB = Color(0xFF1D2266);
const _sun = Color(0xFFFFC857);
const stageGradient = BoxDecoration(gradient: LinearGradient(colors: [_stageA, _stageB], begin: Alignment.topLeft, end: Alignment.bottomRight));

/// 06 · A lesson in simple class mode: the content big, a giant Back and Next, and three named
/// helpers (Write, Pause voice, Help). It opens where the class left off, remembers each step,
/// and Finish class leads to the summary that is saved in the class history.
class SimpleLessonScreen extends StatefulWidget {
  const SimpleLessonScreen({super.key, required this.pack, required this.lesson, this.period, this.startStep, this.preview = false});
  final InstalledPack pack;
  final Lesson lesson;
  final Period? period;

  /// One thing from the Library on the board: no progress saved and no Finish class.
  final bool preview;

  /// Open on this step instead of where it was left.
  final int? startStep;
  @override
  State<SimpleLessonScreen> createState() => _SimpleLessonScreenState();
}

class _SimpleLessonScreenState extends State<SimpleLessonScreen> {
  late final Services s = ServicesScope.of(context);
  late final LessonController c = LessonController(
    pack: widget.pack,
    lesson: widget.pack.lessonFor(widget.lesson, s.config.board),
    narrator: s.narrator,
    lang: s.config.lang,
    recorder: SessionRecorder(outbox: s.outbox, sectionId: s.config.sectionId, mode: 'teacher', pack: widget.pack, lesson: widget.lesson, now: s.clock, mastery: s.mastery),
  );
  late final ClassRoom room = ClassRoom(rollCount: s.config.rollCount);
  late final bool voiced = c.lesson.blocks.any((b) => b.raw['voice'] is List);
  late final AutoPlayer auto = AutoPlayer(
    c: c,
    player: s.voicePlayer(),
    trackFor: (l) => s.voice?.track(widget.pack, c.lesson, l),
    mode: s.config.playMode == 'auto' && s.voice?.track(widget.pack, c.lesson, c.lang) != null ? PlayMode.auto : PlayMode.manual,
  );
  final ink = InkController(style: const InkStyle(tool: InkTool.pen, color: _sun, width: 6));
  final _next = GlobalKey(), _finishKey = GlobalKey(), _write = GlobalKey(), _voiceKey = GlobalKey();
  late final DateTime _opened = s.clock();
  Timer? _tick;
  bool _started = false, _finished = false;
  int _maxSeen = 0, _last = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final step = (widget.startStep ?? (widget.preview ? 0 : s.school.stepFor(widget.lesson.topicId))).clamp(0, c.blocks.length - 1);
    if (step > 0) c.goTo(step);
    _last = _maxSeen = c.index;
    c.addListener(_onChange);
    if (voiced) auto.start();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onChange() {
    if (c.index != _last) {
      ink.clear();
      _last = c.index;
      _maxSeen = math.max(_maxSeen, c.index);
      if (!widget.preview) s.school.setStep(widget.lesson.topicId, c.index);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (!_finished) c.finish(completed: false);
    auto.dispose();
    auto.player.dispose();
    c.removeListener(_onChange);
    c.dispose();
    ink.dispose();
    super.dispose();
  }

  int? get _minutesLeft {
    final p = widget.period;
    if (p == null) return null;
    final now = s.clock();
    final left = p.endMin - (now.hour * 60 + now.minute);
    return left > 0 && left <= p.endMin - p.startMin ? left : null;
  }

  bool get _atEnd => c.isLast && c.revealDone;

  Future<void> _finishClass() async {
    if (widget.preview) {
      Navigator.of(context).maybePop();
      return;
    }
    _finished = true;
    final complete = _atEnd || _maxSeen >= c.blocks.length - 1;
    c.finish(completed: complete);
    if (complete) await s.config.markTaught(widget.lesson.topicId);
    // Next time this lesson opens at the start if it was finished, else where it stopped.
    s.school.setStep(widget.lesson.topicId, complete ? 0 : c.index);
    final recap = c.lesson.blocks.where((b) => b.type == BlockType.recap).lastOrNull;
    final hw = recap == null ? const <L10n>[] : L10n.list(recap.raw['homework']);
    final t = s.school.current;
    final record = ClassRecord(
      id: 'c${s.clock().microsecondsSinceEpoch}',
      at: s.clock(),
      subject: widget.pack.chapter.subject,
      topicId: widget.lesson.topicId,
      topic: widget.lesson.title,
      chapter: widget.pack.chapter.title,
      stepsSeen: complete ? c.blocks.length : _maxSeen + 1,
      stepsTotal: c.blocks.length,
      minutes: math.max(1, s.clock().difference(_opened).inMinutes),
      teacherId: t?.id,
      teacherName: t?.name ?? '',
      homework: hw.map((h) => h.t(c.lang)).join('\n'),
      rollCount: s.config.rollCount,
    );
    s.school.addClass(record);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => FinishClassScreen(recordId: record.id, period: widget.period)));
  }

  HelpInfo _help() {
    final left = _minutesLeft;
    final where = L10n(
      'You are on step ${c.index + 1} of ${c.blocks.length}.${left == null ? '' : ' About $left minutes to go.'}',
      'ನೀವು ${c.blocks.length} ರಲ್ಲಿ ${c.index + 1}ನೇ ಹಂತದಲ್ಲಿದ್ದೀರಿ.${left == null ? '' : ' ಸುಮಾರು $left ನಿಮಿಷ ಉಳಿದಿದೆ.'}',
    );
    LocalUndo? undo() => ink.canUndo ? LocalUndo(const L10n('What you wrote on this step', 'ಈ ಹಂತದಲ್ಲಿ ನೀವು ಬರೆದದ್ದು'), ink.undo) : null;
    if (c.paused) return HelpInfo(next: const L10n('The lesson is paused. Tap anywhere on it to carry on.', 'ಪಾಠ ನಿಂತಿದೆ. ಮುಂದುವರಿಸಲು ಅದರ ಮೇಲೆ ಎಲ್ಲಿಯಾದರೂ ಒತ್ತಿ.'), detail: where, undo: undo);
    if (_atEnd) return HelpInfo(next: const L10n('That was the last step. Tap Finish class to see your summary.', 'ಅದು ಕೊನೆಯ ಹಂತ. ಸಾರಾಂಶ ನೋಡಲು “ತರಗತಿ ಮುಗಿಸಿ” ಒತ್ತಿ.'), detail: where, target: _next, undo: undo);
    if (voiced && auto.mode == PlayMode.auto && auto.waiting) {
      return HelpInfo(next: const L10n('The class has a question. When they have answered, tap Next.', 'ತರಗತಿಗೆ ಪ್ರಶ್ನೆ ಇದೆ. ಉತ್ತರಿಸಿದ ಮೇಲೆ “ಮುಂದೆ” ಒತ್ತಿ.'), detail: where, target: _next, undo: undo);
    }
    if (c.pen) return HelpInfo(next: const L10n('Write on the lesson with your finger. Tap Write again to stop.', 'ಬೆರಳಿನಿಂದ ಪಾಠದ ಮೇಲೆ ಬರೆಯಿರಿ. ನಿಲ್ಲಿಸಲು ಮತ್ತೆ “ಬರೆಯಿರಿ” ಒತ್ತಿ.'), detail: where, target: _write, undo: undo);
    return HelpInfo(next: const L10n('Tap Next to show the next part of the lesson.', 'ಪಾಠದ ಮುಂದಿನ ಭಾಗ ತೋರಿಸಲು “ಮುಂದೆ” ಒತ್ತಿ.'), detail: where, target: _next, undo: undo);
  }

  /// The voice button: pauses the chapter's narration (or reads the step aloud when there is none).
  (IconData, String, VoidCallback?) _voice(Lang l) {
    if (voiced && auto.hasVoice) {
      final on = auto.mode == PlayMode.auto;
      return (on ? Icons.pause_rounded : Icons.play_arrow_rounded, on ? tr(l, 'Pause voice', 'ಧ್ವನಿ ನಿಲ್ಲಿಸಿ') : tr(l, 'Play voice', 'ಧ್ವನಿ ಆರಂಭಿಸಿ'), () {
        final m = on ? PlayMode.manual : PlayMode.auto;
        auto.setMode(m);
        s.config.setPlayMode(m.name);
      });
    }
    return (Icons.volume_up_rounded, tr(l, 'Read aloud', 'ಓದಿ ಹೇಳಿ'), c.canReadAloud && !c.speaking ? c.readAloud : null);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, auto, s.config]),
    builder: (context, _) {
      final l = s.config.lang;
      if (c.lang != l) c.setLang(l);
      final phone = usePhoneLayout(context);
      final line = (c.stepLine ?? c.current.narration)?.t(l) ?? '';
      final left = _minutesLeft;
      final (vIcon, vLabel, vTap) = _voice(l);
      final stage = Stack(children: [
        Positioned.fill(child: BlockView(c: c, embeds: s.embeds, room: room, onFinished: () => teacherQuizDone(context, c))),
        if (c.pen) Positioned.fill(child: InkCanvas(controller: ink, transparent: true)),
        if (c.paused)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('resume'),
              onTap: () => c.setPaused(false),
              child: Container(
                decoration: BoxDecoration(color: _stageA.withValues(alpha: .82), borderRadius: BorderRadius.circular(40)),
                alignment: Alignment.center,
                child: Text(tr(l, 'Paused · tap to carry on', 'ನಿಂತಿದೆ · ಮುಂದುವರಿಸಲು ಒತ್ತಿ'), style: hd(phone ? 60 : 110, c: Colors.white, l: l)),
              ),
            ),
          ),
      ]);
      final next = KeyedSubtree(
        key: _next,
        child: ZxButton(
          _atEnd ? (widget.preview ? tr(l, 'Close', 'ಮುಚ್ಚಿ') : tr(l, 'Finish class', 'ತರಗತಿ ಮುಗಿಸಿ')) : tr(l, 'Next', 'ಮುಂದೆ'),
          key: const ValueKey('next'),
          trailing: _atEnd ? Icons.flag_rounded : Icons.arrow_forward_rounded,
          bg: S.violet,
          height: phone ? 130 : 190,
          size: phone ? 42 : 68,
          shadow: true,
          onTap: _atEnd ? _finishClass : c.next,
        ),
      );
      final back = ZxButton(
        tr(l, 'Back', 'ಹಿಂದೆ'),
        key: const ValueKey('back'),
        icon: Icons.arrow_back_rounded,
        bg: const Color(0x26FFFFFF),
        height: phone ? 130 : 190,
        size: phone ? 42 : 60,
        onTap: c.isFirst ? null : (voiced && auto.mode == PlayMode.auto ? auto.back : c.back),
      );
      Widget tool(Key key, GlobalKey? gk, String label, IconData icon, VoidCallback? onTap, {bool on = false}) {
        final w = Press(
          key: key,
          radius: 36,
          onTap: onTap,
          child: ToolButton(label, icon, width: phone ? 150 : 250, height: phone ? 130 : 190, bg: on ? Colors.white : const Color(0x1FFFFFFF), fg: on ? S.violet : Colors.white),
        );
        return gk == null ? w : KeyedSubtree(key: gk, child: w);
      }

      final tools = [
        tool(const ValueKey('write'), _write, tr(l, 'Write', 'ಬರೆಯಿರಿ'), Icons.edit_rounded, c.togglePen, on: c.pen),
        tool(const ValueKey('voice'), _voiceKey, vLabel, vIcon, vTap),
        tool(const ValueKey('lessonHelp'), null, tr(l, 'Help', 'ಸಹಾಯ'), Icons.question_mark_rounded, () => openHelp(context, _help())),
      ];
      final finishTag = KeyedSubtree(
        key: _finishKey,
        child: widget.preview ? const SizedBox.shrink() : Press(key: const ValueKey('finishClass'), onTap: _finishClass, child: Tag(tr(l, 'Finish class', 'ತರಗತಿ ಮುಗಿಸಿ'), icon: Icons.flag_rounded, bg: const Color(0x26FFFFFF), fg: Colors.white, size: phone ? 24 : 30)),
      );
      final close = Press(
        key: const ValueKey('closeLesson'),
        onTap: () => Navigator.of(context).maybePop(),
        child: Tag(tr(l, 'Home', 'ಮುಖಪುಟ'), icon: Icons.home_rounded, bg: const Color(0x26FFFFFF), fg: Colors.white, size: phone ? 24 : 30),
      );
      final title = '${classLine(s, widget.pack.chapter.subject, l, period: widget.period)} · ${widget.pack.chapter.title.t(l)}';

      if (phone) {
        return Scaffold(
          body: Container(
            decoration: stageGradient,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [Expanded(child: StepProgress(step: c.index + 1, of: c.blocks.length, width: 300, size: 26, lang: l)), close, const SizedBox(width: 12), finishTag]),
                  const SizedBox(height: 20),
                  Expanded(child: stage),
                  const SizedBox(height: 20),
                  Row(children: [for (final (i, t) in tools.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: t)]]),
                  const SizedBox(height: 16),
                  Row(children: [Expanded(child: back), const SizedBox(width: 16), Expanded(flex: 2, child: next)]),
                ]),
              ),
            ),
          ),
        );
      }
      return Scaffold(
        body: Container(
          decoration: stageGradient,
          child: DesignCanvas(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_pad, 56, _pad, 56),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Brand(size: 64, dark: true),
                  const SizedBox(width: 40),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(36, c: const Color(0xFFC9CBE6), w: FontWeight.w600))),
                  const SizedBox(width: 40),
                  StepProgress(step: c.index + 1, of: c.blocks.length, width: 640, size: 36, lang: l),
                  const SizedBox(width: 56),
                  if (left != null) ...[Tag(tr(l, '$left min left', 'ಇನ್ನೂ $left ನಿಮಿಷ'), icon: Icons.schedule_rounded, bg: const Color(0x26FFFFFF), fg: Colors.white, size: 30), const SizedBox(width: 18)],
                  finishTag,
                  const SizedBox(width: 18),
                  close,
                ]),
                const SizedBox(height: 40),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: stage)),
                if (line.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 18, 40, 18),
                    decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(999)),
                    child: Row(children: [
                      Icon(auto.speaking || c.speaking ? Icons.volume_up_rounded : Icons.subtitles_rounded, size: 46, color: _sun),
                      const SizedBox(width: 22),
                      Expanded(child: Text('“$line”', key: const ValueKey('caption'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(36, c: const Color(0xFFE6E8FF), w: FontWeight.w500))),
                    ]),
                  ),
                ],
                const SizedBox(height: 40),
                Row(children: [
                  SizedBox(width: 640, child: back),
                  const Spacer(),
                  for (final (i, t) in tools.indexed) ...[if (i > 0) const SizedBox(width: 24), t],
                  const Spacer(),
                  SizedBox(width: 860, child: next),
                ]),
              ]),
            ),
          ),
        ),
      );
    },
  );
}

/// 10 · Finish class: well done, three big ticks (lesson, homework, attendance) and Done. The
/// class is already saved in the history; homework and attendance can be changed (and undone).
class FinishClassScreen extends StatelessWidget {
  const FinishClassScreen({super.key, required this.recordId, this.period, this.practice});
  final String recordId;
  final Period? period;

  /// A practice class: the same screen with a pretend record that is not saved.
  final ClassRecord? practice;

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final s = ServicesScope.of(context);
      final r = practice ?? school.history.where((h) => h.id == recordId).firstOrNull;
      if (r == null) return const Scaffold(backgroundColor: Colors.white);
      final phone = usePhoneLayout(context);
      final now = s.clock();
      final mins = now.hour * 60 + now.minute;
      final next = school.today(now).where((p) => p.startMin > mins && (school.current == null || p.teacherId == null || p.teacherId!.isEmpty || p.teacherId == school.current!.id)).firstOrNull;
      void save(ClassRecord nr, L10n what) {
        if (practice != null) return;
        final old = r;
        school.updateClass(nr);
        school.pushUndo(what, () => school.updateClass(old));
      }

      final covered = r.stepsSeen >= r.stepsTotal ? tr(l, 'all ${r.stepsTotal} steps', 'ಎಲ್ಲಾ ${r.stepsTotal} ಹಂತಗಳು') : tr(l, '${r.stepsSeen} of ${r.stepsTotal} steps', '${r.stepsTotal} ರಲ್ಲಿ ${r.stepsSeen} ಹಂತಗಳು');
      final absent = r.absent.isEmpty ? '' : tr(l, ' · absent: ${r.absent.join(', ')}', ' · ಗೈರು: ${r.absent.join(', ')}');
      final ticks = [
        _tick(l, S.mint, tr(l, 'Lesson covered', 'ಪಾಠ ಮುಗಿದಿದೆ'), '${r.chapter.t(l)} · ${r.topic.t(l)} · $covered', null, null, phone),
        _tick(l, S.peach, tr(l, 'Homework given', 'ಮನೆಗೆಲಸ ನೀಡಲಾಗಿದೆ'), r.homework.isEmpty ? tr(l, 'No homework', 'ಮನೆಗೆಲಸ ಇಲ್ಲ') : r.homework, tr(l, 'Change', 'ಬದಲಿಸಿ'), () async {
          final v = await editHomework(context, r.homework);
          if (v != null) save(r.copyWith(homework: v), const L10n('A change to the homework', 'ಮನೆಗೆಲಸದ ಬದಲಾವಣೆ'));
        }, phone, key: const ValueKey('changeHomework')),
        _tick(l, S.sky, tr(l, 'Attendance', 'ಹಾಜರಾತಿ'), tr(l, '${r.present} of ${r.rollCount} present', '${r.rollCount} ರಲ್ಲಿ ${r.present} ಹಾಜರು') + absent, tr(l, 'Change', 'ಬದಲಿಸಿ'), () async {
          final v = await editAttendance(context, r.rollCount, r.absent);
          if (v != null) save(r.copyWith(absent: v), const L10n('A change to the attendance', 'ಹಾಜರಾತಿಯ ಬದಲಾವಣೆ'));
        }, phone, key: const ValueKey('changeAttendance')),
      ];
      final done = ZxButton(tr(l, 'Done', 'ಮುಗಿಯಿತು'), key: const ValueKey('finishDone'), icon: Icons.check_rounded, height: phone ? 140 : 190, size: phone ? 44 : 64, shadow: true, onTap: () => Navigator.of(context).maybePop());
      final saved = SafeLine(practice != null ? tr(l, 'Practice only: nothing was saved.', 'ಅಭ್ಯಾಸ ಮಾತ್ರ: ಏನೂ ಉಳಿಸಿಲ್ಲ.') : tr(l, 'Saved on this board. It works without internet.', 'ಈ ಬೋರ್ಡ್‌ನಲ್ಲಿ ಉಳಿಸಲಾಗಿದೆ. ಇಂಟರ್ನೆಟ್ ಇಲ್ಲದೆಯೂ ಕೆಲಸ ಮಾಡುತ್ತದೆ.'), size: phone ? 28 : 34, c: S.muted);
      final help = HelpChip(info: () => const HelpInfo(next: L10n('Check the homework and attendance, then tap Done.', 'ಮನೆಗೆಲಸ ಮತ್ತು ಹಾಜರಾತಿ ನೋಡಿ, ನಂತರ “ಮುಗಿಯಿತು” ಒತ್ತಿ.'), detail: L10n('Change attendance by tapping the roll numbers who are absent.', 'ಗೈರಾದ ರೋಲ್ ನಂಬರ್‌ಗಳನ್ನು ಒತ್ತಿ ಹಾಜರಾತಿ ಬದಲಿಸಿ.')));
      final nextLine = next == null ? '' : tr(l, 'Next: ${classLine(s, next.subject, l, period: next)} at ${Period.clock(next.start)}', 'ಮುಂದೆ: ${Period.clock(next.start)}ಕ್ಕೆ ${classLine(s, next.subject, l, period: next)}');
      final head = [
        Container(
          width: phone ? 140 : 220, height: phone ? 140 : 220,
          decoration: const BoxDecoration(color: S.green, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x551F7A4D), blurRadius: 60, offset: Offset(0, 24))]),
          child: Icon(Icons.check_rounded, size: phone ? 96 : 150, color: Colors.white),
        ),
        SizedBox(height: phone ? 36 : 60),
        Text(tr(l, 'Well done!', 'ಬಹಳ ಚೆನ್ನಾಗಿದೆ!'), style: tx(phone ? 40 : 54, c: S.eyebrow, w: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(tr(l, 'Class finished.', 'ತರಗತಿ ಮುಗಿಯಿತು.'), style: hd(phone ? 96 : 160, l: l)),
        const SizedBox(height: 24),
        Text('${classLine(s, r.subject, l, period: period)} · ${tr(l, '${r.minutes} minutes', '${r.minutes} ನಿಮಿಷ')}', style: tx(phone ? 34 : 48)),
      ];
      if (phone) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(40), children: [
              Align(alignment: Alignment.centerRight, child: help),
              ...head,
              const SizedBox(height: 40),
              for (final t in ticks) ...[t, const SizedBox(height: 24)],
              saved,
              const SizedBox(height: 40),
              done,
              if (nextLine.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 24), child: Text(nextLine, style: tx(30, c: S.muted))),
            ]),
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.white,
        body: DesignCanvas(
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _Confetti())),
            Padding(
              padding: const EdgeInsets.fromLTRB(_pad + 40, 80, _pad, 80),
              child: Row(children: [
                Expanded(
                  flex: 10,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    ...head,
                    const SizedBox(height: 70),
                    SizedBox(width: 760, child: done),
                    const SizedBox(height: 36),
                    Text(nextLine, style: tx(38, c: S.muted)),
                  ]),
                ),
                const SizedBox(width: 80),
                Expanded(
                  flex: 11,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (final t in ticks) ...[t, const SizedBox(height: 36)],
                    const SizedBox(height: 8),
                    saved,
                  ]),
                ),
              ]),
            ),
            Positioned(top: 40, right: 60, child: help),
          ]),
        ),
      );
    },
  );

  Widget _tick(Lang l, Color bg, String t, String sub, String? edit, VoidCallback? onEdit, bool phone, {Key? key}) => Container(
    padding: EdgeInsets.fromLTRB(phone ? 32 : 48, phone ? 30 : 44, phone ? 28 : 40, phone ? 30 : 44),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(56)),
    child: Row(children: [
      Tick(done: true, size: phone ? 80 : 120),
      SizedBox(width: phone ? 24 : 40),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: hd(phone ? 44 : 64, l: l)),
          const SizedBox(height: 8),
          Text(sub, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx(phone ? 28 : 36, c: S.cardText)),
        ]),
      ),
      if (edit != null) ...[const SizedBox(width: 24), ZxButton(edit, key: key, icon: Icons.edit_rounded, bg: Colors.white, fg: S.ink, height: phone ? 96 : 116, size: phone ? 28 : 34, onTap: onEdit)],
    ]),
  );
}

/// Asks for the homework (plain words).
Future<String?> editHomework(BuildContext context, String current) {
  final l = ServicesScope.of(context).config.lang;
  final t = TextEditingController(text: current);
  return showZxDialog<String>(
    context,
    title: tr(l, 'Homework', 'ಮನೆಗೆಲಸ'),
    body: (ctx) => ZxField(fieldKey: const ValueKey('homeworkField'), controller: t, label: tr(l, 'What the class should do at home', 'ಮನೆಯಲ್ಲಿ ತರಗತಿ ಮಾಡಬೇಕಾದದ್ದು'), lines: 3, autofocus: true),
    actions: (ctx) => [
      ZxButton(tr(l, 'Cancel', 'ರದ್ದು'), bg: S.mist, fg: S.ink, onTap: () => Navigator.pop(ctx)),
      ZxButton(tr(l, 'Save', 'ಉಳಿಸಿ'), key: const ValueKey('homeworkSave'), icon: Icons.check_rounded, bg: S.violet, onTap: () => Navigator.pop(ctx, t.text.trim())),
    ],
  );
}

/// Tap the roll numbers who are absent; everyone else is present.
Future<List<int>?> editAttendance(BuildContext context, int rollCount, List<int> absent) {
  final l = ServicesScope.of(context).config.lang;
  final set = {...absent};
  return showZxDialog<List<int>>(
    context,
    width: 2200,
    title: tr(l, 'Tap who is absent', 'ಗೈರಾದವರನ್ನು ಒತ್ತಿ'),
    body: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr(l, '${rollCount - set.length} of $rollCount present · roll numbers only', '$rollCount ರಲ್ಲಿ ${rollCount - set.length} ಹಾಜರು · ರೋಲ್ ನಂಬರ್ ಮಾತ್ರ'), style: tx(36, c: S.muted)),
        const SizedBox(height: 28),
        Wrap(spacing: 16, runSpacing: 16, children: [
          for (var r = 1; r <= rollCount; r++)
            Press(
              key: ValueKey('absent-$r'),
              radius: 28,
              onTap: () => setState(() => set.contains(r) ? set.remove(r) : set.add(r)),
              child: Container(
                width: 150, height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: set.contains(r) ? S.peach : S.mist, borderRadius: BorderRadius.circular(28), border: Border.all(color: set.contains(r) ? S.rust : Colors.transparent, width: 4)),
                child: Text('$r', style: hd(56, c: set.contains(r) ? S.rust : S.ink)),
              ),
            ),
        ]),
      ]),
    ),
    actions: (ctx) => [
      ZxButton(tr(l, 'Cancel', 'ರದ್ದು'), bg: S.mist, fg: S.ink, onTap: () => Navigator.pop(ctx)),
      ZxButton(tr(l, 'Save', 'ಉಳಿಸಿ'), key: const ValueKey('attendanceSave'), icon: Icons.check_rounded, bg: S.violet, onTap: () => Navigator.pop(ctx, set.toList()..sort())),
    ],
  );
}

class _Confetti extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final rnd = math.Random(7);
    const cols = [S.lavender, S.peach, S.mint, S.sky, S.butter, S.pink];
    for (var i = 0; i < 46; i++) {
      final x = rnd.nextDouble() * s.width, t = rnd.nextDouble();
      final y = t < .5 ? t * s.height * .28 : s.height * (.86 + (t - .5) * .28);
      canvas.drawCircle(Offset(x, y), 12 + rnd.nextDouble() * 26, Paint()..color = cols[i % cols.length]);
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => false;
}
