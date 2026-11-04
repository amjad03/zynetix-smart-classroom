import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/model.dart';
import 'play_model.dart';
import 'scene_painter.dart' show formatValue;
import 'strings.dart';

/// Play/Pause, Step, Reset, a scrubber, the time, and the speed (tap to cycle) — one row, each
/// target [Z.tap] high, that fits a phone held either way.
class TimeBar extends StatelessWidget {
  const TimeBar({super.key, required this.rt, required this.lang});
  final PlayRuntime rt;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final m = rt.model;
    Widget icon(String key, IconData i, String tip, VoidCallback onTap, {bool filled = false}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tip,
        child: SizedBox.square(
          dimension: Z.tap,
          child: filled
              ? FilledButton(key: ValueKey(key), onPressed: onTap, style: FilledButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(Z.tap, Z.tap)), child: Icon(i, size: 52))
              : OutlinedButton(key: ValueKey(key), onPressed: onTap, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(Z.tap, Z.tap)), child: Icon(i, size: 48)),
        ),
      ),
    );
    final speedLabel = '${formatValue(rt.speed)}×';
    return Row(
      children: [
        icon('timePlay', rt.playing ? Icons.pause : Icons.play_arrow, st(rt.playing ? 'pause' : 'play', lang), rt.toggle, filled: true),
        icon('timeStep', Icons.skip_next, st('step', lang), rt.stepOnce),
        icon('timeReset', Icons.replay, st('reset', lang), rt.reset),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 22),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 40),
              activeTrackColor: Z.accent,
              thumbColor: Z.accent,
              inactiveTrackColor: Colors.white24,
            ),
            child: SizedBox(
              height: Z.tap,
              child: Slider(key: const ValueKey('timeScrub'), min: m.min, max: m.max, value: rt.t.clamp(m.min, m.max), onChanged: rt.seek),
            ),
          ),
        ),
        SizedBox(
          width: 170,
          child: Text(
            '${rt.t.toStringAsFixed(2)} ${m.unit}',
            key: const ValueKey('timeValue'),
            textAlign: TextAlign.right,
            style: zText(34, FontWeight.w800).copyWith(color: Z.accent),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: st('speed', lang),
          child: SizedBox(
            height: Z.tap,
            child: OutlinedButton(
              key: const ValueKey('timeSpeed'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(Z.tap * 1.2, Z.tap), padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: () {
                final sp = m.speeds;
                rt.setSpeed(sp[(sp.indexOf(rt.speed) + 1) % sp.length]);
              },
              child: Text(speedLabel, style: zText(32, FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Toggles, choices and buttons, wrapped to the width: big chips and buttons.
class ExtraControls extends StatelessWidget {
  const ExtraControls({super.key, required this.rt, required this.lang});
  final PlayRuntime rt;
  final Lang lang;

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
    if (m.toggles.isEmpty && m.choices.isEmpty && m.buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (i, b) in m.buttons.indexed)
            SizedBox(
              height: Z.tap,
              child: FilledButton.icon(
                key: ValueKey('button-$i'),
                onPressed: () => rt.press(b),
                icon: Icon(buttonIcon(b.icon), size: 44),
                label: Text(b.label.t(lang), style: zText(30)),
              ),
            ),
          for (final tg in m.toggles) _Toggle(spec: tg, on: (rt.controls[tg.name] ?? 0) != 0, lang: lang, onChanged: (v) => rt.setControl(tg.name, v ? 1 : 0)),
          for (final ch in m.choices) _Choice(spec: ch, value: rt.controls[ch.name] ?? ch.value, lang: lang, onChanged: (v) => rt.setControl(ch.name, v)),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.spec, required this.on, required this.lang, required this.onChanged});
  final ToggleSpec spec;
  final bool on;
  final Lang lang;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: on ? Z.accent.withValues(alpha: 0.2) : Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Z.radius),
      side: BorderSide(color: on ? Z.accent : Colors.white38, width: 3),
    ),
    child: InkWell(
      key: ValueKey('toggle-${spec.name}'),
      borderRadius: BorderRadius.circular(Z.radius),
      onTap: () => onChanged(!on),
      child: Container(
        constraints: const BoxConstraints(minHeight: Z.tap),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(on ? Icons.toggle_on : Icons.toggle_off_outlined, size: 56, color: on ? Z.accent : Colors.white54),
            const SizedBox(width: 12),
            Flexible(child: Text(spec.label.t(lang), style: zText(30))),
          ],
        ),
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.spec, required this.value, required this.lang, required this.onChanged});
  final ChoiceSpec spec;
  final double value;
  final Lang lang;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text('${spec.label.t(lang)}:', style: zText(30, FontWeight.w700)),
      for (final (i, (label, v)) in spec.options.indexed)
        Material(
          color: v == value ? Z.accent : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Z.radius),
            side: BorderSide(color: v == value ? Z.accent : Colors.white38, width: 3),
          ),
          child: InkWell(
            key: ValueKey('choice-${spec.name}-$i'),
            borderRadius: BorderRadius.circular(Z.radius),
            onTap: () => onChanged(v),
            child: Container(
              constraints: const BoxConstraints(minHeight: Z.tap, minWidth: Z.tap),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(label.t(lang), style: zText(30, FontWeight.w700).copyWith(color: v == value ? Colors.black : null)),
            ),
          ),
        ),
    ],
  );
}
