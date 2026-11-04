import 'dart:async';

import 'package:flutter/material.dart';

import '../../blocks/block_view.dart';
import '../../blocks/math_text.dart';
import '../../core/services.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../engine/lesson_controller.dart';
import '../../engine/model.dart';
import '../../engine/period.dart';
import '../../engine/session_log.dart';
import '../participation.dart';
import 'analysis.dart';
import 'strings.dart';

/// The outcome of the quiz block [c] is on, from the answers its recorder holds; null when the
/// current block is not a quiz.
QuizOutcome? quizOutcome(LessonController c) {
  final b = c.current;
  if (b.type != BlockType.classQuiz && b.type != BlockType.pyq) return null;
  final answers = (c.recorder.log['answers'] as List).cast<Map<String, dynamic>>();
  return QuizOutcome.from(answers, b.ids('questionIds'));
}

List<String> _shown(LessonController c) => (c.recorder.log['blocksShown'] as List).cast<String>();

/// Teacher Mode hook: a quiz block has finished. Under 60% right, shows the Re-teach card
/// (missed questions, Re-teach another way, Pair up); otherwise nothing changes.
Future<void> teacherQuizDone(BuildContext context, LessonController c) async {
  final o = quizOutcome(c);
  if (o == null || !o.needsReteach) return;
  final s = ServicesScope.of(context);
  final alt = reteachBlock(c.lesson, _shown(c));
  final again = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(ctx.narrow ? 24 : 40),
          child: ReteachCard(
            outcome: o,
            missed: c.pack.questionsFor(o.missed),
            pairs: pairUp(s.mastery, c.lesson.topicId, o),
            lang: c.lang,
            onReteach: alt == null ? null : () => Navigator.pop(ctx, true),
            onCarryOn: () => Navigator.pop(ctx, false),
          ),
        ),
      ),
    ),
  );
  if (again != true || alt == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReplayScreen(pack: c.pack, lesson: c.lesson, blocks: [alt], recorder: c.recorder, title: it('anotherWay', c.lang)),
    ),
  );
}

/// Re-teaches the topic now, another way (from a quiz's rail). Null when the lesson has no other
/// approach left to show.
Future<void> Function()? reteachNow(BuildContext context, LessonController c) {
  final alt = reteachBlock(c.lesson, _shown(c));
  if (alt == null) return null;
  return () => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReplayScreen(pack: c.pack, lesson: c.lesson, blocks: [alt], recorder: c.recorder, title: it('anotherWay', c.lang)),
    ),
  );
}

final _retaught = Expando<bool>('retaught');

/// Self-Learning hook: a quiz block has finished. Under 60% right, re-teaches once by itself
/// (another approach from the same lesson, for as long as the period can spare), then lets the
/// period carry on. Otherwise it just tells the runner the quiz is done.
void selfLearningQuizDone(BuildContext context, PeriodRunner runner) {
  final c = runner.c;
  final o = quizOutcome(c);
  final alt = reteachBlock(c.lesson, _shown(c));
  if (o == null || !o.needsReteach || alt == null || _retaught[runner] == true || runner.homework) {
    runner.onQuizFinished();
    return;
  }
  final remaining = runner.plan.steps.skip(runner.step + 1).fold(0, (a, st) => a + st.seconds);
  final secs = reteachSeconds(alt, secondsLeft: runner.secondsLeft, remainingPlanned: remaining);
  if (secs == 0) {
    runner.onQuizFinished();
    return;
  }
  _retaught[runner] = true;
  // Hold the quiz step while the re-teach plays; the period clock keeps running.
  runner.current.seconds = runner.elapsed + secs + 10;
  final s = ServicesScope.of(context);
  Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => ReplayScreen(
            pack: c.pack,
            lesson: c.lesson,
            blocks: [alt],
            recorder: c.recorder,
            auto: true,
            seconds: secs,
            title: it('anotherWay', c.lang),
            intro: ReteachCard(outcome: o, missed: c.pack.questionsFor(o.missed), pairs: pairUp(s.mastery, c.lesson.topicId, o), lang: c.lang),
          ),
        ),
      )
      .then((_) => runner.onQuizFinished());
}

