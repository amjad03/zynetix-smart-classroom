import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kinetix_ink/kinetix_ink.dart' show InkCanvas, InkController, InkStyle, InkTool;

import '../blocks/block_view.dart';
import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/auto_play.dart';
import '../engine/lesson_controller.dart';
import '../engine/model.dart';
import '../engine/session_log.dart';
import '../engine/sync.dart' show SyncError;
import 'insight/reteach.dart' show teacherQuizDone;
import 'participation.dart';
import 'smartboard.dart';

/// Teacher Mode lesson player: the block, and one row of big controls —
/// Back · Pause · Next · Pen · Quiz (plus Read aloud).
class LessonPlayerScreen extends StatefulWidget {
  const LessonPlayerScreen({super.key, required this.pack, required this.lesson});
  final InstalledPack pack;
  final Lesson lesson;
  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  late final Services s = ServicesScope.of(context);
  late final LessonController c = LessonController(
    pack: widget.pack,
    lesson: widget.pack.lessonFor(widget.lesson, s.config.board),
    narrator: s.narrator,
    lang: s.config.lang,
    recorder: SessionRecorder(outbox: s.outbox, sectionId: s.config.sectionId, mode: 'teacher', pack: widget.pack, lesson: widget.lesson, now: s.clock, mastery: s.mastery),
  );
  late final ClassRoom room = ClassRoom(rollCount: s.config.rollCount);

  /// Video-style narration: plays each step's clip and moves on (Auto), or waits for Next (Manual).
  /// With no voice downloaded the lesson starts in Manual and stays silent.
  late final bool voiced = c.lesson.blocks.any((b) => b.raw['voice'] is List);
  late final AutoPlayer auto = AutoPlayer(
    c: c,
    player: s.voicePlayer(),
    trackFor: (l) => s.voice?.track(widget.pack, c.lesson, l),
    mode: s.config.playMode == 'auto' && s.voice?.track(widget.pack, c.lesson, c.lang) != null ? PlayMode.auto : PlayMode.manual,
  );
  bool _downloading = false;

