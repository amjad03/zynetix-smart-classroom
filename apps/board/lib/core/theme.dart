
import 'package:flutter/material.dart';

export 'ui.dart';

/// The bundled typefaces (assets/fonts, OFL; see assets/fonts/NOTICE.md). Nothing is loaded
/// from the network: Inter for interface text, Poppins for titles, Noto Sans Kannada for ಕನ್ನಡ.
abstract final class ZFonts {
  static const inter = 'Inter';
  static const poppins = 'Poppins';
  static const kannada = 'NotoSansKannada';

  /// Kannada first, then the maths signs and Devanagari kept in kinetix_ui.
  static const fallback = [kannada, 'packages/kinetix_ui/NotoSansMath', 'packages/kinetix_ui/NotoSansDevanagari', 'packages/kinetix_ui/Inter'];

  /// Numbers line up in columns (readouts, timers, scores).
  static const tabular = [FontFeature.tabularFigures()];
}

/// A text style in Inter (button, tab and segment styles do not inherit the theme's family).
/// Figures are tabular, so changing values do not jitter.
TextStyle zText(double size, [FontWeight weight = FontWeight.w600]) =>
    TextStyle(fontSize: size, fontWeight: weight, fontFamily: ZFonts.inter, fontFamilyFallback: ZFonts.fallback, fontFeatures: ZFonts.tabular);

/// A title style in Poppins 600 (screen titles, section headings, question stems).
TextStyle zTitle(double size, [FontWeight weight = FontWeight.w600]) =>
    TextStyle(fontSize: size, fontWeight: weight, fontFamily: ZFonts.poppins, fontFamilyFallback: ZFonts.fallback, height: 1.3);

/// Design tokens. Sizes are layout-canvas units: two per pixel of the approved design at phone
/// size (so a 48 px button is 96 here), and [UiScale] draws the canvas at the display size the
/// college chose. Colour carries meaning only: blue for the action, green right, orange wrong.
abstract final class Z {
  // Type.
  static const double body = 30, small = 26, title = 42, display = 56;

  // Touch targets, spacing and corners.
  static const double tap = 96, gap = 32, radius = 24, panelRadius = 32, stageRadius = 40, pill = 999;

  // Chrome (light everywhere).
  static const page = Color(0xFFEEF0EC);
  static const panel = Color(0xFFFFFFFF);
  static const ink = Color(0xFF15191C);
  static const ink2 = Color(0xFF4A5257);
  static const muted = Color(0xFF5B6369);
  static const faint = Color(0xFF8A9196);
  static const ghost = Color(0xFFA9B0B4);
  static const line = Color(0xFFD3D7D1);
  static const track = Color(0xFFE3E6E1);
  static const segTrack = Color(0xFFF1F3EF);
  static const tile = Color(0xFFF4F6F3);
  static const well = Color(0xFFF7F8F6);
  static const primary = Color(0xFF2457E6);
  static const primaryDark = Color(0xFF163F9E);
  static const tagBg = Color(0xFFEAF0FD);
  static const correct = Color(0xFF00875A);
  static const correctBg = Color(0xFFE7F4EE);
  static const correctTint = Color(0xFFD6EFE3);
  static const correctLabel = Color(0xFF1D6E4F);
  static const wrong = Color(0xFFC44D0B);
  static const wrongText = Color(0xFFA0430C);
  static const wrongBg = Color(0xFFFDF0E8);
  static const highlight = Color(0xFFFFF4E0);

  /// Stars, points and trophies (rewards only).
  static const star = Color(0xFFE69F00);

  /// The action colour in chrome (headings' icons, links, the selected thing).
  static const accent = primary;

  // The dark stage the subject sits on (simulations, models, labs, the chalkboard).
  static const stage = Color(0xFF141A1D);
  static const transport = Color(0xFF1E262A);
  static const stageButton = Color(0xFF2A3438);
  static const stageTrack = Color(0xFF34403F);
  static const stageGrid = Color(0xFF20282C);
  static const stageAxis = Color(0xFF4A5459);
  static const stagePill = Color(0xFF232C30);
  static const onStage = Color(0xFFE7EAE6);
  static const onStage2 = Color(0xFF9AA3A8);
  static const onStage3 = Color(0xFF8E979C);

  /// The highlight on the stage: the running value, the thing being moved.
  static const stageAccent = Color(0xFFF2A93B);

  // Data colours (Okabe–Ito), bright cut for the dark stage.
  static const orange = Color(0xFFF2A93B), sky = Color(0xFF56B4E9), green = Color(0xFF3CC08E), yellow = Color(0xFFF0E442);
  static const blue = Color(0xFF0072B2), vermillion = Color(0xFFE8613C), purple = Color(0xFFCC79A7);

