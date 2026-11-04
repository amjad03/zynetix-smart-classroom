import 'dart:async';

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/lesson_controller.dart';
import '../engine/model.dart';
import '../features/participation.dart';
import 'activity/activity_view.dart';
import 'challenge_view.dart';
import 'embeds.dart';
import 'interactive_view.dart';
import 'math_text.dart';
import 'whiteboard_view.dart';

/// Draws one lesson block. [auto] is Self-Learning: example steps reveal themselves and quizzes
/// run on a timer. [onFinished] is called by blocks that end on their own (quizzes).
class BlockView extends StatelessWidget {
  const BlockView({super.key, required this.c, required this.embeds, required this.room, this.auto = false, this.onFinished});
  final LessonController c;
  final Embeds embeds;
  final ClassRoom room;
  final bool auto;
  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context) {
    final b = c.current, l = c.lang;
    final text = Theme.of(context).textTheme;
    Widget heading(String s, {IconData? icon}) => Padding(
      padding: const EdgeInsets.only(bottom: Z.gap),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 56, color: Z.accent), const SizedBox(width: 16)],
          Expanded(child: Text(s, style: text.headlineLarge)),
        ],
      ),
    );
    List<Widget> bullets(List<L10n> items, {IconData icon = Icons.check_circle_outline}) => [
      for (final p in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: Z.accent),
              const SizedBox(width: 16),
              Expanded(child: MathText(p.t(l))),
            ],
          ),
        ),
    ];
    Widget withSide(Widget main, List<Widget> side) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: ClipRRect(borderRadius: BorderRadius.circular(Z.radius), child: main),
        ),
        const SizedBox(width: Z.gap),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: side),
          ),
        ),
      ],
    );

    final Widget body = switch (b.type) {
      BlockType.intro => _scrollCentered(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.lesson.title.t(l), style: text.headlineMedium?.copyWith(color: Z.accent)),
            const SizedBox(height: 12),
            Text(b.f('heading').t(l), style: text.displayLarge),
            const SizedBox(height: Z.gap),
            Text(b.f('hook').t(l), style: text.bodyLarge?.copyWith(fontSize: 40)),
            if (b.list('objectives').isNotEmpty) ...[const SizedBox(height: Z.gap), Text(tr('whatYouLearn', l), style: text.headlineMedium), ...bullets(b.list('objectives'))],
          ],
        ),
      ),
      BlockType.concept => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(b.title?.t(l) ?? '', icon: Icons.lightbulb_outline),
            MathText(b.f('body').t(l)),
            if (b.s('formula') != null) ...[const SizedBox(height: Z.gap), Center(child: Formula(b.s('formula')!))],
            const SizedBox(height: Z.gap),
            ...bullets(b.list('points')),
          ],
        ),
      ),
      BlockType.model3d => withSide(embeds.model3d(b, l), [Text(b.f('caption').t(l), style: text.bodyLarge)]),
      BlockType.simulation => withSide(embeds.simulation(b, c.pack, l), [
        Text(b.f('caption').t(l), style: text.bodyLarge),
        if (b.list('tryThis').isNotEmpty) ...[const SizedBox(height: Z.gap), Text(tr('tryThis', l), style: text.headlineMedium), ...bullets(b.list('tryThis'), icon: Icons.touch_app_outlined)],
      ]),
      BlockType.virtualLab => withSide(embeds.lab(b.s('labId')!, b.s('preset'), l), [
        Text(tr('aim', l), style: text.headlineMedium),
        const SizedBox(height: 8),
        Text(b.f('aim').t(l), style: text.bodyLarge),
      ]),
      BlockType.example => ExampleView(key: ValueKey(b.id), block: b, lang: l, auto: auto),
      BlockType.classQuiz => _quiz(b, b.ids('questionIds'), b.quizMode, false, l, text, Icons.groups_outlined, tr('classQuiz', l)),
      BlockType.pyq => _quiz(b, b.ids('questionIds'), QuizMode.monitor, true, l, text, Icons.emoji_events_outlined, tr('pyq', l)),
      BlockType.trick => _scrollCentered(
        Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Z.accent.withValues(alpha: 0.15),
            border: Border.all(color: Z.accent, width: 4),
            borderRadius: BorderRadius.circular(Z.radius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('${tr('trick', l)}: ${b.f('heading').t(l)}', icon: Icons.auto_awesome),
              MathText(b.f('body').t(l), style: text.bodyLarge?.copyWith(fontSize: 40)),
              if (b.maybe('mnemonic') != null) ...[const SizedBox(height: Z.gap), Text('“${b.maybe('mnemonic')!.t(l)}”', style: text.headlineMedium?.copyWith(fontStyle: FontStyle.italic))],
            ],
          ),
        ),
      ),
      BlockType.whiteboard => WhiteboardView(key: ValueKey('wb:${b.id}'), c: c, block: b, auto: auto),
      BlockType.interactive => InteractiveView(key: ValueKey('ia:${b.id}'), block: b, lang: l),
      BlockType.challenge => ChallengeView(key: ValueKey('ch:${b.id}'), block: b, lang: l, room: room, recorder: c.recorder, auto: auto, onFinished: onFinished),
      BlockType.activity => ActivityView(key: ValueKey('act:${b.id}'), block: b, lang: l, recorder: c.recorder),
      BlockType.recap => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(tr('recap', l), icon: Icons.replay),
            ...bullets(b.list('points')),
            if (b.list('homework').isNotEmpty || b.ids('homeworkQuestionIds').isNotEmpty) ...[
              const SizedBox(height: Z.gap),
              heading(tr('homework', l), icon: Icons.menu_book_outlined),
              ...bullets(b.list('homework'), icon: Icons.edit_note),
              for (final q in c.pack.questionsFor(b.ids('homeworkQuestionIds'))) ...bullets([q.stem], icon: Icons.edit_note),
            ],
          ],
        ),
      ),
    };
    return KeyedSubtree(key: ValueKey('block:${b.id}'), child: body);
  }

  /// Centred when it fits, scrollable when the screen is too short.
  static Widget _scrollCentered(Widget child) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    ),
  );

  Widget _quiz(Block b, List<String> ids, QuizMode mode, bool exams, Lang l, TextTheme text, IconData icon, String label) {
    final qs = c.pack.questionsFor(ids);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 52, color: Z.accent),
            const SizedBox(width: 12),
            Text(label, style: text.headlineLarge),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: QuizRunner(
            key: ValueKey('quiz:${b.id}'),
            questions: qs,
            mode: mode,
            lang: l,
            recorder: c.recorder,
            room: room,
            auto: auto,
            secondsPerQuestion: b.secondsPerQuestion,
            showExams: exams,
            onDone: onFinished,
          ),
        ),
      ],
    );
  }
}

