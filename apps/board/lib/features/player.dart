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
    recorder: SessionRecorder(outbox: s.outbox, sectionId: s.config.sectionId, mode: 'teacher', pack: widget.pack, lesson: widget.lesson, now: s.clock),
  );
  late final ClassRoom room = ClassRoom(rollCount: s.config.rollCount);
  final ink = InkController(
    style: const InkStyle(tool: InkTool.pen, color: Color(0xFFFFEB3B), width: 6),
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
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Row(
                children: [
                  Text(tr('quiz', c.lang), style: Theme.of(ctx).textTheme.headlineLarge),
                  const Spacer(),
                  IconButton(iconSize: 64, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              Expanded(
                child: QuizRunner(questions: qs.take(3).toList(), mode: QuizMode.monitor, lang: c.lang, recorder: c.recorder, room: room, onDone: () => Navigator.pop(ctx)),
              ),
            ],
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
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top: lesson, position, language, close.
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 16, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(widget.lesson.title.t(l), style: text.headlineMedium, overflow: TextOverflow.ellipsis, maxLines: 1),
                      ),
                      const SizedBox(width: 16),
                      Text('${c.index + 1} / ${c.blocks.length}', style: text.headlineMedium),
                      const SizedBox(width: 16),
                      SmartboardButton(onOpen: _boardOpened, onClose: _boardClosed),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () => c.setLang(l == Lang.en ? Lang.kn : Lang.en),
                        child: Text(l == Lang.en ? 'ಕನ್ನಡ' : 'EN', style: const TextStyle(fontSize: 32)),
                      ),
                      IconButton(key: const ValueKey('close'), iconSize: 64, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                LinearProgressIndicator(value: c.progress, minHeight: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.all(context.narrow ? 20 : 40),
                          child: BlockView(c: c, embeds: s.embeds, room: room),
                        ),
                      ),
                      if (c.pen) ...[Positioned.fill(child: InkCanvas(controller: ink, transparent: true)), Positioned(right: 24, top: 24, child: _PenPalette(ink: ink))],
                      if (c.paused)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => c.setPaused(false),
                            child: Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              child: Text(tr('pause', l), style: text.displayLarge?.copyWith(color: Colors.white)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _Controls(c: c, onQuiz: _quickQuiz, onFinish: _finish),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.c, required this.onQuiz, required this.onFinish});
  final LessonController c;
  final VoidCallback onQuiz, onFinish;

  @override
  Widget build(BuildContext context) {
    final l = c.lang;
    final gap = SizedBox(width: context.narrow ? 12 : 20);
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      padding: EdgeInsets.symmetric(horizontal: context.narrow ? 16 : 32, vertical: 16),
      child: Row(
        children: [
          BigButton(collapse: true, key: const ValueKey('back'), icon: Icons.arrow_back, label: tr('back', l), filled: false, onPressed: c.isFirst ? null : c.back),
          gap,
          BigButton(
            collapse: true,
            key: const ValueKey('pause'),
            icon: c.paused ? Icons.play_arrow : Icons.pause,
            label: tr(c.paused ? 'resume' : 'pause', l),
            filled: false,
            onPressed: () => c.setPaused(!c.paused),
          ),
          gap,
          BigButton(collapse: true, key: const ValueKey('pen'), icon: Icons.edit, label: tr('pen', l), filled: c.pen, onPressed: c.togglePen),
          gap,
          BigButton(collapse: true, key: const ValueKey('quiz'), icon: Icons.quiz_outlined, label: tr('quiz', l), filled: false, onPressed: onQuiz),
          gap,
          if (c.canReadAloud)
            BigButton(
              collapse: true,
              key: const ValueKey('read'),
              icon: c.speaking ? Icons.volume_up : Icons.record_voice_over_outlined,
              label: tr('readAloud', l),
              filled: false,
              onPressed: c.speaking ? null : c.readAloud,
            ),
          const Spacer(),
          c.isLast
              ? BigButton(key: const ValueKey('finish'), icon: Icons.done_all, label: tr('finish', l), color: Z.correct, onPressed: onFinish)
              : BigButton(key: const ValueKey('next'), icon: Icons.arrow_forward, label: tr('next', l), onPressed: c.next),
        ],
      ),
    );
  }
}

class _PenPalette extends StatelessWidget {
  const _PenPalette({required this.ink});
  final InkController ink;
  static const colors = [Color(0xFFFFEB3B), Color(0xFFFFFFFF), Color(0xFFFF5252), Color(0xFF69F0AE), Color(0xFF40C4FF)];

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final col in colors)
            Padding(
              padding: const EdgeInsets.all(6),
              child: InkWell(
                onTap: () => ink.style = ink.style.copyWith(tool: InkTool.pen, color: col),
                child: CircleAvatar(radius: 32, backgroundColor: col),
              ),
            ),
          IconButton(iconSize: 56, icon: const Icon(Icons.undo), onPressed: ink.undo),
          IconButton(iconSize: 56, icon: const Icon(Icons.delete_sweep_outlined), onPressed: ink.clear),
        ],
      ),
    ),
  );
}
