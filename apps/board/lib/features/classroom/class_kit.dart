import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import '../app/help.dart';

/// The frame every whole-class mode uses: the top bar (breadcrumb, title, then [trailing], the
/// language switch and close), the content, and an optional bottom bar like the lesson player's.
/// Type is sized for the back bench: on a 1080p board body text is 24 px or more.
class ClassScaffold extends StatelessWidget {
  const ClassScaffold({super.key, required this.crumbs, required this.title, required this.body, this.trailing = const [], this.bottomLeft = const [], this.bottomRight = const [], this.help});
  final List<String> crumbs;

  /// What "What do I do now?" says here (a general hint when null).
  final HelpInfo Function()? help;
  final String title;
  final Widget body;
  final List<Widget> trailing, bottomLeft, bottomRight;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final l = s.config.lang;
    final narrow = context.narrow, pad = narrow ? 20.0 : 32.0;
    final hasBottom = bottomLeft.isNotEmpty || bottomRight.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ZTopBar(
                crumbs: crumbs,
                title: title,
                trailing: [
                  ...trailing,
                  HelpChip(
                    info: help ??
                        () => const HelpInfo(
                          next: L10n('Use the big buttons at the bottom. The X at the top right takes you back.', 'ಕೆಳಗಿನ ದೊಡ್ಡ ಬಟನ್‌ಗಳನ್ನು ಬಳಸಿ. ಮೇಲಿನ ಬಲಭಾಗದ X ಹಿಂದಕ್ಕೆ ಕರೆದೊಯ್ಯುತ್ತದೆ.'),
                        ),
                  ),
                  if (s.config.kannadaOffered)
                    ZSmallButton(
                      key: const ValueKey('classLang'),
                      label: l == Lang.en ? 'ಕನ್ನಡ' : 'English',
                      onPressed: () => s.config.setLang(l == Lang.en ? Lang.kn : Lang.en),
                    ),
                  ZIconSquare(icon: Icons.close, tooltip: 'Close', onPressed: () => Navigator.of(context).maybePop()),
                ],
              ),
              SizedBox(height: pad),
              Expanded(child: body),
              if (hasBottom) ...[
                SizedBox(height: pad),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
                  child: Row(
                    children: [
                      for (final (i, w) in bottomLeft.indexed) ...[if (i > 0) const SizedBox(width: 20), w],
                      const Spacer(),
                      for (final (i, w) in bottomRight.indexed) ...[if (i > 0) const SizedBox(width: 20), w],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rebuilds [builder] when the board language changes.
class LangBuilder extends StatelessWidget {
  const LangBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, Lang lang) builder;

  @override
  Widget build(BuildContext context) {
    final config = ServicesScope.of(context).config;
    return ListenableBuilder(listenable: config, builder: (context, _) => builder(context, config.lang));
  }
}

/// A big round-cornered label for the top bar: "Step 2 of 6", "KCET", "Sample".
class BarChip extends StatelessWidget {
  const BarChip(this.text, {super.key, this.icon, this.color = Z.ink2, this.background = Z.segTrack});
  final String text;
  final IconData? icon;
  final Color color, background;

  @override
  Widget build(BuildContext context) => Container(
    height: 84,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Z.radius)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 34, color: color), const SizedBox(width: 12)],
        Text(text, style: zText(28, FontWeight.w600).copyWith(color: color)),
      ],
    ),
  );
}

/// A small caps-style label over a panel's content ("SOLUTION", "THE CLASS GOT IT").
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color = Z.muted, this.size = 28});
  final String text;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Text(text, style: zText(size, FontWeight.w600).copyWith(color: color, letterSpacing: 0.4));
}

/// What a roll number's answer was marked: not yet, right or wrong.
enum Mark { none, right, wrong }

/// One roll number in a tap grid: white when not marked, green with a tick when right, orange
/// with a cross when wrong. The number is large enough to find from across the room.
class RollCell extends StatelessWidget {
  const RollCell({super.key, required this.roll, required this.mark, this.onTap, this.label, this.dim = false, this.selected = false});
  final int roll;
  final Mark mark;
  final VoidCallback? onTap;

  /// Shown under the number instead of the mark (a score).
  final String? label;
  final bool dim;

  /// The roll number being entered (a thick blue ring).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (mark) {
      Mark.right => (Z.correct, Colors.white, Z.correct),
      Mark.wrong => (Z.wrong, Colors.white, Z.wrong),
      Mark.none => (dim ? Z.well : Z.panel, dim ? Z.ghost : Z.ink, Z.line),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius), side: BorderSide(color: selected ? Z.primary : border, width: selected ? 8 : 3)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Z.radius),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, box) {
            final big = (box.maxHeight * (box.maxWidth < 120 ? 0.36 : 0.42)).clamp(30.0, 60.0);
            return Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$roll', style: zText(big, FontWeight.w700).copyWith(color: fg, height: 1.1)),
                      if (mark != Mark.none && label == null && box.maxWidth < 120) Icon(mark == Mark.right ? Icons.check_rounded : Icons.close_rounded, size: 26, color: Colors.white),
                      if (label != null) Text(label!, style: zText(big * 0.62, FontWeight.w600).copyWith(color: mark == Mark.none ? Z.primary : fg, height: 1.2)),
                    ],
                  ),
                ),
                if (mark != Mark.none && label == null && box.maxWidth >= 120)
                  Positioned(
                    right: 10,
                    top: 8,
                    child: Icon(mark == Mark.right ? Icons.check_rounded : Icons.close_rounded, size: (big * 0.6).clamp(24.0, 40.0), color: Colors.white),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Roll numbers 1…[count] in a grid that fills its box: [cell] builds each one.
class RollGrid extends StatelessWidget {
  const RollGrid({super.key, required this.count, required this.cell, this.columns, this.gap = 16});
  final int count;
  final Widget Function(int roll) cell;
  final int? columns;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // As square as the box allows: try column counts and keep the one with the biggest cells.
      var best = columns ?? 8;
      if (columns == null) {
        var bestSide = 0.0;
        for (var c = 4; c <= 14; c++) {
          final rows = (count / c).ceil();
          final w = (box.maxWidth - gap * (c - 1)) / c, h = (box.maxHeight - gap * (rows - 1)) / rows;
          final side = w < h ? w : h;
          if (side > bestSide) {
            bestSide = side;
            best = c;
          }
        }
      }
      final rows = (count / best).ceil();
      final w = (box.maxWidth - gap * (best - 1)) / best;
      final h = ((box.maxHeight - gap * (rows - 1)) / rows).clamp(72.0, 200.0);
      return SingleChildScrollView(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (var r = 1; r <= count; r++) SizedBox(width: w, height: h, child: cell(r))],
        ),
      );
    },
  );
}

/// A pill showing a roll number (in "revisit" and "rolls below 50" lists).
class RollChip extends StatelessWidget {
  const RollChip(this.roll, {super.key, this.color = Z.wrongText, this.background = Z.wrongBg, this.size = 34});
  final int roll;
  final Color color, background;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minWidth: size * 2.4),
    padding: EdgeInsets.symmetric(horizontal: size * 0.5, vertical: size * 0.28),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Z.radius)),
    child: Text('$roll', textAlign: TextAlign.center, style: zText(size, FontWeight.w700).copyWith(color: color)),
  );
}

/// Option letters.
const optionLetters = ['A', 'B', 'C', 'D', 'E'];
