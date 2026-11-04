import 'dart:async';

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/lesson_controller.dart';
import '../engine/model.dart';
import '../features/insight/reteach.dart' show reteachNow;
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
    final narrow = context.narrow;
    final big = text.bodyLarge!.copyWith(fontSize: narrow ? 32 : 36, height: 1.55);
    Widget heading(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Text(s, style: zTitle(narrow ? 44 : 52)),
    );
    List<Widget> bullets(List<L10n> items, {IconData icon = Icons.check_circle_outline, TextStyle? style}) => [
      for (final p in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 6), child: Icon(icon, size: 40, color: Z.primary)),
              const SizedBox(width: 20),
              Expanded(child: MathText(p.t(l), style: style ?? big)),
            ],
          ),
        ),
    ];
    // A Kinetix embed on the dark stage, its caption and notes in the rail.
    Widget staged(Widget main, {required String? title, required String? hint, required List<Widget> rail}) => StageLayout(
      stage: ZStage(
        title: title,
        hint: hint,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: ClipRRect(borderRadius: BorderRadius.circular(Z.panelRadius), child: main),
      ),
      rail: rail,
    );
    String caption(String key) => b.f(key).t(l);

    final Widget body = switch (b.type) {
      BlockType.intro => ContentPanel(
        center: true,
        tag: blockName(b.type, l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.lesson.title.t(l), style: zText(30, FontWeight.w500).copyWith(color: Z.muted)),
            const SizedBox(height: 12),
            Text(b.f('heading').t(l), style: zTitle(narrow ? 52 : 68)),
            const SizedBox(height: 28),
            Text(b.f('hook').t(l), style: big.copyWith(fontSize: narrow ? 34 : 40)),
            if (b.list('objectives').isNotEmpty) ...[
              const SizedBox(height: 48),
              ZSectionTitle(tr('whatYouLearn', l), size: 34),
              const SizedBox(height: 24),
              ...bullets(b.list('objectives')),
            ],
          ],
        ),
      ),
      BlockType.concept => ContentPanel(
        tag: blockName(b.type, l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(b.title?.t(l) ?? ''),
            MathText(b.f('body').t(l), style: big),
            if (b.s('formula') != null) ...[const SizedBox(height: 36), Formula(b.s('formula')!)],
            const SizedBox(height: 36),
            ...bullets(b.list('points')),
          ],
        ),
      ),
      BlockType.model3d => staged(
        embeds.model3d(b, l),
        title: b.title?.t(l) ?? blockName(b.type, l),
        hint: tr('model3dHint', l),
        rail: [
          RailPanel(title: tr('about', l), children: [RailNote(caption('caption'))]),
        ],
      ),
      // Kinetix labs and players draw their own title and controls: no heading over them.
      BlockType.simulation => staged(
        embeds.simulation(b, c.pack, l),
        title: b.s('source') == 'phet' ? (b.title?.t(l) ?? blockName(b.type, l)) : null,
        hint: b.s('source') == 'phet' ? tr('simHint', l) : null,
        rail: [
          RailPanel(title: tr('about', l), children: [RailNote(caption('caption'))]),
          if (b.list('tryThis').isNotEmpty) RailPanel(title: tr('tryThis', l), gap: 20, children: bullets(b.list('tryThis'), icon: Icons.touch_app_outlined, style: zText(28, FontWeight.w400).copyWith(color: Z.ink2, height: 1.5))),
        ],
      ),
      BlockType.virtualLab => staged(
        embeds.lab(b.s('labId')!, b.s('preset'), l),
        title: null,
        hint: null,
        rail: [
          RailPanel(title: tr('aim', l), children: [RailNote(caption('aim'))]),
        ],
      ),
      BlockType.example => ExampleView(key: ValueKey(b.id), block: b, lang: l, auto: auto),
      BlockType.classQuiz => _quiz(b, b.ids('questionIds'), b.quizMode, false, l, tr('classQuiz', l)),
      BlockType.pyq => _quiz(b, b.ids('questionIds'), QuizMode.monitor, true, l, tr('pyq', l)),
      BlockType.trick => ContentPanel(
        center: true,
        tag: tr('trick', l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(b.f('heading').t(l)),
            MathText(b.f('body').t(l), style: big.copyWith(fontSize: narrow ? 34 : 40)),
            if (b.maybe('mnemonic') != null) ...[
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
                decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
                child: Text('“${b.maybe('mnemonic')!.t(l)}”', style: zTitle(narrow ? 36 : 42, FontWeight.w500)),
              ),
            ],
          ],
        ),
      ),
      BlockType.whiteboard => WhiteboardView(key: ValueKey('wb:${b.id}'), c: c, block: b, auto: auto),
      BlockType.interactive => InteractiveView(key: ValueKey('ia:${b.id}'), block: b, lang: l),
      BlockType.challenge => ChallengeView(key: ValueKey('ch:${b.id}'), block: b, lang: l, room: room, recorder: c.recorder, auto: auto, onFinished: onFinished),
      BlockType.activity => ActivityView(key: ValueKey('act:${b.id}'), block: b, lang: l, recorder: c.recorder),
      BlockType.recap => ContentPanel(
        tag: tr('recap', l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...bullets(b.list('points')),
            if (b.list('homework').isNotEmpty || b.ids('homeworkQuestionIds').isNotEmpty) ...[
              const SizedBox(height: 36),
              ZSectionTitle(tr('homework', l), size: 36),
              const SizedBox(height: 24),
              ...bullets(b.list('homework'), icon: Icons.edit_note),
              for (final q in c.pack.questionsFor(b.ids('homeworkQuestionIds'))) ...bullets([q.stem], icon: Icons.edit_note),
            ],
          ],
        ),
      ),
    };
    return KeyedSubtree(key: ValueKey('block:${b.id}'), child: body);
  }

  Widget _quiz(Block b, List<String> ids, QuizMode mode, bool exams, Lang l, String label) => QuizRunner(
    key: ValueKey('quiz:${b.id}'),
    questions: c.pack.questionsFor(ids),
    mode: mode,
    lang: l,
    recorder: c.recorder,
    room: room,
    auto: auto,
    secondsPerQuestion: b.secondsPerQuestion,
    showExams: exams,
    label: label,
    onDone: onFinished,
    onReteach: auto ? null : (ctx) => reteachNow(ctx, c),
  );
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
    final l = widget.lang, narrow = context.narrow;
    final body = Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: narrow ? 32 : 36, height: 1.55);
    return ContentPanel(
      tag: blockName(BlockType.example, l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MathText(widget.block.f('problem').t(l), style: zTitle(narrow ? 38 : 44, FontWeight.w500).copyWith(height: 1.4)),
          const SizedBox(height: 40),
          for (var i = 0; i < shown && i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == shown - 1 && !all ? Z.primary : Z.segTrack, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: zText(28, FontWeight.w600).copyWith(color: i == shown - 1 && !all ? Colors.white : Z.ink2)),
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: MathText(steps[i].t(l), style: body))),
                ],
              ),
            ),
          if (all)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
              decoration: BoxDecoration(color: Z.correctBg, borderRadius: BorderRadius.circular(Z.radius)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('answer', l), style: zText(26, FontWeight.w500).copyWith(color: Z.correctLabel)),
                  const SizedBox(height: 4),
                  MathText(widget.block.f('answer').t(l), style: zText(narrow ? 36 : 44, FontWeight.w600).copyWith(color: Z.correct)),
                ],
              ),
            )
          else if (!widget.auto)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BigButton(icon: Icons.expand_more, label: tr('showStep', l), filled: false, onPressed: () => setState(() => shown++)),
            ),
        ],
      ),
    );
  }
}
