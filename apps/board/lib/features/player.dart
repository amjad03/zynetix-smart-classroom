import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kinetix_ink/kinetix_ink.dart' show InkCanvas, InkController, InkStyle, InkTool;

import '../blocks/block_view.dart';
import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/lesson_controller.dart';
import '../engine/model.dart';
import '../engine/session_log.dart';
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
      listenable: c,
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
                      if (!phone) SmartboardButton(onOpen: _boardOpened, onClose: _boardClosed),
                      if (!phone) ZSmallButton(key: const ValueKey('lang'), label: l == Lang.en ? 'ಕನ್ನಡ' : 'English', onPressed: () => c.setLang(l == Lang.en ? Lang.kn : Lang.en)),
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
                  _Controls(c: c, onQuiz: _quickQuiz, onFinish: _finish),
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
  const _Controls({required this.c, required this.onQuiz, required this.onFinish});
  final LessonController c;
  final VoidCallback onQuiz, onFinish;

  @override
  Widget build(BuildContext context) {
    final l = c.lang, narrow = context.narrow;
    final phone = narrow && context.portrait && MediaQuery.sizeOf(context).width < 1000;
    final gap = SizedBox(width: narrow ? 12 : 20);
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
    final own = const {BlockType.classQuiz, BlockType.pyq, BlockType.activity, BlockType.challenge}.contains(c.current.type);
    return Container(
      padding: EdgeInsets.all(narrow ? 16 : 24),
      decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: Row(
        children: [
          BigButton(collapse: true, key: const ValueKey('back'), icon: Icons.arrow_back, label: tr('back', l), filled: false, onPressed: c.isFirst ? null : c.back),
          if (!phone) ...[
            gap,
            // Paused, it says so: a labelled Resume.
            if (c.paused)
              BigButton(collapse: true, key: const ValueKey('pause'), icon: Icons.play_arrow, label: tr('resume', l), onPressed: () => c.setPaused(false))
            else
              square(const ValueKey('pause'), Icons.pause, tr('pause', l), () => c.setPaused(true)),
          ],
          gap,
          square(const ValueKey('pen'), Icons.edit_outlined, tr('pen', l), c.togglePen, on: c.pen),
          if (c.canReadAloud) ...[
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
                      child: c.isLast
                          ? BigButton(key: const ValueKey('finish'), icon: Icons.done_all, label: tr('finish', l), trailingIcon: true, filled: !own, onPressed: onFinish)
                          : BigButton(key: const ValueKey('next'), icon: Icons.arrow_forward, label: tr('nextStep', l), trailingIcon: true, filled: !own, onPressed: c.next),
                    )
                  : c.isLast
                  ? BigButton(key: const ValueKey('finish'), icon: Icons.done_all, label: tr('finish', l), trailingIcon: true, filled: !own, onPressed: onFinish)
                  : BigButton(
                      key: const ValueKey('next'),
                      icon: Icons.arrow_forward,
                      trailingIcon: true,
                      filled: !own,
                      label: narrow || next == null ? tr('next', l) : '${tr('next', l)}: ${blockName(next.type, l)}',
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
