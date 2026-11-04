import 'dart:async';

import 'package:flutter/material.dart';

import '../blocks/block_view.dart';
import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/lesson_controller.dart';
import '../engine/model.dart';
import '../engine/period.dart';
import '../engine/session_log.dart';
import 'home.dart';
import 'participation.dart';
import 'pin.dart';
import 'smartboard.dart';

/// Self-Learning: start the next topic for this class (two taps from Home), or the topic the
/// college scheduled for this period.
class SelfLearningStartScreen extends StatelessWidget {
  const SelfLearningStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), l = s.config.lang, text = Theme.of(context).textTheme;
    final booked = s.config.scheduledNow(s.clock());
    final scheduled = booked == null ? null : s.lessonFor(booked.topicId);
    final next = scheduled ?? s.nextTopic();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Z.tap + 16,
        leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(tr('selfLearning', l), style: text.headlineLarge),
        // Before the period starts only: a running period has no way out but the PIN.
        actions: const [SmartboardButton(), SizedBox(width: 24)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(48),
        child: next == null
            ? Center(child: Text(tr('comingSoon', l), style: text.headlineMedium))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scheduled != null ? tr('scheduled', l) : tr('nextTopic', l), style: text.headlineMedium?.copyWith(color: Z.accent)),
                  const SizedBox(height: 16),
                  Text('${yearLabel(next.pack.chapter.year, s.config.board, l)} · ${subjectName(next.pack.chapter.subject, l)} · ${next.pack.chapter.title.t(l)}', style: text.bodyLarge),
                  Text(next.lesson.title.t(l), style: text.displayLarge),
                  const SizedBox(height: 32),
                  Text('${tr('nowPlaying', l)}: ${s.config.periodMinutes} min · ${tr('periodEnds', l)} …', style: text.bodyMedium),
                  const SizedBox(height: 32),
                  BigButton(
                    key: const ValueKey('startSelf'),
                    icon: Icons.play_arrow,
                    label: tr('start', l),
                    color: const Color(0xFF6A1B9A),
                    onPressed: () => startSelfLearning(context, next.pack, next.lesson, periodSeconds: booked?.secondsLeft(s.clock()) ?? s.config.periodMinutes * 60),
                  ),
                ],
              ),
      ),
    );
  }
}

void startSelfLearning(BuildContext context, InstalledPack pack, Lesson lesson, {required int periodSeconds}) => Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(
    builder: (_) => SelfLearningScreen(pack: pack, lesson: lesson, periodSeconds: periodSeconds),
  ),
  (r) => r.isFirst,
);

/// A whole period with no teacher. The back button does nothing; only the teacher PIN exits.
class SelfLearningScreen extends StatefulWidget {
  const SelfLearningScreen({super.key, required this.pack, required this.lesson, required this.periodSeconds, this.autoTick = true});
  final InstalledPack pack;
  final Lesson lesson;
  final int periodSeconds;
  final bool autoTick;
  @override
  State<SelfLearningScreen> createState() => SelfLearningScreenState();
}

