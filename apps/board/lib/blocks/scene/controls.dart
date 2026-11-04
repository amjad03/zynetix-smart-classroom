import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/model.dart';
import 'play_model.dart';
import 'scene_painter.dart' show formatValue;
import 'strings.dart';

/// The transport inside a stage: round Play/Pause, Step and Reset, a pill scrubber, the time, the
/// speed chip (tap to cycle) and the model's own buttons (Launch…). Each target is at least
/// 42 design px; it fits a phone held either way.
class TimeBar extends StatelessWidget {
  const TimeBar({super.key, required this.rt, required this.lang, this.buttons = true});
  final PlayRuntime rt;
  final Lang lang;

  /// Show the model's buttons here (on a narrow screen they go to the Controls panel).
  final bool buttons;

  @override
  Widget build(BuildContext context) {
    final m = rt.model;
    final speedLabel = '${formatValue(rt.speed)}×';
    return LayoutBuilder(
      builder: (context, box) {
        // Narrow: no Step, the model's button without its label, and the time shrinks to fit.
        final w = box.maxWidth, compact = w < 1100, tight = w < 760;
        return ZTransport(
          gap: compact ? 12 : 20,
          children: [
            StageButton(key: const ValueKey('timePlay'), primary: true, icon: rt.playing ? Icons.pause : Icons.play_arrow, tooltip: st(rt.playing ? 'pause' : 'play', lang), onPressed: rt.toggle, size: compact ? 80 : 92),
            if (!tight) StageButton(key: const ValueKey('timeStep'), icon: Icons.skip_next, tooltip: st('step', lang), onPressed: rt.stepOnce, size: compact ? 72 : 84),
            StageButton(key: const ValueKey('timeReset'), icon: Icons.replay, tooltip: st('reset', lang), onPressed: rt.reset, size: compact ? 72 : 84),
            if (buttons) for (final (i, b) in m.buttons.indexed) _StageAction(key: ValueKey('button-$i'), label: b.label.t(lang), icon: ExtraControls.buttonIcon(b.icon), showLabel: w >= 1300, onPressed: () => rt.press(b)),
            Expanded(
              child: SizedBox(
                height: 72,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 12,
                    activeTrackColor: Z.stageAccent,
                    inactiveTrackColor: Z.stageTrack,
                    thumbShape: const RingThumbShape(radius: 18, ring: Colors.white),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 30),
                    overlayColor: Colors.white.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: Slider(key: const ValueKey('timeScrub'), min: m.min, max: m.max, value: rt.t.clamp(m.min, m.max), onChanged: rt.seek),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: tight ? 150 : 260),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${rt.t.toStringAsFixed(2)} ${m.unit}',
                  key: const ValueKey('timeValue'),
                  textAlign: TextAlign.right,
                  style: zText(compact ? 28 : 30, FontWeight.w500).copyWith(color: Z.onStage),
                ),
              ),
            ),
            Tooltip(
              message: st('speed', lang),
              child: StagePill(
                key: const ValueKey('timeSpeed'),
                label: speedLabel,
                height: compact ? 72 : 80,
                onPressed: () {
                  final sp = m.speeds;
                  rt.setSpeed(sp[(sp.indexOf(rt.speed) + 1) % sp.length]);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A model's button on the stage (Launch, Add…): a white pill.
class _StageAction extends StatelessWidget {
  const _StageAction({super.key, required this.label, required this.icon, required this.onPressed, this.showLabel = true});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool showLabel;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Container(
          height: 84,
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 32 : 22),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: Z.stage),
              if (showLabel) ...[const SizedBox(width: 12), Text(label, style: zText(28, FontWeight.w600).copyWith(color: Z.stage))],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Choices (segmented), toggles (pill switches) and, when there is no transport, the model's
/// buttons, for the Controls panel.
class ExtraControls extends StatelessWidget {
  const ExtraControls({super.key, required this.rt, required this.lang, this.buttons = true});
  final PlayRuntime rt;
  final Lang lang;

  /// Show the model's buttons here (else they are in the transport).
  final bool buttons;

  static IconData buttonIcon(String? name) => switch (name) {
    'play' => Icons.play_arrow,
    'add' => Icons.add_circle_outline,
    'remove' => Icons.remove_circle_outline,
    'next' => Icons.skip_next,
    'reset' => Icons.replay,
    'launch' => Icons.rocket_launch_outlined,
    'flip' => Icons.swap_horiz,
    'check' => Icons.check_circle_outline,
    _ => Icons.touch_app_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final m = rt.model;
    final showButtons = buttons && m.buttons.isNotEmpty;
    if (m.toggles.isEmpty && m.choices.isEmpty && !showButtons) return const SizedBox.shrink();
    final gap = context.narrow ? 20.0 : 32.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final ch in m.choices) ...[_Choice(spec: ch, value: rt.controls[ch.name] ?? ch.value, lang: lang, onChanged: (v) => rt.setControl(ch.name, v)), SizedBox(height: gap)],
        for (final tg in m.toggles) ...[
          ZSwitchRow(key: ValueKey('toggle-${tg.name}'), label: tg.label.t(lang), value: (rt.controls[tg.name] ?? 0) != 0, onChanged: (v) => rt.setControl(tg.name, v ? 1 : 0)),
          SizedBox(height: gap * 0.6),
        ],
        if (showButtons)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (i, b) in m.buttons.indexed)
                BigButton(key: ValueKey('button-$i'), icon: buttonIcon(b.icon), label: b.label.t(lang), filled: i == 0, onPressed: () => rt.press(b)),
            ],
          ),
      ],
    );
  }
}

/// A choice: its name over a segmented control (wraps into rows when there are many options).
class _Choice extends StatelessWidget {
  const _Choice({required this.spec, required this.value, required this.lang, required this.onChanged});
  final ChoiceSpec spec;
  final double value;
  final Lang lang;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final opts = spec.options;
    final rows = <List<int>>[];
    for (var i = 0; i < opts.length; i += 3) {
      rows.add([for (var k = i; k < math.min(i + 3, opts.length); k++) k]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(spec.label.t(lang), style: zText(30, FontWeight.w500).copyWith(color: Z.ink)),
        const SizedBox(height: 20),
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: 12),
          ZSegmented<int>(
            items: [for (final i in row) (i, opts[i].$1.t(lang), ValueKey('choice-${spec.name}-$i'))],
            selected: opts.indexWhere((o) => o.$2 == value),
            onChanged: (i) => onChanged(opts[i].$2),
          ),
        ],
      ],
    );
  }
}
