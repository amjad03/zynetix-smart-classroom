import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/model.dart';

/// Simple-first classroom (v8): the Zynetix School website look for a first-time teacher.
/// Navy display headings in Bricolage Grotesque, DM Sans text, soft pastel cards with a white
/// arrow chip, white pill tags and plenty of white space. Sizes are canvas units (two per design
/// pixel on a board, see `AppConfig.uiScale`), so 108 units is the 72 px minimum touch target.
abstract final class S {
  // Website tokens (quest-academy tailwind.config.ts, zx.*).
  static const ink = Color(0xFF13165A);
  static const violet = Color(0xFF5442D8);
  static const deep = Color(0xFF4433C4);
  static const soft = Color(0xFFEEEBFB);
  static const body = Color(0xFF4A4E66);
  static const muted = Color(0xFF6B6F85);
  static const line = Color(0xFFE5E7EF);
  static const mist = Color(0xFFF6F6FA);
  static const eyebrow = Color(0xFFB8501C);
  static const green = Color(0xFF1F7A4D);
  static const greenSoft = Color(0xFFE5F3EA);
  static const night = Color(0xFF2B2F75);
  static const rust = Color(0xFFB4441B);
  static const cardText = Color(0xFF3D4060);

  // The landing page's "What are you preparing for?" card colours.
  static const lavender = Color(0xFFEEEBFB);
  static const peach = Color(0xFFFFE9DC);
  static const mint = Color(0xFFDDF3E7);
  static const sky = Color(0xFFDCEBFF);
  static const butter = Color(0xFFFFF2CC);
  static const pink = Color(0xFFF4E3F5);

  /// The website's card shadow: 0 18px 40px rgba(19,22,90,.14).
  static const shadow = [BoxShadow(color: Color(0x2413165A), blurRadius: 80, offset: Offset(0, 36))];
  static const shadowSoft = [BoxShadow(color: Color(0x1413165A), blurRadius: 40, offset: Offset(0, 16))];

  static const display = 'ZxDisplay', text = 'ZxText';
  static const tap = 108.0;
}

String tr(Lang l, String en, String kn) => l == Lang.kn ? kn : en;

/// A display heading (Bricolage, tight tracking like the website). Kannada keeps normal tracking.
TextStyle hd(double s, {Color c = S.ink, FontWeight w = FontWeight.w700, Lang l = Lang.en}) => TextStyle(
  fontFamily: S.display,
  fontFamilyFallback: ZFonts.fallback,
  fontSize: l == Lang.kn ? s * .86 : s,
  fontWeight: w,
  color: c,
  height: l == Lang.kn ? 1.32 : 1.06,
  letterSpacing: l == Lang.kn ? 0 : -s * .035,
);

/// Body text (DM Sans).
TextStyle tx(double s, {Color c = S.body, FontWeight w = FontWeight.w400, double h = 1.45}) =>
    TextStyle(fontFamily: S.text, fontFamilyFallback: ZFonts.fallback, fontSize: s, fontWeight: w, color: c, height: h);

/// The small white circle with ↗ in the corner of every website card.
class ArrowChip extends StatelessWidget {
  const ArrowChip({super.key, this.size = 84, this.color = Colors.white, this.fg = S.ink});
  final double size;
  final Color color, fg;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(Icons.arrow_outward_rounded, size: size * .5, color: fg),
  );
}

/// A rounded tag.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.size = 30, this.bg = const Color(0xBFFFFFFF), this.fg = S.ink, this.icon});
  final String text;
  final double size;
  final Color bg, fg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size * .8, vertical: size * .38),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: size * 1.2, color: fg), SizedBox(width: size * .35)],
      Text(text, style: tx(size, c: fg, w: FontWeight.w500, h: 1.2)),
    ]),
  );
}

