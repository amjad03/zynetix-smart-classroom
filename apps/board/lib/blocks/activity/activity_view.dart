import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/model.dart';
import '../../engine/session_log.dart';
import '../math_text.dart';
import '../scene/strings.dart';
import 'activity_kinds.dart';
import 'activity_logic.dart';

/// A touch activity (schema `activity`): sort, order, match, label, hotspot or fill. Drag or
/// tap to place; Check marks each item right or wrong; Show answer puts everything right;
/// Start again reshuffles. With a `questionId` and a [recorder], the class's first Check is
/// recorded as one answer (source "activity", whole class, no roll number).
class ActivityView extends StatefulWidget {
  const ActivityView({super.key, required this.block, required this.lang, this.recorder, this.onFinished});
  final Block block;
  final Lang lang;
  final SessionRecorder? recorder;

  /// Called when the activity is checked all right, or its answer shown.
  final VoidCallback? onFinished;

  @override
  State<ActivityView> createState() => ActivityViewState();
}

class ActivityViewState extends State<ActivityView> {
  late final ActivityLogic logic = ActivityLogic.of(widget.block);
  bool revealed = false, recorded = false;
  int? right;
  String? message;

  void update(VoidCallback f) => setState(() {
    f();
    right = null;
    message = null;
  });

  void check() {
    final l = widget.lang;
    if (!logic.complete) {
      setState(() => message = st('notDone', l));
      return;
    }
    setState(() {
      right = logic.check();
      message = logic.allRight ? st('allRight', l) : '$right ${st('of', l)} ${logic.total} ${st('someWrong', l)}';
    });
    final qid = widget.block.s('questionId');
    if (!recorded && qid != null && widget.recorder != null) {
      recorded = true;
      widget.recorder!.answer(questionId: qid, mode: QuizMode.monitor, chosen: null, correct: logic.allRight, source: 'activity');
    }
    if (logic.allRight) widget.onFinished?.call();
  }

  void showAnswer() {
    setState(() {
      logic.reveal();
      revealed = true;
      right = logic.total;
      message = st('answerShown', widget.lang);
    });
    widget.onFinished?.call();
  }

  void reset() => setState(() {
    logic.reset();
    revealed = false;
    right = null;
    message = null;
  });

  String get _hint => switch (widget.block.raw['kind']) {
    'order' => 'tapToOrder',
    'match' => 'tapToMatch',
    'hotspot' => 'tapSpots',
    'fill' => 'tapBlank',
    _ => 'tapThenPlace',
  };

  @override
  Widget build(BuildContext context) {
    final l = widget.lang, text = Theme.of(context).textTheme;
    final b = widget.block;
    final body = switch (logic) {
      final SortLogic s => SortBoard(logic: s, lang: l, onChange: update),
      final OrderLogic o => OrderBoard(logic: o, lang: l, onChange: update),
      final MatchLogic m => MatchBoard(logic: m, lang: l, onChange: update),
      final LabelLogic lb => DiagramBoard.label(block: b, logic: lb, lang: l, onChange: update),
      final HotspotLogic h => DiagramBoard.hotspot(block: b, logic: h, lang: l, onChange: update, showLabels: logic.marks.isNotEmpty || revealed),
      final FillLogic f => FillBoard(block: b, logic: f, lang: l, onChange: update),
      _ => const SizedBox.shrink(),
    };
    final ok = logic.marks.isNotEmpty && logic.allRight;
    final explanation = b.maybe('explanation');
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.22),
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.extension_outlined, size: 52, color: Z.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MathText(b.f('prompt').t(l), style: text.headlineMedium),
                        Text(st(_hint, l), style: text.bodyMedium?.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: body),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: math.max(box.maxHeight * 0.3, Z.tap + 8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message != null) Text(message!, key: const ValueKey('activityResult'), style: text.headlineMedium?.copyWith(color: ok || revealed ? Z.correct : Z.accent)),
                        if (explanation != null && (ok || revealed)) MathText('${st('why', l)}: ${explanation.t(l)}', style: text.bodyLarge),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                BigButton(key: const ValueKey('activityReset'), collapse: true, icon: Icons.replay, label: st('resetActivity', l), filled: false, onPressed: reset),
                const SizedBox(width: 12),
                BigButton(key: const ValueKey('activityShow'), collapse: true, icon: Icons.visibility_outlined, label: st('showAnswer', l), filled: false, onPressed: showAnswer),
                const SizedBox(width: 12),
                BigButton(key: const ValueKey('activityCheck'), icon: Icons.check, label: st('check', l), color: Z.correct, onPressed: check),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
