import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Text with inline `$…$` LaTeX, as written in concept blocks.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = style ?? Theme.of(context).textTheme.bodyLarge!;
    final parts = text.split(r'$');
    // A formula wider than the line scrolls sideways inside its own box instead of overflowing.
    return LayoutBuilder(builder: (context, box) => Text.rich(
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
              TextSpan(text: parts[i]),
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
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(24)),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Math.tex(
        tex,
        textStyle: const TextStyle(fontSize: 44),
        onErrorFallback: (_) => Text(tex, style: const TextStyle(fontSize: 36)),
      ),
    ),
  );
}