  /// Teams in a team quiz: Okabe–Ito blue, vermillion, green and purple (tell apart for colour-blind eyes).
  static const teamColors = [Color(0xFF0072B2), Color(0xFFD55E00), Color(0xFF009E73), Color(0xFFCC79A7)];

  /// The 1 px lift on a selected segment and on draggable chips (the only shadows).
  static const lift = [BoxShadow(color: Color(0x1F15191C), blurRadius: 4, offset: Offset(0, 2))];
}

const _scheme = ColorScheme(
  brightness: Brightness.light,
  primary: Z.primary,
  onPrimary: Colors.white,
  primaryContainer: Z.tagBg,
  onPrimaryContainer: Z.primaryDark,
  secondary: Z.ink2,
  onSecondary: Colors.white,
  secondaryContainer: Z.tagBg,
  onSecondaryContainer: Z.primaryDark,
  tertiary: Z.correct,
  onTertiary: Colors.white,
  tertiaryContainer: Z.correctBg,
  onTertiaryContainer: Z.correctLabel,
  error: Z.wrong,
  onError: Colors.white,
  errorContainer: Z.wrongBg,
  onErrorContainer: Z.wrongText,
  surface: Z.panel,
  onSurface: Z.ink,
  onSurfaceVariant: Z.muted,
  surfaceContainerLowest: Z.panel,
  surfaceContainerLow: Z.well,
  surfaceContainer: Z.tile,
  surfaceContainerHigh: Z.segTrack,
  surfaceContainerHighest: Z.segTrack,
  outline: Z.line,
  outlineVariant: Z.track,
  inverseSurface: Z.stage,
  onInverseSurface: Z.onStage,
  inversePrimary: Color(0xFF9DB6F5),
  shadow: Color(0xFF15191C),
  scrim: Color(0x9915191C),
  surfaceTint: Colors.transparent,
);