/// A worked example: the problem, then one step at a time (tap, or by itself in Self-Learning).
class ExampleView extends StatefulWidget {
  const ExampleView({super.key, required this.block, required this.lang, this.auto = false, this.stepEvery = const Duration(seconds: 8)});
  final Block block;
  final Lang lang;
  final bool auto;
  final Duration stepEvery;
  @override
  State<ExampleView> createState() => _ExampleViewState();
}

class _ExampleViewState extends State<ExampleView> {
  int shown = 0;
  Timer? _t;

  List<L10n> get steps => widget.block.list('steps');
  bool get all => shown > steps.length; // steps, then the answer

  @override
  void initState() {
    super.initState();
    if (widget.auto) _t = Timer.periodic(widget.stepEvery, (_) => all ? _t?.cancel() : setState(() => shown++));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang, text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, size: 56, color: Z.accent),
              const SizedBox(width: 16),
              Text(tr('example', l), style: text.headlineLarge),
            ],
          ),
          const SizedBox(height: Z.gap),
          MathText(widget.block.f('problem').t(l), style: text.headlineMedium),
          const SizedBox(height: Z.gap),
          for (var i = 0; i < shown && i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 26, child: Text('${i + 1}', style: const TextStyle(fontSize: 28))),
                  const SizedBox(width: 16),
                  Expanded(child: MathText(steps[i].t(l))),
                ],
              ),
            ),
          if (all)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Z.correct, borderRadius: BorderRadius.circular(Z.radius)),
              child: Text(
                '${tr('answer', l)}: ${widget.block.f('answer').t(l)}',
                style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          else if (!widget.auto)
            BigButton(icon: Icons.expand_more, label: tr('showStep', l), onPressed: () => setState(() => shown++)),
        ],
      ),
    );
  }
}
