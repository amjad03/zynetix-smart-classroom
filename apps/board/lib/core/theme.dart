import 'package:flutter/material.dart';
import 'package:kinetix_ui/kinetix_ui.dart';

/// Back-bench sizes: a 75" board read from 8–10 m. Every tap target is at least [tap] high.
abstract final class Z {
  static const double body = 34, small = 26, title = 48, display = 68, tap = 96, gap = 24, radius = 28;
  static const correct = Color(0xFF1B8A3A), wrong = Color(0xFFC62828), accent = Color(0xFFFFB300);
  static const teamColors = [Color(0xFF1565C0), Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFF6A1B9A)];
}

/// The Kinetix board theme (chalkboard green, SansFlex), scaled up for the back bench.
ThemeData zynetixTheme() {
  final base = KinetixTheme.board();
  final t = base.textTheme;
  return base.copyWith(
    textTheme: t.copyWith(
      displayLarge: t.displayLarge?.copyWith(fontSize: Z.display, fontWeight: FontWeight.w700),
      headlineLarge: t.headlineLarge?.copyWith(fontSize: Z.title, fontWeight: FontWeight.w700),
      headlineMedium: t.headlineMedium?.copyWith(fontSize: 40, fontWeight: FontWeight.w600),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: Z.body, height: 1.35),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: Z.small),
      labelLarge: t.labelLarge?.copyWith(fontSize: 30, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(Z.tap * 1.6, Z.tap), textStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(Z.tap * 1.6, Z.tap), textStyle: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius))),
    ),
  );
}

/// A large labelled button with an icon: the only kind of button on the board.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.icon, required this.label, this.onPressed, this.filled = true, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 44), const SizedBox(width: 14), Text(label)]);
    final style = color == null ? null : FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white);
    return filled ? FilledButton(onPressed: onPressed, style: style, child: child) : OutlinedButton(onPressed: onPressed, child: child);
  }
}