/// The one main action on a screen: a big rounded button with an icon and plain words.
class BigButton extends StatelessWidget {
  const BigButton(this.label, {super.key, this.icon, this.bg = S.ink, this.fg = Colors.white, this.height = 160, this.size = 52, this.trailing, this.border, this.shadow = true});
  final String label;
  final IconData? icon, trailing;
  final Color bg, fg;
  final Color? border;
  final double height, size;
  final bool shadow;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    padding: EdgeInsets.symmetric(horizontal: height * .36),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: border == null ? null : Border.all(color: border!, width: 4),
      boxShadow: shadow && border == null ? [BoxShadow(color: bg.withValues(alpha: .35), blurRadius: 48, offset: const Offset(0, 20))] : null,
    ),
    child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: size * 1.3, color: fg), SizedBox(width: size * .45)],
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(size, c: fg, w: FontWeight.w700, h: 1.1))),
      if (trailing != null) ...[SizedBox(width: size * .45), Icon(trailing, size: size * 1.1, color: fg)],
    ]),
  );
}

/// A square-ish tool button: icon above its word (never an icon alone).
class ToolButton extends StatelessWidget {
  const ToolButton(this.label, this.icon, {super.key, this.bg = const Color(0x1FFFFFFF), this.fg = Colors.white, this.width = 220, this.height = 160, this.on = false, this.dot});
  final String label;
  final IconData icon;
  final Color bg, fg;
  final double width, height;
  final bool on;
  final Color? dot;
  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(36), border: on ? Border.all(color: fg, width: 5) : null),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      dot != null
          ? Container(width: 64, height: 64, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5), boxShadow: S.shadowSoft))
          : Icon(icon, size: 64, color: fg),
      const SizedBox(height: 10),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(30, c: fg, w: FontWeight.w600, h: 1.1)),
    ]),
  );
}

/// A website card: pastel fill, big title, a line of plain words, tags and the arrow chip.
class PastelCard extends StatelessWidget {
  const PastelCard({super.key, required this.bg, required this.icon, required this.title, required this.sub, this.tags = const [], this.lang = Lang.en, this.titleSize = 64, this.compact = false, this.iconSize = 128, this.subLines = 2, this.pad = 52});
  final Color bg;
  final IconData icon;
  final String title, sub;
  final List<String> tags;
  final Lang lang;
  final double titleSize, iconSize, pad;
  final int subLines;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 36 : pad),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(compact ? 40 : 56)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: compact ? 96 : iconSize, height: compact ? 96 : iconSize,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(compact ? 28 : 36)),
          child: Icon(icon, size: compact ? 54 : iconSize * .56, color: S.ink),
        ),
        const Spacer(),
        ArrowChip(size: compact ? 68 : 84),
      ]),
      compact ? const SizedBox(height: 24) : const Spacer(),
      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: hd(titleSize, l: lang)),
      SizedBox(height: compact ? 8 : 14),
      Text(sub, maxLines: subLines, overflow: TextOverflow.ellipsis, style: tx(compact ? 28 : 34, c: S.cardText)),
      if (tags.isNotEmpty) const Spacer(),
      if (tags.isNotEmpty) Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tags) Tag(t, size: compact ? 24 : 28)]),
    ]),
  );
}

/// The always-visible help button.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, this.lang = Lang.en, this.size = 40, this.dark = false});
  final Lang lang;
  final double size;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    height: size * 3.4,
    padding: EdgeInsets.fromLTRB(size * .5, 0, size * 1.1, 0),
    decoration: BoxDecoration(color: dark ? Colors.white : S.violet, borderRadius: BorderRadius.circular(999), boxShadow: S.shadow),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size * 2.4, height: size * 2.4,
        decoration: BoxDecoration(color: dark ? S.violet : Colors.white, shape: BoxShape.circle),
        child: Icon(Icons.question_mark_rounded, size: size * 1.4, color: dark ? Colors.white : S.violet),
      ),
      SizedBox(width: size * .5),
      Text(tr(lang, 'What do I do now?', 'ಈಗ ನಾನು ಏನು ಮಾಡಲಿ?'), style: tx(size, c: dark ? S.ink : Colors.white, w: FontWeight.w700, h: 1.1)),
    ]),
  );
}

