import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../engine/model.dart';
import '../simple/kit.dart';
import 'school.dart';

export '../simple/kit.dart';

/// Makes any of the kit's drawn buttons and cards tappable, with a ripple in their shape.
class Press extends StatelessWidget {
  const Press({super.key, required this.child, this.onTap, this.radius = 999, this.onLongPress, this.label});
  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final double radius;

  /// What a screen reader says (the drawn words usually say it already).
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(opacity: onTap == null && onLongPress == null ? .45 : 1, child: child),
      ),
    ),
  );
}

/// Draws a fixed-size board layout ([width] × [height] canvas units, the approved 1440 × 810
/// board design at two units per pixel) scaled to fit the screen, so it looks the same on any
/// board, laptop or landscape tablet; any spare room is the page colour.
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({super.key, required this.child, this.width = 2880, this.height = 1620, this.color = Colors.white});
  final Widget child;
  final double width, height;
  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: LayoutBuilder(
      builder: (context, box) {
        if ((box.maxWidth - width).abs() < 1 && (box.maxHeight - height).abs() < 1) return child;
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: width,
            height: height,
            child: MediaQuery(data: MediaQuery.of(context).copyWith(size: Size(width, height)), child: child),
          ),
        );
      },
    ),
  );
}

/// The phone layout is used on phones and upright tablets.
bool usePhoneLayout(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.width < 1200 || s.height > s.width * 1.05;
}

/// Rebuilds when the language or the school's records change.
class SchoolBuilder extends StatelessWidget {
  const SchoolBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, Lang l, SchoolStore school) builder;
  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return ListenableBuilder(listenable: Listenable.merge([s.config, s.school]), builder: (context, _) => builder(context, s.config.lang, s.school));
  }
}

/// A teacher's initials disc in their colour.
Widget teacherFace(Teacher t, {double size = 96, Color? ring}) => Face(t.initials, Color(t.colorValue), size: size, ring: ring);

/// "Good morning" / afternoon / evening by the board's clock.
String greeting(Lang l, DateTime now) => now.hour < 12
    ? tr(l, 'Good morning', 'ಶುಭೋದಯ')
    : now.hour < 17
    ? tr(l, 'Good afternoon', 'ಶುಭ ಮಧ್ಯಾಹ್ನ')
    : tr(l, 'Good evening', 'ಶುಭ ಸಂಜೆ');

const _daysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _daysKn = ['ಸೋಮ', 'ಮಂಗಳ', 'ಬುಧ', 'ಗುರು', 'ಶುಕ್ರ', 'ಶನಿ', 'ಭಾನು'];
const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsKn = ['ಜನವರಿ', 'ಫೆಬ್ರವರಿ', 'ಮಾರ್ಚ್', 'ಏಪ್ರಿಲ್', 'ಮೇ', 'ಜೂನ್', 'ಜುಲೈ', 'ಆಗಸ್ಟ್', 'ಸೆಪ್ಟೆಂಬರ್', 'ಅಕ್ಟೋಬರ್', 'ನವೆಂಬರ್', 'ಡಿಸೆಂಬರ್'];
const dayNamesEn = _daysEn, dayNamesKn = _daysKn;

/// "Wed 4 Nov" / "ಬುಧ 4 ನವೆಂಬರ್".
String shortDate(Lang l, DateTime d) => l == Lang.kn ? '${_daysKn[d.weekday - 1]} ${d.day} ${_monthsKn[d.month - 1]}' : '${_daysEn[d.weekday - 1]} ${d.day} ${_monthsEn[d.month - 1]}';

/// A plain rounded text field in the website style.
class ZxField extends StatelessWidget {
  const ZxField({super.key, required this.controller, required this.label, this.size = 40, this.obscure = false, this.number = false, this.maxLength, this.autofocus = false, this.lines = 1, this.fieldKey});
  final TextEditingController controller;
  final String label;
  final double size;
  final bool obscure, number, autofocus;
  final int? maxLength;
  final int lines;
  final Key? fieldKey;
  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    obscureText: obscure,
    autofocus: autofocus,
    maxLength: maxLength,
    minLines: lines,
    maxLines: lines == 1 ? 1 : lines + 2,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    style: tx(size, c: S.ink, w: FontWeight.w500, h: 1.3),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: tx(size * .8, c: S.muted),
      filled: true,
      fillColor: S.mist,
      counterText: '',
      contentPadding: EdgeInsets.symmetric(horizontal: size * .9, vertical: size * .7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(size * .8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(size * .8), borderSide: const BorderSide(color: S.violet, width: 4)),
    ),
  );
}

