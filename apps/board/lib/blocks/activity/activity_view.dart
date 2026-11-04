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

  /// How many items are placed so far, for the progress bar (null when it means nothing).
  (int, int)? get _progress => switch (logic) {
    final SortLogic g => (g.placed.where((p) => p != null).length, g.total),
    final MatchLogic g => (g.link.where((p) => p != null).length, g.total),
    final LabelLogic g => (g.onTarget.where((p) => p != null).length, g.total),
    final FillLogic g => (g.chosen.where((p) => p != null).length, g.total),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l = widget.lang;
    final b = widget.block;
    final narrow = context.narrow, portrait = context.portrait;
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
    final progress = _progress;
    final kind = b.raw['kind'] as String? ?? 'sort';
    final progressW = progress == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!narrow) ...[ZProgress(value: progress.$2 == 0 ? 0 : progress.$1 / progress.$2, width: 320, height: 16, track: Z.segTrack), const SizedBox(width: 24)],
              Text('${progress.$1} ${st('of', l)} ${progress.$2} ${st('placed', l)}', key: const ValueKey('activityProgress'), style: zText(narrow ? 26 : 30, FontWeight.w600)),
            ],
          );
    return Container(
      padding: EdgeInsets.fromLTRB(narrow ? 24 : 56, narrow ? 24 : 52, narrow ? 24 : 56, narrow ? 20 : 44),
      decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: LayoutBuilder(
        builder: (context, box) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.24),
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!narrow || !portrait) ...[ZTag('${st('activity', l)} · ${st('kind.$kind', l)}'), SizedBox(height: narrow ? 10 : 16)],
                          MathText(b.f('prompt').t(l), style: zTitle(narrow ? 34 : 52)),
                        ],
                      ),
                    ),
                    if (progressW != null && !portrait) ...[const SizedBox(width: 48), progressW],
                  ],
                ),
              ),
            ),
            if (progressW != null && portrait) ...[const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: progressW)],
            SizedBox(height: narrow ? 16 : 40),
            Expanded(child: body),
            SizedBox(height: narrow ? 12 : 40),
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
                          if (message != null)
                            Text(message!, key: const ValueKey('activityResult'), style: zText(narrow ? 28 : 32, FontWeight.w600).copyWith(color: ok || revealed ? Z.correct : (logic.marks.isEmpty ? Z.ink : Z.wrongText)))
                          else if (!narrow)
                            Text('${st(_hint, l)} ${st('checkHint', l)}', style: zText(28, FontWeight.w400).copyWith(color: Z.muted)),
                          if (explanation != null && (ok || revealed)) ...[const SizedBox(height: 8), MathText('${st('why', l)}: ${explanation.t(l)}', style: zText(narrow ? 26 : 30, FontWeight.w400).copyWith(color: Z.ink2, height: 1.5))],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  BigButton(key: const ValueKey('activityReset'), collapse: true, icon: Icons.replay, label: st('resetActivity', l), filled: false, onPressed: reset),
                  const SizedBox(width: 20),
                  BigButton(key: const ValueKey('activityShow'), collapse: true, icon: Icons.visibility_outlined, label: st('showAnswer', l), filled: false, onPressed: showAnswer),
                  const SizedBox(width: 20),
                  BigButton(key: const ValueKey('activityCheck'), icon: Icons.check, label: st('check', l), onPressed: check),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
