import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../engine/model.dart' show glyphSafe;

/// Text with inline `$…$` LaTeX, as written in concept blocks. With [accent], `*word*` is a
/// keyword drawn in that colour (lesson cards, rules and speech bubbles; never code, where `*`
/// is multiplication). [align] centres a rule.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style, this.accent, this.align, this.maxLines});
  final String text;
  final TextStyle? style;
  final Color? accent;
  final TextAlign? align;
  final int? maxLines;

  /// Plain text split into keyword (odd) and normal (even) runs.
  static List<InlineSpan> _words(String t, Color? accent, TextStyle s) {
    if (accent == null || !t.contains('*')) return [TextSpan(text: t)];
    final runs = t.split('*');
    return [
      for (var i = 0; i < runs.length; i++)
        if (runs[i].isNotEmpty) TextSpan(text: runs[i], style: i.isOdd ? TextStyle(color: accent, fontWeight: s.fontWeight == FontWeight.w400 ? FontWeight.w600 : s.fontWeight) : null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = style ?? Theme.of(context).textTheme.bodyLarge!;
    final parts = glyphSafe(text).split(r'$');
    // A formula wider than the line scrolls sideways inside its own box instead of overflowing.
    return LayoutBuilder(builder: (context, box) => Text.rich(
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      TextSpan(
        style: s,
        children: [
          for (var i = 0; i < parts.length; i++)
            if (i.isOdd)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth.isFinite ? box.maxWidth : double.infinity),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Math.tex(
                      parts[i],
                      textStyle: s,
                      onErrorFallback: (_) => Text(parts[i], style: s),
                    ),
                  ),
                ),
              )
            else
              ..._words(parts[i], accent, s),
        ],
      ),
    ));
  }
}

/// A display formula, large and centred.
class Formula extends StatelessWidget {
  const Formula(this.tex, {super.key});
  final String tex;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 44),
    decoration: BoxDecoration(color: const Color(0xFFF4F6F3), borderRadius: BorderRadius.circular(24)),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        tex,
        textStyle: const TextStyle(fontSize: 46, color: Color(0xFF15191C)),
        onErrorFallback: (_) => Text(tex, style: const TextStyle(fontSize: 36)),
      ),
    ),
  );
}