class SelfLearningScreenState extends State<SelfLearningScreen> {
  late final Services s = ServicesScope.of(context);
  late final Lesson lesson = widget.pack.lessonFor(widget.lesson, s.config.board);
  late final PeriodPlan plan = PeriodPlanner.plan(lesson, periodMinutes: (widget.periodSeconds / 60).ceil());
  late final LessonController c = LessonController(
    pack: widget.pack,
    lesson: lesson,
    blocks: plan.blocks,
    narrator: s.narrator,
    lang: s.config.lang,
    recorder: SessionRecorder(outbox: s.outbox, sectionId: s.config.sectionId, mode: 'self_learning', pack: widget.pack, lesson: widget.lesson, now: s.clock, mastery: s.mastery),
  );
  late final ClassRoom room = ClassRoom(rollCount: s.config.rollCount);
  late final PeriodRunner runner = PeriodRunner(c: c, plan: plan, periodSeconds: widget.periodSeconds, autoTick: widget.autoTick);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (runner.step == 0 && runner.elapsed == 0 && runner.periodElapsed == 0) {
      scheduleMicrotask(runner.start);
    }
  }

  @override
  void dispose() {
    runner.dispose();
    c.dispose();
    super.dispose();
  }

  Future<void> _exit() async {
    if (!await askPin(context, s.config)) return;
    runner.stop();
    if (runner.homework) await s.config.markTaught(widget.lesson.topicId);
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: ListenableBuilder(
        listenable: runner,
        builder: (context, _) {
          final l = c.lang, text = Theme.of(context).textTheme;
          final left = runner.secondsLeft;
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.smart_display_outlined, size: 52, color: Color(0xFFCE93D8)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(widget.lesson.title.t(l), style: text.headlineMedium, overflow: TextOverflow.ellipsis),
                        ),
                        Text('${context.narrow ? '' : '${tr('periodEnds', l)} '}${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}', style: text.headlineMedium),
                        const SizedBox(width: 16),
                        IconButton(key: const ValueKey('lockExit'), iconSize: 56, icon: const Icon(Icons.lock_outline), onPressed: _exit),
                      ],
                    ),
                  ),
                  _PhaseStrip(phase: runner.phase, lang: l),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(context.narrow ? 20 : 40),
                      child: runner.homework
                          ? _Homework(c: c, over: runner.over)
                          : Stack(
                              children: [
                                Positioned.fill(
                                  child: BlockView(c: c, embeds: s.embeds, room: room, auto: true, onFinished: runner.onQuizFinished),
                                ),
                                if (runner.paused)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black54,
                                      alignment: Alignment.center,
                                      child: Text(tr('pause', l), style: text.displayLarge?.copyWith(color: Colors.white)),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  if (!runner.homework)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // The monitor may pause (a doubt, a noise outside); nothing else.
                          BigButton(
                            key: const ValueKey('slPause'),
                            icon: runner.paused ? Icons.play_arrow : Icons.pause,
                            label: tr(runner.paused ? 'resume' : 'pause', l),
                            filled: false,
                            onPressed: () => runner.setPaused(!runner.paused),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: LinearProgressIndicator(value: (runner.step + 1) / plan.steps.length, minHeight: 16, borderRadius: BorderRadius.circular(8)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhaseStrip extends StatelessWidget {
  const _PhaseStrip({required this.phase, required this.lang});
  final Phase phase;
  final Lang lang;
  static const _labels = {Phase.lesson: 'nowPlaying', Phase.examples: 'example', Phase.quiz: 'classQuiz', Phase.recap: 'recap', Phase.homework: 'homework'};

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Row(
      children: [
        for (final p in Phase.values)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: p == phase ? const Color(0xFF6A1B9A) : (p.index < phase.index ? Z.correct : Theme.of(context).colorScheme.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                p == Phase.lesson ? (lang == Lang.kn ? 'ಪಾಠ' : 'Lesson') : tr(_labels[p]!, lang),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: p == phase ? FontWeight.w700 : FontWeight.w500,
                  color: p.index <= phase.index ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Homework extends StatelessWidget {
  const _Homework({required this.c, required this.over});
  final LessonController c;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final l = c.lang, text = Theme.of(context).textTheme;
    final recap = c.lesson.blocks.where((b) => b.type == BlockType.recap).firstOrNull;
    final items = [...?recap?.list('homework'), for (final q in c.pack.questionsFor(recap?.ids('homeworkQuestionIds') ?? const [])) q.stem];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 64, color: Z.accent),
            const SizedBox(width: 16),
            Text(tr('homework', l), style: text.displayLarge),
          ],
        ),
        const SizedBox(height: 32),
        for (final (i, h) in items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text('${i + 1}.  ${h.t(l)}', style: text.headlineMedium),
          ),
        const Spacer(),
        if (over)
          Center(
            child: Text(tr('periodOver', l), style: text.headlineLarge?.copyWith(color: Z.correct)),
          ),
      ],
    );
  }
}