/// The board theme: light chrome (white panels on a pale grey-green page), Inter and Poppins.
ThemeData zynetixTheme() {
  final base = ThemeData(useMaterial3: true, colorScheme: _scheme, fontFamily: ZFonts.inter, fontFamilyFallback: ZFonts.fallback, visualDensity: VisualDensity.standard);
  TextStyle i(double s, FontWeight w, [double h = 1.4]) => zText(s, w).copyWith(color: Z.ink, height: h);
  TextStyle p(double s, [FontWeight w = FontWeight.w600]) => zTitle(s, w).copyWith(color: Z.ink);
  final text = TextTheme(
    displayLarge: p(Z.display),
    displayMedium: p(48),
    displaySmall: p(44),
    headlineLarge: p(Z.title),
    headlineMedium: p(36),
    headlineSmall: p(34),
    titleLarge: p(30),
    titleMedium: i(30, FontWeight.w600),
    titleSmall: i(28, FontWeight.w600),
    bodyLarge: i(Z.body, FontWeight.w400, 1.5),
    bodyMedium: i(28, FontWeight.w400, 1.5),
    bodySmall: i(Z.small, FontWeight.w400, 1.45).copyWith(color: Z.muted),
    labelLarge: i(Z.body, FontWeight.w500, 1.2),
    labelMedium: i(Z.small, FontWeight.w500, 1.2),
    labelSmall: i(24, FontWeight.w500, 1.2),
  );
  final r12 = BorderRadius.circular(Z.radius), r16 = BorderRadius.circular(Z.panelRadius);
  const btnPad = EdgeInsets.symmetric(horizontal: 36);
  return base.copyWith(
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: Z.page,
    canvasColor: Z.panel,
    dividerColor: Z.track,
    disabledColor: Z.ghost,
    splashFactory: InkRipple.splashFactory,
    iconTheme: const IconThemeData(color: Z.ink, size: 40),
    dividerTheme: const DividerThemeData(color: Z.track, thickness: 2, space: 2),
    appBarTheme: AppBarTheme(
      backgroundColor: Z.page,
      foregroundColor: Z.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: p(Z.title),
      iconTheme: const IconThemeData(color: Z.ink, size: 40),
    ),
    cardTheme: CardThemeData(elevation: 0, color: Z.panel, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: r16), margin: EdgeInsets.zero),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Z.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Z.track,
        disabledForegroundColor: Z.ghost,
        minimumSize: const Size(Z.tap, Z.tap),
        padding: btnPad,
        elevation: 0,
        textStyle: zText(Z.body, FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: r12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? Z.well : Z.panel),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? Z.ghost : Z.ink),
        iconColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? Z.ghost : Z.ink),
        side: WidgetStateProperty.resolveWith((s) => BorderSide(color: s.contains(WidgetState.disabled) ? Z.track : Z.line, width: 2)),
        minimumSize: const WidgetStatePropertyAll(Size(Z.tap, Z.tap)),
        padding: const WidgetStatePropertyAll(btnPad),
        textStyle: WidgetStatePropertyAll(zText(Z.body, FontWeight.w500)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: r12)),
        overlayColor: WidgetStatePropertyAll(Z.ink.withValues(alpha: 0.05)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Z.primary, minimumSize: const Size(Z.tap, Z.tap), textStyle: zText(Z.body, FontWeight.w500), shape: RoundedRectangleBorder(borderRadius: r12)),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Z.ink, minimumSize: const Size(Z.tap, Z.tap), shape: RoundedRectangleBorder(borderRadius: r12))),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Z.panel : Z.segTrack),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Z.ink : Z.ink2),
        side: const WidgetStatePropertyAll(BorderSide(color: Z.segTrack, width: 4)),
        textStyle: WidgetStatePropertyAll(zText(28, FontWeight.w600)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: r12)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Z.primary : Z.line),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbIcon: const WidgetStatePropertyAll(null),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 12,
      activeTrackColor: Z.primary,
      inactiveTrackColor: Z.track,
      thumbColor: Colors.white,
      overlayColor: Color(0x1A2457E6),
      thumbShape: const RingThumbShape(),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 44),
      trackShape: const RoundedRectSliderTrackShape(),
      tickMarkShape: SliderTickMarkShape.noTickMark,
      showValueIndicator: ShowValueIndicator.never,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Z.segTrack,
      selectedColor: Z.tagBg,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: zText(Z.small, FontWeight.w500).copyWith(color: Z.ink2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Z.ink,
      unselectedLabelColor: Z.muted,
      labelStyle: zText(Z.body, FontWeight.w600),
      unselectedLabelStyle: zText(Z.body, FontWeight.w500),
      indicatorColor: Z.primary,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: Z.primary, width: 6), borderRadius: BorderRadius.all(Radius.circular(6))),
      dividerColor: Colors.transparent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Z.primary, linearTrackColor: Z.track, circularTrackColor: Z.track, borderRadius: BorderRadius.all(Radius.circular(Z.pill))),
    dialogTheme: DialogThemeData(backgroundColor: Z.panel, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: r16), titleTextStyle: p(Z.title), contentTextStyle: text.bodyLarge),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Z.panel, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(backgroundColor: Z.stage, contentTextStyle: zText(28, FontWeight.w500).copyWith(color: Z.onStage), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: r12)),
    tooltipTheme: TooltipThemeData(textStyle: zText(24, FontWeight.w500).copyWith(color: Colors.white), decoration: BoxDecoration(color: Z.stage, borderRadius: r12)),
    listTileTheme: const ListTileThemeData(iconColor: Z.muted, textColor: Z.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Z.tile,
      border: OutlineInputBorder(borderRadius: r12, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: r12, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: r12, borderSide: const BorderSide(color: Z.primary, width: 3)),
      labelStyle: zText(28, FontWeight.w500).copyWith(color: Z.muted),
      hintStyle: zText(28, FontWeight.w400).copyWith(color: Z.faint),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Z.primary : Z.faint)),
    checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Z.primary : Colors.transparent), side: const BorderSide(color: Z.faint, width: 2)),
    popupMenuTheme: PopupMenuThemeData(color: Z.panel, surfaceTintColor: Colors.transparent, textStyle: text.bodyLarge, shape: RoundedRectangleBorder(borderRadius: r12)),
  );
}