/// What the class missed and what to do about it. With no callbacks (Self-Learning) it only
/// informs: the pairs are shown straight away.
class ReteachCard extends StatefulWidget {
  const ReteachCard({super.key, required this.outcome, required this.missed, required this.pairs, required this.lang, this.onReteach, this.onCarryOn});
  final QuizOutcome outcome;
  final List<Question> missed;
  final List<(int, int)> pairs;
  final Lang lang;
  final VoidCallback? onReteach, onCarryOn;

  @override
  State<ReteachCard> createState() => _ReteachCardState();
}

class _ReteachCardState extends State<ReteachCard> {
  late bool showPairs = widget.onCarryOn == null;

  @override
  Widget build(BuildContext context) {
    final l = widget.lang, text = Theme.of(context).textTheme, o = widget.outcome;
    final buttons = widget.onCarryOn == null
        ? const <Widget>[]
        : [
            BigButton(key: const ValueKey('reteach'), icon: Icons.replay_circle_filled_outlined, label: it('reteach', l), onPressed: widget.onReteach),
            BigButton(key: const ValueKey('pairUp'), icon: Icons.people_alt_outlined, label: it('pairUp', l), filled: false, onPressed: () => setState(() => showPairs = !showPairs)),
            BigButton(key: const ValueKey('carryOn'), icon: Icons.arrow_forward, label: it('carryOn', l), filled: false, onPressed: widget.onCarryOn),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology_alt_outlined, size: 64, color: Z.accent),
            const SizedBox(width: 16),
            Expanded(child: Text(it('reteachTitle', l), style: text.headlineLarge)),
            Text('${o.correct} / ${o.total} ${it('reteachScore', l)}', style: text.headlineMedium?.copyWith(color: Z.wrong)),
          ],
        ),
        const SizedBox(height: Z.gap),
        Expanded(
          child: ListView(
            children: [
              if (widget.missed.isNotEmpty) ...[
                Text(it('missed', l), style: text.headlineSmall),
                const SizedBox(height: 8),
                for (final (i, q) in widget.missed.take(4).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 24, backgroundColor: Z.wrongBg, child: Text('${i + 1}', style: zText(26, FontWeight.w600).copyWith(color: Z.wrongText))),
                        const SizedBox(width: 16),
                        Expanded(child: MathText(q.stem.t(l))),
                      ],
                    ),
                  ),
              ],
              if (showPairs) ...[
                const SizedBox(height: 12),
                Text(it('pairUp', l), style: text.headlineSmall),
                Text(widget.pairs.isEmpty ? it('noPairs', l) : it('pairsHint', l), style: text.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final (a, b) in widget.pairs)
                      Chip(
                        key: ValueKey('pair:$a'),
                        avatar: const Icon(Icons.people_alt_outlined),
                        label: Text('${it('roll', l)} $a ${it('with', l)} $b', style: zText(26)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: 16),
          context.portrait
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final b in buttons) Padding(padding: const EdgeInsets.only(top: 12), child: b)])
              : Row(children: [for (final (i, b) in buttons.indexed) ...[if (i > 0) const SizedBox(width: 20), Expanded(child: b)]]),
        ],
      ],
    );
  }
}