  Future<void> _downloadVoice() async {
    setState(() => _downloading = true);
    String? error;
    try {
      await s.sync.downloadVoice(widget.pack.id, c.lang);
    } on SyncError catch (e) {
      error = e.message;
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() => _downloading = false);
    if (s.voice?.track(widget.pack, c.lesson, c.lang) != null) {
      auto.reload();
      auto.setMode(PlayMode.auto);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? tr('voiceMissing', c.lang))));
    }
  }

  void _toggleMode() {
    final m = auto.mode == PlayMode.auto ? PlayMode.manual : PlayMode.auto;
    auto.setMode(m);
    s.config.setPlayMode(m.name);
  }
  final ink = InkController(
    style: const InkStyle(tool: InkTool.pen, color: Z.vermillion, width: 6),
  );
  bool _done = false;

  bool _listening = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listening) {
      _listening = true;
      c.addListener(_onChange);
      if (voiced) auto.start();
    }
  }

  int _lastIndex = 0;
  void _onChange() {
    if (c.index != _lastIndex) {
      ink.clear();
      _lastIndex = c.index;
    }
  }

  @override
  void dispose() {
    if (!_done) c.finish(completed: false);
    auto.dispose();
    auto.player.dispose();
    c.dispose();
    ink.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    _done = true;
    c.finish(completed: true);
    await s.config.markTaught(widget.lesson.topicId);
    if (mounted) Navigator.pop(context);
  }

  // The Smartboard pauses the lesson; closing it comes back to the same block, as it was.
  bool _pausedBeforeBoard = false;
  void _boardOpened() {
    _pausedBeforeBoard = c.paused;
    c.setPaused(true);
  }

  void _boardClosed() {
    if (mounted && !_pausedBeforeBoard) c.setPaused(false);
  }

  /// Quiz button: three questions on this topic, any time, answered by the class.
  void _quickQuiz() {
    final qs = widget.pack.topicQuestions(widget.lesson.topicId)..shuffle(Random());
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Z.page,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(ctx.narrow ? 20 : 32),
            child: Column(
              children: [
                ZTopBar(
                  title: widget.lesson.title.t(c.lang),
                  crumbs: [tr('quickQuiz', c.lang)],
                  trailing: [ZIconSquare(icon: Icons.close, tooltip: tr('close', c.lang), onPressed: () => Navigator.pop(ctx))],
                ),
                SizedBox(height: ctx.narrow ? 20 : 32),
                Expanded(
                  child: QuizRunner(questions: qs.take(3).toList(), mode: QuizMode.monitor, lang: c.lang, recorder: c.recorder, room: room, onDone: () => Navigator.pop(ctx)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([c, auto]),
      builder: (context, _) {
        final l = c.lang, text = Theme.of(context).textTheme;
        final narrow = context.narrow, pad = narrow ? 20.0 : 32.0;
        // A phone held upright: the top bar keeps only the lesson and Close (Smartboard and the
        // language are on Home), as in the approved phone layout.
        final phone = narrow && context.portrait && MediaQuery.sizeOf(context).width < 1000;
        final chapter = widget.pack.chapter;
        final step = trf('stepOf', l, {'n': c.index + 1, 'm': c.blocks.length});
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                children: [
                  // Top: where this is, the lesson, the step, Smartboard, language, close.
                  ZTopBar(
                    crumbs: [
                      subjectName(chapter.subject, l),
                      if (!narrow) yearLabel(chapter.id.startsWith('puc2') ? 'puc2' : 'puc1', s.config.board, l),
                      if (!phone) chapter.title.t(l) else trf('stepOf', l, {'n': c.index + 1, 'm': c.blocks.length}),
                    ],
                    title: widget.lesson.title.t(l),
                    trailing: [
                      if (phone)
                        const SizedBox.shrink()
                      else if (!narrow) ...[
                        Text(step, key: const ValueKey('stepOf'), style: zText(28, FontWeight.w400).copyWith(color: Z.muted)),
                        ZProgress(value: c.progress, width: 280),
                      ] else
                        Text('${c.index + 1}/${c.blocks.length}', key: const ValueKey('stepOf'), style: zText(28, FontWeight.w500).copyWith(color: Z.muted)),
                      // No voice for this chapter in this language yet: one small chip to fetch it.
                      if (voiced && !auto.hasVoice && s.voice != null)
                        ZSmallButton(
                          key: const ValueKey('downloadVoice'),
                          icon: _downloading ? Icons.downloading : Icons.download_outlined,
                          label: tr(_downloading ? 'voiceDownloading' : 'downloadVoice', l),
                          iconOnly: phone,
                          onPressed: _downloading ? null : _downloadVoice,
                        ),
                      if (!phone) SmartboardButton(onOpen: _boardOpened, onClose: _boardClosed),
                      if (!phone && s.config.kannadaOffered) ZSmallButton(key: const ValueKey('lang'), label: l == Lang.en ? 'ಕನ್ನಡ' : 'English', onPressed: () => c.setLang(l == Lang.en ? Lang.kn : Lang.en)),
                      ZIconSquare(key: const ValueKey('close'), icon: Icons.close, tooltip: tr('closeLesson', l), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  SizedBox(height: pad),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: BlockView(c: c, embeds: s.embeds, room: room, onFinished: () => teacherQuizDone(context, c)),
                        ),
                        if (c.pen) ...[Positioned.fill(child: InkCanvas(controller: ink, transparent: true)), Positioned(right: 24, top: 24, child: _PenPalette(ink: ink))],
                        // Auto stops on a step that asks the class something; Next (or an answer) carries on.
                        if (voiced && auto.mode == PlayMode.auto && auto.waiting && !c.paused)
                          Positioned(right: 24, bottom: 24, child: IgnorePointer(child: _Pill(key: const ValueKey('yourTurn'), icon: Icons.front_hand_outlined, text: tr('yourTurn', l)))),
                        if (c.paused)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () => c.setPaused(false),
                              child: Container(
                                decoration: BoxDecoration(color: Z.stage.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(Z.stageRadius)),
                                alignment: Alignment.center,
                                child: Text(tr('pause', l), style: text.displayLarge?.copyWith(color: Z.onStage)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: pad),
                  _Controls(c: c, auto: voiced ? auto : null, onQuiz: _quickQuiz, onFinish: _finish, onMode: _toggleMode),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The footer panel: Back, Pause, Pen, Read aloud, Quick quiz, and the primary Next (named for
/// the block it goes to).
class _Controls extends StatelessWidget {
  const _Controls({required this.c, required this.auto, required this.onQuiz, required this.onFinish, required this.onMode});
  final LessonController c;

  /// The narration player, when the lesson is narrated (Auto/Manual switch).
  final AutoPlayer? auto;
  final VoidCallback onQuiz, onFinish, onMode;

  @override
  Widget build(BuildContext context) {
    final l = c.lang, narrow = context.narrow;
    final phone = narrow && context.portrait && MediaQuery.sizeOf(context).width < 1000;
    final gap = SizedBox(width: narrow ? 12 : 20);
    final playing = auto?.mode == PlayMode.auto;
    Widget square(Key key, IconData icon, String label, VoidCallback? onPressed, {bool on = false}) => Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: Z.tap,
        child: on
            ? FilledButton(key: key, onPressed: onPressed, style: FilledButton.styleFrom(padding: EdgeInsets.zero), child: Icon(icon, size: 40, semanticLabel: label))
            : OutlinedButton(key: key, onPressed: onPressed, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero), child: Icon(icon, size: 40, semanticLabel: label)),
      ),
    );
    final next = c.isLast ? null : c.blocks[c.index + 1];
    // A block with its own primary action (Next question, Check, Lock in) keeps the only blue
    // button; the lesson's Next steps back to secondary.
    final own = const {BlockType.classQuiz, BlockType.pyq, BlockType.activity, BlockType.challenge}.contains(c.current.type) && c.current.style != 'pause' && c.current.style != 'solve';
    // While a block still has ideas to show, Next shows the next one (no block name yet).
    final more = !c.revealDone;
    return Container(
      padding: EdgeInsets.all(narrow ? 16 : 24),
      decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: Row(
        children: [
          BigButton(collapse: true, key: const ValueKey('back'), icon: Icons.arrow_back, label: tr('back', l), filled: false, onPressed: c.isFirst ? null : (playing ? auto!.back : c.back)),
          if (!phone) ...[
            gap,
            // Paused, it says so: a labelled Resume.
            if (c.paused)
              BigButton(collapse: true, key: const ValueKey('pause'), icon: Icons.play_arrow, label: tr('resume', l), onPressed: () => c.setPaused(false))
            else
              square(const ValueKey('pause'), Icons.pause, tr('pause', l), () => c.setPaused(true)),
          ],
          if (auto != null) ...[
            gap,
            // Auto (plays like a video) or Manual (tap Next); filled while Auto is on.
            square(const ValueKey('mode'), playing ? Icons.smart_display_outlined : Icons.touch_app_outlined, tr(playing ? 'autoPlay' : 'manualPlay', l), onMode, on: playing),
          ],
          gap,
          square(const ValueKey('pen'), Icons.edit_outlined, tr('pen', l), c.togglePen, on: c.pen),
          if (c.canReadAloud && !(auto?.hasVoice ?? false)) ...[
            gap,
            square(const ValueKey('read'), c.speaking ? Icons.volume_up : Icons.volume_up_outlined, tr('readAloud', l), c.speaking ? null : c.readAloud, on: c.speaking),
          ],
          if (!phone) ...[
            gap,
            BigButton(collapse: true, key: const ValueKey('quiz'), icon: Icons.quiz_outlined, label: tr('quickQuiz', l), filled: false, onPressed: onQuiz),
          ],
          gap,
          // Takes the space left, so its label shortens rather than overflowing on a phone.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: phone
                  ? SizedBox(
                      width: double.infinity,
                      child: c.isLast && !more
                          ? BigButton(key: const ValueKey('finish'), icon: Icons.done_all, label: tr('finish', l), trailingIcon: true, filled: !own, onPressed: onFinish)
                          : BigButton(key: const ValueKey('next'), icon: Icons.arrow_forward, label: tr('nextStep', l), trailingIcon: true, filled: !own, onPressed: c.next),
                    )
                  : c.isLast && !more
                  ? BigButton(key: const ValueKey('finish'), icon: Icons.done_all, label: tr('finish', l), trailingIcon: true, filled: !own, onPressed: onFinish)
                  : BigButton(
                      key: const ValueKey('next'),
                      icon: Icons.arrow_forward,
                      trailingIcon: true,
                      filled: !own,
                      label: narrow || next == null || more ? tr('next', l) : '${tr('next', l)}: ${blockLabel(next, l)}',
                      onPressed: c.next,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PenPalette extends StatelessWidget {
  const _PenPalette({required this.ink});
  final InkController ink;
  static const colors = [Z.yellow, Color(0xFFFFFFFF), Z.vermillion, Z.green, Z.sky, Z.ink];

  @override
  Widget build(BuildContext context) => ZPanel(
    padding: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final col in colors)
            Padding(
              padding: const EdgeInsets.all(6),
              child: InkWell(
                onTap: () => ink.style = ink.style.copyWith(tool: InkTool.pen, color: col),
                child: Container(width: 64, height: 64, decoration: BoxDecoration(color: col, shape: BoxShape.circle, border: Border.all(color: Z.line, width: 2))),
              ),
            ),
          IconButton(iconSize: 56, icon: const Icon(Icons.undo), onPressed: ink.undo),
          IconButton(iconSize: 56, icon: const Icon(Icons.delete_sweep_outlined), onPressed: ink.clear),
        ],
      ),
    ),
  );
}

/// A small dark label over the stage ("Your turn · Next continues").
class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
    decoration: BoxDecoration(color: Z.ink.withValues(alpha: 0.88), borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: Z.yellow),
        const SizedBox(width: 14),
        Text(text, style: zText(28, FontWeight.w500).copyWith(color: Colors.white)),
      ],
    ),
  );
}