/// A website-style dialog: a white rounded card with a big title, content and buttons.
Future<T?> showZxDialog<T>(BuildContext context, {required String title, required Widget Function(BuildContext) body, List<Widget> Function(BuildContext)? actions, double width = 1400}) => showDialog<T>(
  context: context,
  builder: (ctx) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(64)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(72, 64, 72, 56),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: hd(80)),
            const SizedBox(height: 36),
            body(ctx),
            if (actions != null) ...[
              const SizedBox(height: 48),
              Wrap(alignment: WrapAlignment.end, spacing: 24, runSpacing: 16, children: actions(ctx)),
            ],
          ]),
        ),
      ),
    ),
  ),
);

/// A kit button that is pressable: [BigButton]'s look with a tap.
class ZxButton extends StatelessWidget {
  const ZxButton(this.label, {super.key, this.icon, this.trailing, this.onTap, this.bg = S.ink, this.fg = Colors.white, this.height = 120, this.size = 36, this.shadow = false, this.border});
  final String label;
  final IconData? icon, trailing;
  final VoidCallback? onTap;
  final Color bg, fg;
  final Color? border;
  final double height, size;
  final bool shadow;
  @override
  Widget build(BuildContext context) => Press(
    onTap: onTap,
    child: BigButton(label, icon: icon, trailing: trailing, bg: bg, fg: fg, height: height, size: size, shadow: shadow, border: border),
  );
}

/// A pill switch with a word ("Show all tools").
class ZxSwitch extends StatelessWidget {
  const ZxSwitch({super.key, required this.on, required this.onChanged, this.w = 132});
  final bool on;
  final ValueChanged<bool> onChanged;
  final double w;
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: on,
    child: GestureDetector(onTap: () => onChanged(!on), child: BigSwitch(on: on, w: w)),
  );
}

/// The "Works without internet" tag, or "Needs internet" on what only works online.
Widget offlineTag(Lang l, {double size = 30, bool online = false}) => online
    ? Tag(tr(l, 'Needs internet', 'ಇಂಟರ್ನೆಟ್ ಬೇಕು'), icon: Icons.wifi_rounded, bg: S.peach, fg: S.rust, size: size)
    : Tag(tr(l, 'Works without internet', 'ಇಂಟರ್ನೆಟ್ ಇಲ್ಲದೆಯೂ ಕೆಲಸ ಮಾಡುತ್ತದೆ'), icon: Icons.cloud_done_outlined, bg: S.greenSoft, fg: S.green, size: size);

/// A short snack message in the website style.
void toast(BuildContext context, String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
  SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: S.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
    content: Text(text, style: tx(34, c: Colors.white, w: FontWeight.w600)),
  ),
);

/// The website card (PastelCard's look) whose words shrink to fit any height.
class ZxCard extends StatelessWidget {
  const ZxCard({super.key, required this.bg, required this.icon, required this.title, required this.sub, this.tags = const [], this.lang = Lang.en, this.titleSize = 64, this.compact = false, this.iconSize = 128, this.subLines = 2, this.pad = 52});
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
      Flexible(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: hd(titleSize, l: lang))),
      SizedBox(height: compact ? 8 : 14),
      Flexible(child: Text(sub, maxLines: subLines, overflow: TextOverflow.ellipsis, style: tx(compact ? 28 : 34, c: S.cardText))),
      if (tags.isNotEmpty) const Spacer(),
      if (tags.isNotEmpty) Flexible(child: ClipRect(child: Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tags) Tag(t, size: compact ? 24 : 28)]))),
    ]),
  );
}