/// Plays a few blocks of a lesson on their own, then returns: a re-teach inside the player,
/// or a five-minute revision. With [recorder] it records into that session (the lesson's);
/// otherwise it opens and closes its own Teacher Mode session. With [auto] (Self-Learning) it
/// shows [intro] briefly, plays for [seconds] and closes itself; otherwise the teacher moves
/// with Back / Next and leaves with Done.
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({
    super.key,
    required this.pack,
    required this.lesson,
    required this.blocks,
    this.recorder,
    this.auto = false,
    this.seconds = 120,
    this.title,
    this.intro,
    this.doneLabel,
    this.onDone,
  });
  final InstalledPack pack;

  /// The lesson as taught on this board (already filtered for the curriculum).
  final Lesson lesson;
  final List<Block> blocks;
  final SessionRecorder? recorder;
  final bool auto;
  final int seconds;
  final String? title;
  final Widget? intro;
  final String? doneLabel;

  /// Called after Done (Teacher Mode), in place of just going back.
  final VoidCallback? onDone;

  static const introSeconds = 8;

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  late final Services s = ServicesScope.of(context);
  late final bool ownRecorder = widget.recorder == null;
  late final LessonController c = LessonController(
    pack: widget.pack,
    lesson: widget.lesson,
    blocks: widget.blocks,
    narrator: s.narrator,
    lang: s.config.lang,
    recorder: widget.recorder ?? SessionRecorder(outbox: s.outbox, sectionId: s.config.sectionId, mode: 'teacher', pack: widget.pack, lesson: widget.lesson, now: s.clock, mastery: s.mastery),
  );
  late final ClassRoom room = ClassRoom(rollCount: s.config.rollCount);
  Timer? _timer;
  int elapsed = 0;
  bool _started = false;

  bool get showingIntro => widget.auto && widget.intro != null && elapsed < ReplayScreen.introSeconds;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    c.addListener(_changed);
    if (widget.auto) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      if (widget.intro == null) _speak();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _speak() {
    final n = c.current.narration;
    if (n != null) c.speak(n);
  }

  void _tick() {
    if (!mounted) return;
    setState(() => elapsed++);
    if (widget.intro != null && elapsed == ReplayScreen.introSeconds) _speak();
    final per = (widget.seconds - (widget.intro == null ? 0 : ReplayScreen.introSeconds)) ~/ widget.blocks.length;
    final at = elapsed - (widget.intro == null ? 0 : ReplayScreen.introSeconds);
    if (at > 0 && per > 0 && at % per == 0 && !c.isLast) {
      c.next();
      _speak();
    }
    if (elapsed >= widget.seconds) _close();
  }

  bool _closed = false;
  void _close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    c.stopSpeech();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    c.removeListener(_changed);
    c.stopSpeech();
    if (ownRecorder) c.finish(completed: true);
    c.dispose();
    super.dispose();
  }

  void _done() {
    _closed = true;
    c.stopSpeech();
    final then = widget.onDone;
    if (then != null) {
      then();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = c.lang, text = Theme.of(context).textTheme;
    final body = showingIntro
        ? widget.intro!
        : BlockView(c: c, embeds: s.embeds, room: room, auto: widget.auto);
    return PopScope(
      canPop: !widget.auto,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.replay_circle_filled_outlined, size: 52, color: Z.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(widget.title ?? widget.lesson.title.t(l), style: text.headlineMedium, overflow: TextOverflow.ellipsis, maxLines: 1),
                    ),
                    if (widget.auto)
                      Text('${(widget.seconds - elapsed).clamp(0, 9999) ~/ 60}:${((widget.seconds - elapsed).clamp(0, 9999) % 60).toString().padLeft(2, '0')}', style: text.headlineMedium)
                    else
                      IconButton(key: const ValueKey('replayClose'), iconSize: 64, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              if (widget.auto) LinearProgressIndicator(value: (elapsed / widget.seconds).clamp(0, 1), minHeight: 8),
              Expanded(
                child: Padding(padding: EdgeInsets.all(context.narrow ? 20 : 40), child: body),
              ),
              if (!widget.auto)
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  padding: EdgeInsets.symmetric(horizontal: context.narrow ? 16 : 32, vertical: 16),
                  child: Row(
                    children: [
                      if (widget.blocks.length > 1) ...[
                        BigButton(collapse: true, icon: Icons.arrow_back, label: tr('back', l), filled: false, onPressed: c.isFirst ? null : c.back),
                        const SizedBox(width: 16),
                        BigButton(collapse: true, icon: Icons.arrow_forward, label: tr('next', l), filled: false, onPressed: c.isLast ? null : c.next),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: BigButton(key: const ValueKey('replayDone'), icon: Icons.done, label: widget.doneLabel ?? it('backToLesson', l), onPressed: _done),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
