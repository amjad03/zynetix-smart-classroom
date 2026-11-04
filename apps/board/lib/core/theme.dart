import 'package:flutter/material.dart';
import 'package:kinetix_ui/kinetix_ui.dart';

/// Back-bench sizes: a 75" board read from 8–10 m. Every tap target is at least [tap] high.
/// A text style in the board font (button, tab and segment styles do not inherit the theme's family).
TextStyle zText(double size, [FontWeight weight = FontWeight.w600]) => TextStyle(fontSize: size, fontWeight: weight, fontFamily: KxFonts.family, fontFamilyFallback: KxFonts.fallback);

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
      style: FilledButton.styleFrom(
        minimumSize: const Size(Z.tap * 1.6, Z.tap),
        textStyle: zText(30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(Z.tap * 1.6, Z.tap),
        textStyle: zText(30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius)),
      ),
    ),
  );
}

/// Screen classes, measured on the (scaled) layout canvas.
extension ScreenSize on BuildContext {
  /// A phone, or a tablet held upright: toolbars show icons only.
  bool get narrow => MediaQuery.sizeOf(this).width < 1700;

  /// Taller than wide: side panels go under the content instead of beside it.
  bool get portrait => MediaQuery.sizeOf(this).width < MediaQuery.sizeOf(this).height;
}

/// A large labelled button with an icon: the only kind of button on the board. With [collapse],
/// it shows just the icon (the label becomes its tooltip) on a narrow screen.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.icon, required this.label, this.onPressed, this.filled = true, this.color, this.collapse = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? color;
  final bool collapse;

  @override
  Widget build(BuildContext context) {
    final iconOnly = collapse && context.narrow;
    final Widget child = iconOnly
        ? Tooltip(message: label, child: Icon(icon, size: 44))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44),
              const SizedBox(width: 14),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final size = iconOnly ? const Size(Z.tap, Z.tap) : null;
    final style = filled
        ? FilledButton.styleFrom(backgroundColor: color, foregroundColor: color == null ? null : Colors.white, minimumSize: size, padding: iconOnly ? EdgeInsets.zero : null)
        : OutlinedButton.styleFrom(minimumSize: size, padding: iconOnly ? EdgeInsets.zero : null);
    return filled ? FilledButton(onPressed: onPressed, style: style, child: child) : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}