/// The theme inside a dark stage: Kinetix labs and players drawn there read light-on-dark.
ThemeData zynetixStageTheme() {
  final t = zynetixTheme();
  final scheme = _scheme.copyWith(
    brightness: Brightness.dark,
    primary: Z.stageAccent,
    onPrimary: Z.stage,
    primaryContainer: Z.stageButton,
    onPrimaryContainer: Z.onStage,
    secondaryContainer: Z.stageButton,
    onSecondaryContainer: Z.onStage,
    surface: Z.stage,
    onSurface: Z.onStage,
    onSurfaceVariant: Z.onStage2,
    surfaceContainerLowest: Z.stage,
    surfaceContainerLow: Z.transport,
    surfaceContainer: Z.transport,
    surfaceContainerHigh: Z.stageButton,
    surfaceContainerHighest: Z.stageButton,
    outline: Z.stageAxis,
    outlineVariant: Z.stageTrack,
  );
  TextTheme on(TextTheme x) => x.apply(bodyColor: Z.onStage, displayColor: Z.onStage);
  return t.copyWith(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Z.stage,
    canvasColor: Z.stage,
    textTheme: on(t.textTheme),
    primaryTextTheme: on(t.primaryTextTheme),
    iconTheme: const IconThemeData(color: Z.onStage, size: 40),
    cardTheme: t.cardTheme.copyWith(color: Z.transport),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Z.stage,
        minimumSize: const Size(Z.tap, Z.tap),
        textStyle: zText(28, FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Z.stageButton,
        foregroundColor: Z.onStage,
        side: BorderSide.none,
        minimumSize: const Size(Z.tap, Z.tap),
        textStyle: zText(28, FontWeight.w500),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Z.stageAccent, textStyle: zText(28, FontWeight.w500))),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Z.onStage)),
    sliderTheme: t.sliderTheme.copyWith(activeTrackColor: Z.stageAccent, inactiveTrackColor: Z.stageTrack, thumbShape: const RingThumbShape(ring: Colors.white, fill: Colors.white)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Z.stage : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Z.stageAccent : Z.stageTrack),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    chipTheme: t.chipTheme.copyWith(backgroundColor: Z.stageButton, selectedColor: Z.stageAccent, labelStyle: zText(Z.small, FontWeight.w500).copyWith(color: Z.onStage)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Z.stageButton),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Z.stage : Z.onStage),
        side: const WidgetStatePropertyAll(BorderSide(color: Z.stageButton, width: 4)),
        textStyle: WidgetStatePropertyAll(zText(26, FontWeight.w600)),
      ),
    ),
    dividerColor: Z.stageTrack,
    dividerTheme: const DividerThemeData(color: Z.stageTrack, thickness: 2, space: 2),
    tabBarTheme: t.tabBarTheme.copyWith(labelColor: Z.onStage, unselectedLabelColor: Z.onStage2, indicatorColor: Z.stageAccent),
    inputDecorationTheme: t.inputDecorationTheme.copyWith(fillColor: Z.transport),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Z.stageAccent, linearTrackColor: Z.stageTrack),
  );
}

/// A round slider thumb: white with a coloured ring (the slider's active colour unless [ring]).
class RingThumbShape extends SliderComponentShape {
  const RingThumbShape({this.radius = 24, this.ring, this.fill = Colors.white});
  final double radius;
  final Color? ring;
  final Color fill;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radius);

  @override
  void paint(PaintingContext context, Offset center, {required Animation<double> activationAnimation, required Animation<double> enableAnimation, required bool isDiscrete, required TextPainter labelPainter, required RenderBox parentBox, required SliderThemeData sliderTheme, required TextDirection textDirection, required double value, required double textScaleFactor, required Size sizeWithOverflow}) {
    final c = context.canvas;
    final enabled = enableAnimation.value > 0.5;
    c.drawCircle(center, radius, Paint()..color = fill);
    final ringColor = ring ?? (enabled ? sliderTheme.activeTrackColor ?? Z.primary : Z.ghost);
    if (ringColor != fill) {
      c.drawCircle(
        center,
        radius - 2,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }
  }
}

/// Screen classes, measured on the (scaled) layout canvas.
extension ScreenSize on BuildContext {
  /// A phone, or a tablet held upright: toolbars show icons only.
  bool get narrow => MediaQuery.sizeOf(this).width < 1700;

  /// Taller than wide: side panels go under the content instead of beside it.
  bool get portrait => MediaQuery.sizeOf(this).width < MediaQuery.sizeOf(this).height;
}

/// A labelled button with an icon, [Z.tap] high: primary (blue, [filled]) or secondary (white
/// with a hairline border). With [collapse], it shows just the icon (the label becomes its
/// tooltip) on a narrow screen. [color] fills it with another colour (a destructive action).
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.icon, required this.label, this.onPressed, this.filled = true, this.color, this.collapse = false, this.trailingIcon = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? color;
  final bool collapse;

  /// The icon after the label (Next →).
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final iconOnly = collapse && context.narrow;
    final ic = Icon(icon, size: 40);
    final Widget child = iconOnly
        ? Tooltip(message: label, child: ic)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!trailingIcon) ...[ic, const SizedBox(width: 16)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
              if (trailingIcon) ...[const SizedBox(width: 20), ic],
            ],
          );
    final size = iconOnly ? const Size(Z.tap, Z.tap) : null;
    final style = filled
        ? FilledButton.styleFrom(backgroundColor: color, foregroundColor: color == null ? null : Colors.white, minimumSize: size, padding: iconOnly ? EdgeInsets.zero : null)
        : OutlinedButton.styleFrom(minimumSize: size, padding: iconOnly ? EdgeInsets.zero : null);
    return filled ? FilledButton(onPressed: onPressed, style: style, child: child) : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}