/// An on/off switch drawn at board size.
class BigSwitch extends StatelessWidget {
  const BigSwitch({super.key, required this.on, this.w = 132});
  final bool on;
  final double w;
  @override
  Widget build(BuildContext context) => Container(
    width: w, height: w * .56,
    padding: EdgeInsets.all(w * .06),
    alignment: on ? Alignment.centerRight : Alignment.centerLeft,
    decoration: BoxDecoration(color: on ? S.violet : const Color(0xFFD3D6E2), borderRadius: BorderRadius.circular(999)),
    child: Container(
      width: w * .44, height: w * .44,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x3313165A), blurRadius: 8, offset: Offset(0, 3))]),
      child: on ? Icon(Icons.check_rounded, size: w * .28, color: S.violet) : null,
    ),
  );
}

/// A teacher's initials in a soft disc (a photo goes here when the school adds one).
class Face extends StatelessWidget {
  const Face(this.initials, this.color, {super.key, this.size = 96, this.ring});
  final String initials;
  final Color color;
  final double size;
  final Color? ring;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: ring == null ? null : Border.all(color: ring!, width: size * .06),
    ),
    alignment: Alignment.center,
    child: Text(initials, style: hd(size * .38, c: Colors.white, w: FontWeight.w700)),
  );
}

/// The Zynetix mark and name.
class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 72, this.dark = false});
  final double size;
  final bool dark;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: size, height: size,
      decoration: BoxDecoration(color: dark ? Colors.white : S.ink, borderRadius: BorderRadius.circular(size * .3)),
      alignment: Alignment.center,
      child: Text('Z', style: hd(size * .62, c: dark ? S.ink : Colors.white, w: FontWeight.w800)),
    ),
    SizedBox(width: size * .28),
    Text('Zynetix Board', style: hd(size * .5, c: dark ? Colors.white : S.ink, w: FontWeight.w700)),
  ]);
}

/// "Step 3 of 12" with a bar, always visible.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.of, this.lang = Lang.en, this.dark = true, this.width = 520, this.size = 34});
  final int step, of;
  final Lang lang;
  final bool dark;
  final double width, size;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(tr(lang, 'Step $step of $of', 'ಹಂತ $step / $of'), style: tx(size, c: dark ? Colors.white : S.ink, w: FontWeight.w700, h: 1.1)),
    SizedBox(height: size * .4),
    Container(
      width: width, height: size * .42,
      decoration: BoxDecoration(color: dark ? const Color(0x33FFFFFF) : S.line, borderRadius: BorderRadius.circular(99)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: step / of,
        child: Container(decoration: BoxDecoration(color: dark ? const Color(0xFFFFC857) : S.violet, borderRadius: BorderRadius.circular(99))),
      ),
    ),
  ]);
}

/// A round tick (done), a ring with a number (now) or an empty ring (later).
class Tick extends StatelessWidget {
  const Tick({super.key, this.done = false, this.now = false, this.n, this.size = 76});
  final bool done, now;
  final int? n;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: done ? S.green : (now ? S.violet : Colors.white),
      border: done || now ? null : Border.all(color: const Color(0xFFD3D6E2), width: size * .06),
    ),
    alignment: Alignment.center,
    child: done
        ? Icon(Icons.check_rounded, size: size * .66, color: Colors.white)
        : Text(n == null ? '' : '$n', style: tx(size * .42, c: now ? Colors.white : S.muted, w: FontWeight.w700, h: 1)),
  );
}

/// A rough little "you can't break anything" line with a shield.
class SafeLine extends StatelessWidget {
  const SafeLine(this.text, {super.key, this.size = 34, this.c = S.green});
  final String text;
  final double size;
  final Color c;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.verified_user_rounded, size: size * 1.3, color: c),
    SizedBox(width: size * .4),
    Flexible(child: Text(text, style: tx(size, c: c, w: FontWeight.w600, h: 1.25))),
  ]);
}
