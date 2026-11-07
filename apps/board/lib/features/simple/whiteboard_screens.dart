import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kinetix_ui/kinetix_ui.dart' show KxFonts;

import '../../core/theme.dart' show ZFonts;
import '../../engine/model.dart';
import '../combined/kit.dart' show LangOf;
import 'kit.dart';

/// The whiteboard in the simple-first (v9) design: the board is a big white sheet, every tool is
/// a labelled button, and the teacher can always Undo or ask "What do I do now?". Sizes are canvas
/// units (see kit.dart); a 1080p board is a 2880 × 1620 canvas.
const _pad = 140.0;
const _ink = Color(0xFF1B1D2E), _blue = Color(0xFF2457E6), _red = Color(0xFFD7263D), _green = Color(0xFF1F9D55);
const _hiYellow = Color(0x80FFE45C);

/// What the whiteboard screen shows.
enum WbView { simple, allTools, geometry, kit, lessonPage, insert, projector }

TextStyle _hand(double s, Color c) =>
    TextStyle(fontFamily: KxFonts.kalam, fontFamilyFallback: ZFonts.fallback, fontSize: s, color: c, height: 1.1, fontWeight: FontWeight.w400);

class WhiteboardScreen extends StatelessWidget {
  const WhiteboardScreen({super.key, this.view = WbView.simple});
  final WbView view;

  @override
  Widget build(BuildContext context) => LangOf(builder: (context, l) {
    final tablet = MediaQuery.sizeOf(context).width < 2000; // board canvas is 2880 wide
    if (tablet) return _Tablet(l);
    return switch (view) {
      WbView.simple => _SimpleBoard(l),
      WbView.allTools => _AllTools(l),
      WbView.geometry => _Geometry(l),
      WbView.kit => _KitOpen(l),
      WbView.lessonPage => _LessonPage(l),
      WbView.insert => Stack(children: [_SimpleBoard(l), Positioned.fill(child: _InsertMenu(l))]),
      WbView.projector => const _Projector(),
    };
  });
}

// ───────────────────────────── shared pieces ─────────────────────────────

/// The board sheet: white, rounded, soft shadow, with an optional background pattern.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child, this.paper = _PaperKind.plain});
  final Widget child;
  final _PaperKind paper;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: const Color(0xFFFFFFFE), borderRadius: BorderRadius.circular(48), boxShadow: S.shadowSoft, border: Border.all(color: S.line, width: 3)),
    child: Stack(children: [
      if (paper != _PaperKind.plain) Positioned.fill(child: CustomPaint(painter: _Paper(paper))),
      Positioned.fill(child: child),
    ]),
  );
}

/// Fits a fixed design stage into whatever room it gets.
Widget _fit(Widget stage, {Alignment a = Alignment.center, double pad = 40}) =>
    Padding(padding: EdgeInsets.all(pad), child: FittedBox(fit: BoxFit.contain, alignment: a, child: stage));

/// A labelled pill button for the top bar.
class _Pill extends StatelessWidget {
  const _Pill(this.label, this.icon, {this.dot, this.trailing, this.h = 120, this.size = 34});
  final String label;
  final IconData icon;
  final Color? dot;
  final Widget? trailing;
  static const bg = Colors.white, fg = S.ink;
  final double h, size;
  @override
  Widget build(BuildContext context) => Container(
    height: h,
    padding: EdgeInsets.symmetric(horizontal: h * .3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: S.line, width: 3)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      dot != null
          ? Container(width: size * 1.1, height: size * 1.1, decoration: BoxDecoration(color: dot, shape: BoxShape.circle))
          : Icon(icon, size: size * 1.3, color: fg),
      SizedBox(width: size * .45),
      Text(label, style: tx(size, c: fg, w: FontWeight.w700, h: 1.1)),
      if (trailing != null) ...[SizedBox(width: size * .5), trailing!],
    ]),
  );
}

/// Back · (middle) · Undo · What do I do now?
Widget _topBar(Lang l, {List<Widget> middle = const [], bool undo = true}) => Row(children: [
  BigButton(tr(l, 'Back to the lesson', 'ಪಾಠಕ್ಕೆ ಹಿಂತಿರುಗಿ'), icon: Icons.arrow_back_rounded, height: 130, size: 40),
  const SizedBox(width: 28),
  ...middle,
  const Spacer(),
  if (undo) ...[_Pill(tr(l, 'Undo', 'ರದ್ದುಮಾಡು'), Icons.undo_rounded, h: 130, size: 38), const SizedBox(width: 20)],
  HelpButton(lang: l, size: 36),
]);

/// The simple toolbar: a few big tools, each with its word.
Widget _simpleTools(Lang l, {double w = 200, double h = 176, bool clear = true}) => Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(60), boxShadow: S.shadow),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    for (final (n, c) in [(tr(l, 'Pen', 'ಪೆನ್'), _ink), (tr(l, 'Blue', 'ನೀಲಿ'), _blue), (tr(l, 'Red', 'ಕೆಂಪು'), _red)]) ...[
      ToolButton(n, Icons.circle, dot: c, bg: c == _ink ? S.soft : Colors.white, fg: S.ink, width: w, height: h, on: c == _ink),
      const SizedBox(width: 10),
    ],
    ToolButton(tr(l, 'Highlight', 'ಹೈಲೈಟ್'), Icons.border_color_rounded, bg: Colors.white, fg: S.ink, width: w, height: h),
    Container(width: 3, height: h * .7, color: S.line, margin: const EdgeInsets.symmetric(horizontal: 14)),
    ToolButton(tr(l, 'Eraser', 'ರಬ್ಬರ್'), Icons.auto_fix_normal_rounded, bg: Colors.white, fg: S.ink, width: w, height: h),
    const SizedBox(width: 10),
    ToolButton(tr(l, 'Undo', 'ರದ್ದುಮಾಡು'), Icons.undo_rounded, bg: Colors.white, fg: S.ink, width: w, height: h),
    if (clear) ...[
      const SizedBox(width: 10),
      ToolButton(tr(l, 'Clear', 'ಅಳಿಸಿ'), Icons.delete_outline_rounded, bg: S.peach, fg: S.rust, width: w, height: h),
    ],
  ]),
);

/// "Show all tools" with its switch.
Widget _showAll(Lang l, {required bool on, bool sub = true, double sw = 132}) => Row(mainAxisSize: MainAxisSize.min, children: [
  BigSwitch(on: on, w: sw),
  const SizedBox(width: 26),
  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(tr(l, 'Show all tools', 'ಎಲ್ಲಾ ಸಾಧನಗಳನ್ನು ತೋರಿಸಿ'), style: tx(38, c: S.ink, w: FontWeight.w700, h: 1.15)),
    if (sub)
      Text(tr(l, on ? 'On · switch off for the simple board' : 'Ruler, shapes, graph, pictures and more', on ? 'ಆನ್ · ಸರಳ ಬೋರ್ಡ್‌ಗೆ ಆಫ್ ಮಾಡಿ' : 'ಅಳತೆಪಟ್ಟಿ, ಆಕಾರಗಳು, ಗ್ರಾಫ್, ಚಿತ್ರಗಳು'),
          style: tx(30, c: S.muted, h: 1.3)),
  ]),
]);

/// The pages of this board, with the one on screen ringed.
class _Pages extends StatelessWidget {
  const _Pages(this.l, {this.vertical = true, this.thumbW = 340});
  final Lang l;
  final bool vertical;
  final double thumbW;
  static const current = 2;
  @override
  Widget build(BuildContext context) {
    final th = thumbW * .625;
    Widget thumb(int n) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: thumbW, height: th,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: n == current ? S.violet : S.line, width: n == current ? 6 : 3)),
        child: FittedBox(child: _Ink(l, page: n, model: false)),
      ),
      const SizedBox(height: 8),
      Text(tr(l, 'Page $n', 'ಪುಟ $n'), style: tx(28, c: n == current ? S.violet : S.ink, w: FontWeight.w700, h: 1.1)),
    ]);
    final add = Container(
      width: thumbW, height: th,
      decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFC9CCDA), width: 3)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.add_rounded, size: 64, color: S.violet),
        Text(tr(l, 'Add page', 'ಪುಟ ಸೇರಿಸಿ'), style: tx(30, c: S.violet, w: FontWeight.w700, h: 1.1)),
      ]),
    );
    final items = [thumb(1), thumb(2), thumb(3), add];
    if (!vertical) {
      return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final w in items) ...[w, const SizedBox(width: 20)],
      ]);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), boxShadow: S.shadowSoft),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(l, 'Pages', 'ಪುಟಗಳು'), style: hd(44, l: l)),
        const SizedBox(height: 20),
        for (final w in items) ...[w, const SizedBox(height: 22)],
      ]),
    );
  }
}

// ───────────────────────────── the handwriting ─────────────────────────────

/// A teacher's handwritten page on a 2400 × 1500 stage.
/// Page 1: Newton's law. Page 2: g at a height h (with the drawn Earth). Page 3: g inside the
/// Earth, with the earth_layers 3D model placed on the right.
class _Ink extends StatelessWidget {
  const _Ink(this.l, {this.page = 2, this.model = true, this.bold = 1});
  final Lang l;
  final int page;
  final bool model;
  final double bold;
  @override
  Widget build(BuildContext context) {
    Widget t(double x, double y, String s, double size, Color c) => Positioned(left: x, top: y, child: Text(s, style: _hand(size, c)));
    return SizedBox(
      width: page == 3 ? 1700 : 2400, height: 1500,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _InkPainter(page, bold))),
        if (page == 1) ...[
          t(60, 20, tr(l, "Newton's law of gravitation", 'ನ್ಯೂಟನ್‌ನ ಗುರುತ್ವ ನಿಯಮ'), 110, _ink),
          t(80, 300, 'F = G Mm / r²', 170, _ink),
          t(90, 600, 'G = 6.67 × 10⁻¹¹ N m²/kg²', 84, _blue),
          t(90, 760, tr(l, 'Every mass pulls every other mass', 'ಪ್ರತಿ ದ್ರವ್ಯರಾಶಿ ಇನ್ನೊಂದನ್ನು ಎಳೆಯುತ್ತದೆ'), 74, _green),
          t(1690, 980, 'M', 110, _ink),
          t(2150, 1000, 'm', 100, _ink),
          t(1960, 790, 'r', 90, _red),
        ],
        if (page == 2) ...[
          t(50, 10, tr(l, 'Gravitation: g at a height h', 'ಗುರುತ್ವ: ಎತ್ತರ h ನಲ್ಲಿ g'), 110, _ink),
          t(80, 250, "g' = g (1 − 2h/R)", 150, _ink),
          t(90, 492, tr(l, '(only when h is much less than R)', '(h, R ಗಿಂತ ತುಂಬಾ ಚಿಕ್ಕದಿದ್ದಾಗ)'), 64, _green),
          t(80, 610, tr(l, 'Everest:  h = 8.8 km', 'ಎವರೆಸ್ಟ್:  h = 8.8 km'), 84, _blue),
          t(80, 715, "g' = 9.8 (1 − 17.6 / 6400)", 84, _ink),
          t(80, 825, '≈ 9.77 m/s²', 100, _green),
          t(80, 1040, tr(l, 'Going down a depth d:', 'ಆಳ d ಗೆ ಇಳಿದರೆ:'), 76, _blue),
          t(80, 1140, "g'' = g (1 − d/R)", 124, _ink),
          t(1100, 1290, tr(l, 'centre: g = 0 !', 'ಕೇಂದ್ರ: g = 0 !'), 70, _red),
          t(1730, 940, 'O', 70, _ink),
          t(1880, 140, 'P', 80, _red),
          t(1655, 340, 'h', 90, _red),
          t(1910, 340, "g'", 80, _green),
          t(2050, 1010, 'R', 90, _ink),
          t(1590, 900, 'Q', 76, _blue),
          t(1525, 725, 'd', 76, _blue),
        ],
        if (page == 3) ...[
          t(50, 10, tr(l, 'g inside the Earth', 'ಭೂಮಿಯ ಒಳಗೆ g'), 110, _ink),
          t(80, 270, "g'' = g (1 − d/R)", 150, _ink),
          t(90, 560, tr(l, 'd = 0  (surface)  →  g', 'd = 0  (ಮೇಲ್ಮೈ)  →  g'), 84, _blue),
          t(90, 690, tr(l, 'd = R  (centre)  →  0', 'd = R  (ಕೇಂದ್ರ)  →  0'), 84, _blue),
          t(90, 860, tr(l, 'Look at the layers', 'ಪದರಗಳನ್ನು ನೋಡಿ'), 84, _green),
          t(90, 1100, tr(l, 'core is iron + nickel', 'ಕೋರ್: ಕಬ್ಬಿಣ + ನಿಕ್ಕಲ್'), 70, _ink),
          if (model) const Positioned(left: 970, top: 530, width: 700, height: 800, child: _PlacedModel()),
        ],
      ]),
    );
  }
}

/// Pen strokes drawn with a slight hand wobble.
Path _wobLine(Offset a, Offset b, {double amp = 4, int seed = 1}) {
  final p = Path()..moveTo(a.dx, a.dy);
  const n = 24;
  final d = b - a, nrm = Offset(-d.dy, d.dx) / (d.distance == 0 ? 1 : d.distance);
  for (var i = 1; i <= n; i++) {
    final f = i / n;
    final w = amp * math.sin(f * math.pi * 3 + seed) * math.sin(f * math.pi);
    final q = a + d * f + nrm * w;
    p.lineTo(q.dx, q.dy);
  }
  return p;
}

Path _wobCircle(Offset c, double r, {int seed = 1, double over = .14, double amp = .012}) {
  final p = Path();
  const n = 120;
  final a0 = -math.pi / 2 - .3 + seed * .4;
  for (var i = 0; i <= n; i++) {
    final a = a0 + (math.pi * 2 + over) * i / n;
    final rr = r * (1 + amp * math.sin(3 * a + seed) + amp * .5 * math.sin(7 * a + seed * 2) + .01 * i / n);
    final q = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
  }
  return p;
}

Path _wobRect(Rect r, {int seed = 1}) => Path()
  ..addPath(_wobLine(r.topLeft + const Offset(-14, 4), r.topRight + const Offset(10, -4), seed: seed), Offset.zero)
  ..addPath(_wobLine(r.topRight + const Offset(4, -14), r.bottomRight + const Offset(-4, 12), seed: seed + 1), Offset.zero)
  ..addPath(_wobLine(r.bottomRight + const Offset(12, -2), r.bottomLeft + const Offset(-10, 4), seed: seed + 2), Offset.zero)
  ..addPath(_wobLine(r.bottomLeft + const Offset(4, 14), r.topLeft + const Offset(-2, -16), seed: seed + 3), Offset.zero);

void _arrowHead(Canvas c, Offset tip, Offset from, Paint p, {double len = 34}) {
  final d = tip - from, a = math.atan2(d.dy, d.dx);
  for (final s in [-1, 1]) {
    c.drawLine(tip, tip - Offset(math.cos(a + s * .45), math.sin(a + s * .45)) * len, p);
  }
}

Paint _pen(Color c, double w) => Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

class _InkPainter extends CustomPainter {
  _InkPainter(this.page, this.bold);
  final int page;
  final double bold;
  @override
  void paint(Canvas canvas, Size s) {
    final k = bold;
    if (page == 1) {
      canvas.drawPath(_wobLine(const Offset(60, 165), const Offset(1500, 150)), _pen(_red, 8 * k));
      canvas.drawPath(_wobRect(const Rect.fromLTWH(50, 290, 1240, 250)), _pen(_red, 7 * k));
      canvas.drawPath(_wobCircle(const Offset(1740, 1040), 150), _pen(_ink, 8 * k));
      canvas.drawPath(_wobCircle(const Offset(2180, 1060), 70, seed: 3), _pen(_ink, 8 * k));
      canvas.drawPath(_wobLine(const Offset(1740, 860), const Offset(2180, 960), seed: 2), _pen(_red, 6 * k));
      return;
    }
    if (page == 3) {
      canvas.drawPath(_wobLine(const Offset(50, 165), const Offset(1050, 152)), _pen(_red, 8 * k));
      canvas.drawPath(_wobRect(const Rect.fromLTWH(46, 262, 1180, 230)), _pen(_red, 7 * k));
      final a = _pen(_green, 7 * k);
      canvas.drawPath(_wobLine(const Offset(90, 990), const Offset(840, 1010), seed: 4), a);
      _arrowHead(canvas, const Offset(860, 1010), const Offset(780, 1008), a);
      return;
    }
    // Page 2.
    canvas.drawPath(_wobLine(const Offset(50, 165), const Offset(1500, 150)), _pen(_red, 8 * k));
    canvas.drawPath(_wobRect(const Rect.fromLTWH(50, 250, 1260, 220)), _pen(_red, 7 * k));
    final g = _pen(_green, 6 * k);
    canvas.drawPath(_wobLine(const Offset(90, 960), const Offset(560, 952), seed: 2), g);
    canvas.drawPath(_wobLine(const Offset(100, 980), const Offset(540, 975), seed: 5), g);
    // Highlighter over the answer.
    canvas.drawPath(_wobLine(const Offset(120, 1220), const Offset(1060, 1214), amp: 3), _pen(_hiYellow, 70));

    // The Earth.
    const o = Offset(1840, 960);
    const r = 400.0;
    canvas.drawCircle(o, r, Paint()..color = const Color(0x142457E6));
    canvas.drawPath(_wobCircle(o, r), _pen(_blue, 9 * k));
    final land = _pen(_green, 6 * k);
    canvas.drawPath(_wobCircle(o + const Offset(-170, -150), 90, seed: 2, amp: .09), land);
    canvas.drawPath(_wobCircle(o + const Offset(160, 150), 70, seed: 5, amp: .12), land);
    canvas.drawPath(_wobCircle(o + const Offset(-120, 220), 46, seed: 7, amp: .15), land);
    canvas.drawCircle(o, 12, Paint()..color = _ink);
    // R to the surface.
    final rp = o + Offset(math.cos(.55), math.sin(.55)) * r;
    canvas.drawPath(_wobLine(o, rp, seed: 3), _pen(_ink, 6 * k));
    // P at height h, with g' pointing to the centre.
    const top = Offset(1840, 960 - r), pp = Offset(1840, 260);
    canvas.drawCircle(pp, 16, Paint()..color = _red);
    final rd = _pen(_red, 6 * k);
    const hx = Offset(-90, 0);
    canvas.drawLine(top + hx, pp + hx, rd);
    _arrowHead(canvas, top + hx, pp + hx, rd, len: 26);
    _arrowHead(canvas, pp + hx, top + hx, rd, len: 26);
    final gr = _pen(_green, 7 * k);
    canvas.drawLine(pp + const Offset(40, 30), pp + const Offset(40, 220), gr);
    _arrowHead(canvas, pp + const Offset(40, 220), pp + const Offset(40, 30), gr);
    // Q at depth d.
    final dir = Offset(math.cos(math.pi * 1.1), math.sin(math.pi * 1.1));
    final surf = o + dir * r, q = o + dir * (r - 170);
    canvas.drawCircle(q, 14, Paint()..color = _blue);
    final bl = _pen(_blue, 5 * k);
    final off = Offset(-dir.dy, dir.dx) * 50;
    canvas.drawLine(q + off, surf + off, bl);
    _arrowHead(canvas, q + off, surf + off, bl, len: 22);
    _arrowHead(canvas, surf + off, q + off, bl, len: 22);
    canvas.drawPath(_wobLine(q, o, seed: 6, amp: 2), _pen(const Color(0x881B1D2E), 3));
  }

  @override
  bool shouldRepaint(_InkPainter old) => old.page != page;
}

/// The earth_layers 3D model placed on the board, selected so it can be moved and resized.
class _PlacedModel extends StatelessWidget {
  const _PlacedModel();
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    Positioned.fill(
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF0F1340), borderRadius: BorderRadius.circular(36), border: Border.all(color: S.violet, width: 6)),
        child: CustomPaint(painter: _LayersPainter()),
      ),
    ),
    Positioned(left: 30, top: 30, child: Tag('3D · earth_layers', icon: Icons.view_in_ar_rounded, bg: const Color(0x26FFFFFF), fg: Colors.white, size: 38)),
    Positioned(
      left: 30, right: 30, bottom: 30,
      child: Row(children: [
        Tag('Drag to turn', icon: Icons.threesixty_rounded, bg: Colors.white, size: 36),
        const Spacer(),
        Tag('Remove', icon: Icons.close_rounded, bg: const Color(0x26FFFFFF), fg: Colors.white, size: 36),
      ]),
    ),
    for (final a in [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
      Align(
        alignment: a,
        child: FractionalTranslation(
          translation: Offset(a.x * .5, a.y * .5),
          child: Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: S.violet, width: 7))),
        ),
      ),
    Positioned(
      right: -30, bottom: -120,
      child: Tag('Drag a corner to resize', icon: Icons.open_in_full_rounded, bg: S.violet, fg: Colors.white, size: 38),
    ),
  ]);
}

class _LayersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width * .36, s.height * .5);
    final r = s.width * .27;
    canvas.drawCircle(c, r * 1.12, Paint()..color = const Color(0x226FB6FF));
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(colors: [Color(0xFF6FB6FF), Color(0xFF2457E6), Color(0xFF102660)], stops: [0, .62, 1], center: Alignment(-.35, -.4)).createShader(Rect.fromCircle(center: c, radius: r)));
    final land = Paint()..color = const Color(0xB03FBF7F);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(-r * .35, r * .1), width: r * .6, height: r * .8), land);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(r * .2, r * .55), width: r * .5, height: r * .3), land);
    // The cut-away quarter.
    const layers = [(1.0, Color(0xFF8D6E63)), (.93, Color(0xFFE0662F)), (.55, Color(0xFFF5A623)), (.3, Color(0xFFFFE066))];
    for (final (f, col) in layers) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * f), -math.pi / 2, math.pi / 2, true, Paint()..color = col);
    }
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, math.pi / 2, true, Paint()..color = const Color(0x33000000)..style = PaintingStyle.stroke..strokeWidth = 3);
    final lead = Paint()..color = Colors.white70..strokeWidth = 3;
    void label(String t, double f, double dy) {
      final a = -math.pi / 4;
      final from = c + Offset(math.cos(a), math.sin(a)) * r * f;
      final to = Offset(s.width * .66, c.dy + dy);
      canvas.drawLine(from, Offset(to.dx - 12, to.dy), lead);
      canvas.drawCircle(from, 6, Paint()..color = Colors.white);
      final p = TextPainter(text: TextSpan(text: t, style: tx(38, c: Colors.white, w: FontWeight.w600, h: 1)), textDirection: TextDirection.ltr)..layout();
      p.paint(canvas, Offset(to.dx, to.dy - p.height / 2));
    }

    label('Crust', .965, -r * .95);
    label('Mantle', .75, -r * .55);
    label('Outer core', .43, -r * .15);
    label('Inner core', .12, r * .25);
  }

  @override
  bool shouldRepaint(_LayersPainter old) => false;
}

// ───────────────────────────── 01 / 08 · simple board ─────────────────────────────

class _SimpleBoard extends StatelessWidget {
  const _SimpleBoard(this.l);
  final Lang l;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: S.mist,
    body: Padding(
      padding: const EdgeInsets.fromLTRB(_pad, 50, _pad, 50),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _topBar(l, middle: [
          Tag(tr(l, 'Gravitation · Board · page 2 of 3', 'ಗುರುತ್ವಾಕರ್ಷಣೆ · ಬೋರ್ಡ್ · ಪುಟ 2 / 3'), icon: Icons.description_outlined, bg: Colors.white, size: 32),
        ], undo: false),
        const SizedBox(height: 36),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _Sheet(child: _fit(_Ink(l)))),
            const SizedBox(width: 44),
            Align(alignment: Alignment.topCenter, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topCenter, child: _Pages(l, thumbW: 250))),
          ]),
        ),
        const SizedBox(height: 36),
        Row(children: [
          _simpleTools(l),
          const Spacer(),
          _showAll(l, on: false),
        ]),
      ]),
    ),
  );
}

// ───────────────────────────── 02 · all tools ─────────────────────────────

class _AllTools extends StatelessWidget {
  const _AllTools(this.l);
  final Lang l;

  Widget _group(String title, List<(String, IconData)> tools, {String? on, Color bg = S.mist}) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 6, bottom: 8), child: Text(title, style: tx(28, c: S.eyebrow, w: FontWeight.w700, h: 1.1))),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(36)),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (n, ic) in tools) ToolButton(n, ic, bg: n == on ? Colors.white : Colors.transparent, fg: S.ink, width: 188, height: 128, on: n == on),
        ]),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: S.mist,
    body: Padding(
      padding: const EdgeInsets.fromLTRB(_pad, 44, _pad, 44),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 2600,
            child: Row(children: [
              const BigButton('Back to the lesson', icon: Icons.arrow_back_rounded, height: 112, size: 34),
              const Spacer(),
              const _Pill('Record', Icons.circle, dot: _red, h: 104, size: 30),
              const SizedBox(width: 14),
              const _Pill('Projector', Icons.cast_rounded, trailing: BigSwitch(on: false, w: 84), h: 104, size: 30),
              const SizedBox(width: 14),
              const _Pill('Read aloud', Icons.volume_up_rounded, h: 104, size: 30),
              const SizedBox(width: 14),
              const _Pill('Phone as remote', Icons.phone_iphone_rounded, h: 104, size: 30),
              const SizedBox(width: 14),
              const HelpButton(size: 31),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // The grouped, labelled tools.
            Container(
              width: 810,
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), boxShadow: S.shadowSoft),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 820,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _group('Write', [('Pen', Icons.edit_rounded), ('Highlighter', Icons.border_color_rounded), ('Text', Icons.text_fields_rounded)], on: 'Pen', bg: S.lavender),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _group('Draw', [('Shapes', Icons.category_rounded), ('Line, arrow', Icons.north_east_rounded)], bg: S.peach),
                          const SizedBox(width: 18),
                          _group('Fix', [('Eraser', Icons.auto_fix_normal_rounded), ('Undo', Icons.undo_rounded)], bg: S.pink),
                        ]),
                        _group('Measure', [('Ruler', Icons.straighten_rounded), ('Protractor', Icons.architecture_rounded), ('Compass', Icons.explore_outlined), ('Set square', Icons.change_history_rounded)], bg: S.mint),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _group('Maths', [('Graph', Icons.show_chart_rounded), ('Number line', Icons.linear_scale_rounded)], bg: S.sky),
                          const SizedBox(width: 18),
                          _group('Page', [('Add page', Icons.note_add_outlined), ('Clear page', Icons.delete_outline_rounded)], bg: S.pink),
                        ]),
                        _group('Insert', [('Picture', Icons.image_outlined), ('PowerPoint', Icons.slideshow_rounded), ('3D model', Icons.view_in_ar_rounded), ('Lab', Icons.science_outlined), ('Simulation', Icons.play_circle_outline_rounded)], bg: S.butter),
                      ]),
                    ),
                  ),
                ),
                Container(height: 3, color: S.line),
                const SizedBox(height: 18),
                Row(children: [
                  const BigSwitch(on: true, w: 104),
                  const SizedBox(width: 18),
                  Expanded(child: Text('Show all tools · On', style: tx(32, c: S.ink, w: FontWeight.w700, h: 1.15))),
                ]),
              ]),
            ),
            const SizedBox(width: 36),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: _Sheet(
                    child: Stack(children: [
                      Positioned.fill(child: _fit(_Ink(l), a: Alignment.bottomRight)),
                      Positioned(left: 30, top: 30, child: _penChooser()),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _strip()),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  );

  /// The pen's colour and thickness, opened from the Pen button.
  Widget _penChooser() {
    const cols = [_ink, _blue, _red, _green, Color(0xFF8E44AD), Color(0xFFE67E22)];
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 26),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), boxShadow: S.shadow, border: Border.all(color: S.line, width: 3)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pen colour', style: tx(28, c: S.eyebrow, w: FontWeight.w700, h: 1.1)),
        const SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final c in cols)
            Container(
              width: 84, height: 84,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: c == _ink ? S.soft : S.mist, borderRadius: BorderRadius.circular(24), border: c == _ink ? Border.all(color: S.ink, width: 4) : null),
              alignment: Alignment.center,
              child: Container(width: 44, height: 44, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            ),
        ]),
        const SizedBox(height: 18),
        Text('Thickness', style: tx(28, c: S.eyebrow, w: FontWeight.w700, h: 1.1)),
        const SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (n, w) in [('Thin', 6.0), ('Medium', 14.0), ('Thick', 24.0)])
            Container(
              width: 170, height: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: n == 'Medium' ? S.soft : S.mist, borderRadius: BorderRadius.circular(24), border: n == 'Medium' ? Border.all(color: S.ink, width: 4) : null),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 70, height: w, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 10),
                Text(n, style: tx(26, c: S.ink, w: FontWeight.w600, h: 1)),
              ]),
            ),
        ]),
      ]),
    );
  }

  /// Background, zoom and pages, under the board.
  Widget _strip() {
    Widget head(String s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s, style: tx(28, c: S.eyebrow, w: FontWeight.w700, h: 1.1)));
    Widget box(Widget c, {bool on = false, double w = 150}) => Container(
      width: w, height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: on ? S.soft : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: on ? S.ink : S.line, width: on ? 4 : 3)),
      child: c,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), boxShadow: S.shadowSoft),
      child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head('Background'),
          Row(children: [
            for (final (n, k) in [('Plain', _PaperKind.plain), ('Lined', _PaperKind.lined), ('Grid', _PaperKind.grid), ('Graph', _PaperKind.graph)]) ...[
              box(Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _Paper(k, scale: .45))),
                Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), color: Colors.white, child: Text(n, style: tx(26, c: S.ink, w: FontWeight.w700, h: 1.1)))),
              ]), on: k == _PaperKind.plain),
              const SizedBox(width: 10),
            ],
          ]),
        ]),
        Container(width: 3, height: 140, color: S.line, margin: const EdgeInsets.symmetric(horizontal: 22)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head('Zoom'),
          Row(children: [
            box(const Icon(Icons.remove_rounded, size: 48, color: S.ink), w: 104),
            const SizedBox(width: 10),
            box(Center(child: Text('100%', style: tx(30, c: S.ink, w: FontWeight.w700, h: 1))), w: 130),
            const SizedBox(width: 10),
            box(const Icon(Icons.add_rounded, size: 48, color: S.ink), w: 104),
          ]),
        ]),
        Container(width: 3, height: 140, color: S.line, margin: const EdgeInsets.symmetric(horizontal: 22)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head('Pages'),
          Row(children: [
            for (final n in [1, 2, 3]) ...[
              Container(
                width: 166, height: 104,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: n == 2 ? S.violet : S.line, width: n == 2 ? 5 : 3)),
                child: Stack(children: [
                  if (n < 3) Positioned.fill(child: FittedBox(child: _Ink(l, page: n, model: false))),
                  Positioned(left: 8, bottom: 6, child: Text('$n', style: tx(24, c: n == 2 ? S.violet : S.muted, w: FontWeight.w700, h: 1))),
                ]),
              ),
              const SizedBox(width: 10),
            ],
            box(Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.add_rounded, size: 40, color: S.violet),
              Text('Add page', style: tx(26, c: S.violet, w: FontWeight.w700, h: 1)),
            ]), w: 200),
          ]),
        ]),
      ]),
    );
  }
}

// ───────────────────────────── backgrounds ─────────────────────────────

enum _PaperKind { plain, lined, grid, graph }

class _Paper extends CustomPainter {
  _Paper(this.kind, {this.scale = 1});
  final _PaperKind kind;
  final double scale;
  @override
  void paint(Canvas canvas, Size s) {
    switch (kind) {
      case _PaperKind.plain:
        return;
      case _PaperKind.lined:
        final p = Paint()..color = const Color(0xFFBBD3F2)..strokeWidth = 3 * scale;
        for (var y = 120.0 * scale; y < s.height; y += 90 * scale) {
          canvas.drawLine(Offset(0, y), Offset(s.width, y), p);
        }
        canvas.drawLine(Offset(110 * scale, 0), Offset(110 * scale, s.height), Paint()..color = const Color(0xFFF2B8C0)..strokeWidth = 3 * scale);
      case _PaperKind.grid:
        final p = Paint()..color = const Color(0xFFD5DCEB)..strokeWidth = 2 * scale;
        for (var x = 0.0; x < s.width; x += 80 * scale) {
          canvas.drawLine(Offset(x, 0), Offset(x, s.height), p);
        }
        for (var y = 0.0; y < s.height; y += 80 * scale) {
          canvas.drawLine(Offset(0, y), Offset(s.width, y), p);
        }
      case _PaperKind.graph:
        final minor = Paint()..color = const Color(0xFFDDEBF7)..strokeWidth = 1.5 * scale;
        final major = Paint()..color = const Color(0xFFA9CBEA)..strokeWidth = 3 * scale;
        final step = 28.57 * scale;
        var i = 0;
        for (var x = 0.0; x < s.width; x += step, i++) {
          canvas.drawLine(Offset(x, 0), Offset(x, s.height), i % 5 == 0 ? major : minor);
        }
        i = 0;
        for (var y = 0.0; y < s.height; y += step, i++) {
          canvas.drawLine(Offset(0, y), Offset(s.width, y), i % 5 == 0 ? major : minor);
        }
    }
  }

  @override
  bool shouldRepaint(_Paper old) => old.kind != kind;
}

// ───────────────────────────── 03 · geometry tools ─────────────────────────────

class _Geometry extends StatelessWidget {
  const _Geometry(this.l);
  final Lang l;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: S.mist,
    body: Padding(
      padding: const EdgeInsets.fromLTRB(_pad, 50, _pad, 50),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _topBar(l, middle: [Tag('Measuring · graph paper · page 3', icon: Icons.architecture_rounded, bg: Colors.white, size: 32)]),
        const SizedBox(height: 36),
        Expanded(
          child: _Sheet(
            paper: _PaperKind.graph,
            child: Stack(children: [
              Positioned.fill(child: FittedBox(fit: BoxFit.cover, alignment: Alignment.topLeft, child: SizedBox(width: 3560, height: 1620, child: _GeoStage()))),
              Positioned(
                right: 40, top: 40, width: 780,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(44, 38, 44, 40),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(44), boxShadow: S.shadow),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('How to measure an angle', style: hd(46)),
                    const SizedBox(height: 22),
                    for (final (i, s) in ['Drag the protractor. Put its centre dot on the corner B.', 'Turn it so 0 lies along the line BC.', 'Read where BA crosses the numbers: 50°.'].indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Tick(n: i + 1, now: i == 2, done: i < 2, size: 56),
                          const SizedBox(width: 20),
                          Expanded(child: Text(s, style: tx(30, c: S.cardText, h: 1.3))),
                        ]),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 36),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(60), boxShadow: S.shadow),
            child: Row(children: [
              const ToolButton('Ruler', Icons.straighten_rounded, bg: S.mint, fg: S.ink, width: 200, height: 176, on: true),
              const SizedBox(width: 10),
              const ToolButton('Protractor', Icons.architecture_rounded, bg: S.mint, fg: S.ink, width: 200, height: 176, on: true),
              const SizedBox(width: 10),
              const ToolButton('Compass', Icons.explore_outlined, bg: Colors.white, fg: S.ink, width: 200, height: 176),
              const SizedBox(width: 10),
              const ToolButton('Set square', Icons.change_history_rounded, bg: Colors.white, fg: S.ink, width: 200, height: 176),
              Container(width: 3, height: 120, color: S.line, margin: const EdgeInsets.symmetric(horizontal: 14)),
              const ToolButton('Pen', Icons.circle, dot: _ink, bg: Colors.white, fg: S.ink, width: 200, height: 176),
              const SizedBox(width: 10),
              const ToolButton('Eraser', Icons.auto_fix_normal_rounded, bg: Colors.white, fg: S.ink, width: 200, height: 176),
            ]),
          ),
          const Spacer(),
          const BigButton('Put the tools away', icon: Icons.check_rounded, bg: S.violet, height: 176, size: 46),
        ]),
      ]),
    ),
  );
}

class _GeoStage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned.fill(child: CustomPaint(painter: _GeoPainter())),
    Positioned(left: 110, top: 70, child: Text('Measure ∠ABC', style: _hand(110, _ink))),
    Positioned(left: 110, top: 230, child: Text('AB = 7 cm', style: _hand(86, _blue))),
    Positioned(left: 1060, top: 1360, child: Text('B', style: _hand(100, _ink))),
    Positioned(left: 2680, top: 1290, child: Text('C', style: _hand(100, _ink))),
    Positioned(left: 1930, top: 520, child: Text('A', style: _hand(100, _ink))),
    // Live reading where the edge crosses the scale.
    Positioned(
      left: 1480, top: 1100,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
        decoration: BoxDecoration(color: S.violet, borderRadius: BorderRadius.circular(999), boxShadow: S.shadowSoft),
        child: Text('Angle = 50°', style: tx(44, c: Colors.white, w: FontWeight.w700, h: 1.1)),
      ),
    ),
    Positioned(
      left: 380, top: 560,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
        decoration: BoxDecoration(color: S.ink, borderRadius: BorderRadius.circular(999), boxShadow: S.shadowSoft),
        child: Text('Ruler: 7.0 cm', style: tx(40, c: Colors.white, w: FontWeight.w700, h: 1.1)),
      ),
    ),
  ]);
}

class _GeoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    const b = Offset(1220, 1340);
    const len = 1000.0;
    final deg = 50 * math.pi / 180;
    final a = b + Offset(math.cos(deg), -math.sin(deg)) * len;
    const c = Offset(2650, 1340);
    final pen = _pen(_ink, 9);
    canvas.drawPath(_wobLine(b, c, amp: 2), pen);
    canvas.drawPath(_wobLine(b, a, amp: 2, seed: 3), pen);
    for (final p in [a, b, c]) {
      canvas.drawCircle(p, 13, Paint()..color = _ink);
    }

    // Protractor on B.
    const rr = 640.0;
    final half = Path()
      ..moveTo(b.dx - rr - 30, b.dy + 36)
      ..lineTo(b.dx - rr - 30, b.dy)
      ..arcTo(Rect.fromCircle(center: b, radius: rr + 30), math.pi, math.pi, false)
      ..lineTo(b.dx + rr + 30, b.dy + 36)
      ..close();
    canvas.drawPath(half, Paint()..color = const Color(0x40A9C8FF));
    canvas.drawPath(half, Paint()..color = const Color(0xFF2457E6)..style = PaintingStyle.stroke..strokeWidth = 4);
    canvas.drawArc(Rect.fromCircle(center: b, radius: rr * .42), math.pi, math.pi, false, Paint()..color = const Color(0x992457E6)..style = PaintingStyle.stroke..strokeWidth = 3);
    final tick = Paint()..color = const Color(0xFF14307F)..strokeWidth = 2.5;
    for (var d = 0; d <= 180; d++) {
      final t = -d * math.pi / 180;
      final u = Offset(math.cos(t), math.sin(t));
      final l = d % 10 == 0 ? 46.0 : (d % 5 == 0 ? 30.0 : 16.0);
      canvas.drawLine(b + u * (rr + 30), b + u * (rr + 30 - l), d == 50 ? (Paint()..color = _red..strokeWidth = 6) : tick);
      if (d % 10 == 0) {
        void num(int v, double at, double size, Color col) {
          final p = TextPainter(text: TextSpan(text: '$v', style: tx(size, c: col, w: FontWeight.w700, h: 1)), textDirection: TextDirection.ltr)..layout();
          p.paint(canvas, b + u * at - Offset(p.width / 2, p.height / 2));
        }

        num(d, rr - 50, 34, d == 50 ? _red : const Color(0xFF14307F));
        num(180 - d, rr - 108, 26, const Color(0xFF5B79C9));
      }
    }
    canvas.drawCircle(b, 16, Paint()..color = _red);
    canvas.drawLine(b - const Offset(40, 0), b + const Offset(40, 0), Paint()..color = _red..strokeWidth = 4);

    // The angle mark.
    canvas.drawArc(Rect.fromCircle(center: b, radius: 190), -deg, deg, false, _pen(_red, 8));

    // Ruler along BA, its edge on the line.
    canvas.save();
    canvas.translate(b.dx, b.dy);
    canvas.rotate(-deg);
    const pxmm = len / 70;
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(-60, -180, 1300, 180), const Radius.circular(18));
    canvas.drawRRect(body, Paint()..color = const Color(0xD9FFE7A3));
    canvas.drawRRect(body, Paint()..color = const Color(0xFFB58A1B)..style = PaintingStyle.stroke..strokeWidth = 4);
    final rt = Paint()..color = const Color(0xFF5A4410)..strokeWidth = 2.5;
    for (var mm = 0; mm <= 80; mm++) {
      final x = mm * pxmm;
      final l = mm % 10 == 0 ? 54.0 : (mm % 5 == 0 ? 36.0 : 20.0);
      canvas.drawLine(Offset(x, 0), Offset(x, -l), rt);
      if (mm % 10 == 0) {
        final p = TextPainter(text: TextSpan(text: '${mm ~/ 10}', style: tx(34, c: const Color(0xFF5A4410), w: FontWeight.w700, h: 1)), textDirection: TextDirection.ltr)..layout();
        p.paint(canvas, Offset(x - p.width / 2, -100));
      }
    }
    final cm = TextPainter(text: TextSpan(text: 'cm', style: tx(28, c: const Color(0xFF5A4410), w: FontWeight.w600, h: 1)), textDirection: TextDirection.ltr)..layout();
    cm.paint(canvas, const Offset(1170, -150));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GeoPainter old) => false;
}

// ───────────────────────────── 04 · subject kit ─────────────────────────────

class _KitOpen extends StatelessWidget {
  const _KitOpen(this.l);
  final Lang l;
  @override
  Widget build(BuildContext context) {
    const items = [
      (S.lavender, Icons.view_in_ar_rounded, '3D model', 'Layers of the Earth', true),
      (S.lavender, Icons.public_rounded, '3D model', 'Earth and Moon orbit', false),
      (S.mint, Icons.science_outlined, 'Virtual lab', 'Pendulum: find g', false),
      (S.sky, Icons.play_circle_outline_rounded, 'Simulation', 'Weight on other planets', false),
      (S.peach, Icons.auto_stories_outlined, 'Explainer', 'Why g falls with height', false),
      (S.butter, Icons.movie_outlined, 'Concept video · 4 min', "Kepler's three laws", false),
      (S.pink, Icons.quiz_outlined, 'Exam questions', '6 board-exam questions', false),
      (S.mint, Icons.science_outlined, 'Virtual lab', 'Free fall with a timer', false),
    ];
    return Scaffold(
      backgroundColor: S.mist,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(_pad, 50, _pad, 50),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const BigButton('Back to the lesson', icon: Icons.arrow_back_rounded, height: 116, size: 34),
                const Spacer(),
                const _Pill('Undo', Icons.undo_rounded, h: 116, size: 34),
                const SizedBox(width: 16),
                const HelpButton(size: 32),
              ]),
              const SizedBox(height: 36),
              Expanded(child: _Sheet(child: _fit(_Ink(l, page: 3), a: Alignment.topLeft, pad: 50))),
              const SizedBox(height: 36),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _simpleTools(l, w: 180, h: 168, clear: false)),
            ]),
          ),
          const SizedBox(width: 50),
          Container(
            width: 1200,
            padding: const EdgeInsets.fromLTRB(44, 40, 44, 40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(56), boxShadow: S.shadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Physics · Gravitation', style: tx(32, c: S.eyebrow, w: FontWeight.w600, h: 1.2)),
                    const SizedBox(height: 8),
                    Text('Subject kit for this chapter', style: hd(56)),
                  ]),
                ),
                const _Pill('Close', Icons.close_rounded, h: 104, size: 30),
              ]),
              const SizedBox(height: 10),
              Text('Everything is saved on this board. No internet needed.', style: tx(30, c: S.muted)),
              const SizedBox(height: 26),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  const gap = 20.0;
                  final w = (box.maxWidth - gap) / 2, h = (box.maxHeight - gap * 3) / 4;
                  return Wrap(spacing: gap, runSpacing: gap, children: [
                    for (final (bg, ic, kind, title, on) in items)
                      Container(
                        width: w, height: h,
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(36), border: on ? Border.all(color: S.violet, width: 5) : null),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                              child: Icon(ic, size: 42, color: S.ink),
                            ),
                            const SizedBox(width: 20),
                            Expanded(child: Text(kind, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(28, c: S.cardText, w: FontWeight.w600, h: 1.2))),
                          ]),
                          const Spacer(),
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(40)),
                          const SizedBox(height: 12),
                          Container(
                            height: 68,
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            decoration: BoxDecoration(color: on ? S.green : Colors.white, borderRadius: BorderRadius.circular(999)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(on ? Icons.check_rounded : Icons.add_rounded, size: 40, color: on ? Colors.white : S.ink),
                              const SizedBox(width: 10),
                              Text(on ? 'On the board' : 'Put on board', style: tx(30, c: on ? Colors.white : S.ink, w: FontWeight.w700, h: 1)),
                            ]),
                          ),
                        ]),
                      ),
                  ]);
                }),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────────── 05 · lesson step as a page ─────────────────────────────

class _LessonPage extends StatelessWidget {
  const _LessonPage(this.l);
  final Lang l;
  @override
  Widget build(BuildContext context) {
    const steps = [('Recall', '5 min'), ("Newton's law", '8 min'), ('g with height', '10 min'), ('g with depth', '8 min'), ('Quick check', '5 min'), ('Recap', '4 min')];
    return Scaffold(
      backgroundColor: S.mist,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(_pad, 50, _pad, 50),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _topBar(l, middle: [Text('Gravitation · today’s lesson', style: hd(52)), const SizedBox(width: 24), Tag('19 of 40 min', icon: Icons.schedule_rounded, bg: Colors.white, size: 30)]),
          const SizedBox(height: 30),
          // The lesson flow bar.
          Container(
            padding: const EdgeInsets.fromLTRB(30, 20, 30, 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), boxShadow: S.shadowSoft),
            child: Row(children: [
              for (final (i, (n, m)) in steps.indexed) ...[
                if (i > 0) Expanded(child: Container(height: 5, margin: const EdgeInsets.symmetric(horizontal: 10), color: i <= 2 ? S.green : S.line)),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 30, 12),
                  decoration: BoxDecoration(color: i == 2 ? S.soft : Colors.transparent, borderRadius: BorderRadius.circular(999), border: i == 2 ? Border.all(color: S.violet, width: 4) : null),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Tick(done: i < 2, now: i == 2, n: i + 1, size: 64),
                    const SizedBox(width: 14),
                    Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n, style: tx(32, c: S.ink, w: FontWeight.w700, h: 1.1)),
                      Text(m, style: tx(26, c: S.muted, h: 1.2)),
                    ]),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _Sheet(child: _StepPage(l))),
              const SizedBox(width: 44),
              SizedBox(
                width: 900,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Quick check with the answer covered.
                  Expanded(
                    flex: 11,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(44, 34, 44, 36),
                      decoration: BoxDecoration(color: S.lavender, borderRadius: BorderRadius.circular(52)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('Quick check · ask the class', style: tx(32, c: S.eyebrow, w: FontWeight.w600, h: 1.2)),
                          const Spacer(),
                          const ArrowChip(size: 60),
                        ]),
                        const SizedBox(height: 12),
                        Text('How high must you go for g to drop by 1%?', style: hd(52)),
                        const SizedBox(height: 12),
                        Text('Use R = 6400 km.', style: tx(30, c: S.cardText)),
                        const Spacer(),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(colors: [Color(0xFF2B2F75), Color(0xFF5442D8)]),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.visibility_off_rounded, size: 64, color: Colors.white),
                            const SizedBox(width: 22),
                            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Tap to show the answer', style: tx(40, c: Colors.white, w: FontWeight.w700, h: 1.1)),
                              Text('Hidden until you tap', style: tx(26, c: const Color(0xFFD9DBFF), h: 1.3)),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Recap page, made from the lesson.
                  Expanded(
                    flex: 8,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
                      decoration: BoxDecoration(color: S.mint, borderRadius: BorderRadius.circular(52)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Container(
                          width: 360,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Recap', style: hd(32)),
                            const SizedBox(height: 6),
                            for (final r in ['g = GM/R²', "g' = g(1 − 2h/R)", "g'' = g(1 − d/R)", 'Centre: g = 0'])
                              Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('•  $r', maxLines: 1, style: tx(25, c: S.cardText, h: 1.25))),
                          ]),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Recap page', style: hd(46)),
                            const SizedBox(height: 10),
                            Text('Made from today’s steps. Opens at step 6.', style: tx(28, c: S.cardText)),
                            const Spacer(),
                            const BigButton('Open recap', icon: Icons.description_outlined, bg: Colors.white, fg: S.ink, height: 96, size: 30, shadow: false),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 32),
          Row(children: [
            _simpleTools(l, w: 170, h: 150, clear: false),
            const Spacer(),
            const BigButton('Next step: g with depth', icon: Icons.arrow_forward_rounded, bg: S.violet, height: 160, size: 42),
          ]),
        ]),
      ),
    );
  }
}

/// Lesson step 3 laid onto a board page, with the teacher's pen marks over it.
class _StepPage extends StatelessWidget {
  const _StepPage(this.l);
  final Lang l;
  @override
  Widget build(BuildContext context) => _fit(
    SizedBox(
      width: 2200, height: 1240,
      child: Stack(children: [
        Positioned(left: 0, top: 0, child: Tag('From lesson step 3 · you can write on it', icon: Icons.auto_stories_outlined, bg: S.soft, size: 30)),
        Positioned(left: 0, top: 110, child: Text('How g changes with height', style: hd(110))),
        Positioned(left: 0, top: 260, width: 1250, child: Text('Go higher, and g gets a little smaller. Near the surface we can use:', style: tx(52, c: S.body, h: 1.35))),
        Positioned(
          left: 0, top: 470,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 34),
            decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(40)),
            child: Text("g'  =  g × (1 − 2h ⁄ R)", style: tx(80, c: S.ink, w: FontWeight.w600, h: 1.2)),
          ),
        ),
        for (final (i, b) in ['On the ground: g = 9.8 m/s²', 'On Everest (8.8 km): g ≈ 9.77 m/s²'].indexed)
          Positioned(
            left: 0, top: 720.0 + i * 100,
            child: Row(children: [
              Container(width: 24, height: 24, decoration: const BoxDecoration(color: S.violet, shape: BoxShape.circle)),
              const SizedBox(width: 26),
              Text(b, style: tx(54, c: S.ink, h: 1.2)),
            ]),
          ),
        Positioned(left: 1500, top: 120, width: 640, height: 700, child: CustomPaint(painter: _MiniEarth())),
        // Teacher's ink.
        Positioned.fill(child: CustomPaint(painter: _StepInk())),
        Positioned(left: 1040, top: 960, child: Text('only 0.3 % less!', style: _hand(96, _red))),
        Positioned(left: 1180, top: 420, child: Text('h ≪ R', style: _hand(90, _green))),
      ]),
    ),
    pad: 60,
  );
}

class _StepInk extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(_wobLine(const Offset(10, 868), const Offset(1020, 862), amp: 3), _pen(_hiYellow, 64));
    canvas.drawPath(_wobRect(const Rect.fromLTWH(-20, 455, 1110, 190), seed: 2), _pen(_red, 7));
    final r = _pen(_red, 7);
    canvas.drawPath(_wobLine(const Offset(1030, 990), const Offset(940, 900), seed: 3), r);
    _arrowHead(canvas, const Offset(940, 900), const Offset(1030, 990), r);
  }

  @override
  bool shouldRepaint(_StepInk old) => false;
}

class _MiniEarth extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width * .5, s.height * .66);
    final r = s.width * .34;
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(colors: [Color(0xFF6FB6FF), Color(0xFF2457E6), Color(0xFF14307F)], stops: [0, .6, 1], center: Alignment(-.3, -.4)).createShader(Rect.fromCircle(center: c, radius: r)));
    final land = Paint()..color = const Color(0x8C3FBF7F);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(-r * .3, -r * .2), width: r * .7, height: r * .45), land);
    final ball = c + Offset(0, -r * 1.55);
    canvas.drawCircle(ball, r * .09, Paint()..color = const Color(0xFFFFB020));
    final a = Paint()..color = S.ink..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawLine(c + Offset(-r * .2, -r), c + Offset(-r * .2, -r * 1.55), a);
    final p = TextPainter(text: TextSpan(text: 'h', style: tx(56, c: S.ink, w: FontWeight.w700, h: 1)), textDirection: TextDirection.ltr)..layout();
    p.paint(canvas, c + Offset(-r * .2 - 60, -r * 1.35));
  }

  @override
  bool shouldRepaint(_MiniEarth old) => false;
}

// ───────────────────────────── 06 · insert menu ─────────────────────────────

class _InsertMenu extends StatelessWidget {
  const _InsertMenu(this.l);
  final Lang l;
  @override
  Widget build(BuildContext context) {
    const items = [
      (S.sky, Icons.image_outlined, 'Picture', 'From a pen drive or this board'),
      (S.peach, Icons.slideshow_rounded, 'PowerPoint slides', 'Each slide becomes a page'),
      (S.lavender, Icons.view_in_ar_rounded, '3D model', 'Earth, heart, atom, engine…'),
      (S.mint, Icons.science_outlined, 'Virtual lab', 'Do the experiment on the board'),
      (S.butter, Icons.play_circle_outline_rounded, 'Simulation', 'Move a slider, watch it change'),
      (S.pink, Icons.show_chart_rounded, 'Graph', 'Axes ready. Type y = 2x + 1'),
      (S.mist, Icons.note_add_outlined, 'Blank page', 'A fresh white page'),
      (S.mint, Icons.grid_on_rounded, 'Template', 'Lined, grid, graph, map, table'),
    ];
    return Material(
      type: MaterialType.transparency,
      child: Container(
      color: const Color(0x8C13165A),
      alignment: Alignment.center,
      child: Container(
        width: 2640,
        padding: const EdgeInsets.fromLTRB(60, 52, 60, 56),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(64), boxShadow: S.shadow),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Insert', style: tx(34, c: S.eyebrow, w: FontWeight.w600, h: 1.2)),
                const SizedBox(height: 8),
                Text('What do you want to put on the board?', style: hd(72)),
              ]),
            ),
            const HelpButton(size: 34),
            const SizedBox(width: 20),
            const _Pill('Close', Icons.close_rounded, h: 130, size: 38),
          ]),
          const SizedBox(height: 40),
          Wrap(spacing: 28, runSpacing: 28, children: [
            for (final (bg, ic, t, sub) in items)
              SizedBox(
                width: (2640 - 120 - 28 * 3) / 4,
                height: 420,
                child: PastelCard(bg: bg, icon: ic, title: t, sub: sub, titleSize: 50, iconSize: 110, pad: 40, subLines: 2),
              ),
          ]),
          const SizedBox(height: 32),
          SafeLine('All of these work without internet. You can Undo anything you put on.', size: 34),
        ]),
      ),
    ),
    );
  }
}

// ───────────────────────────── 07 · projector ─────────────────────────────

class _Projector extends StatelessWidget {
  const _Projector();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Stack(children: [
      Positioned.fill(child: _fit(const _Ink(Lang.en, bold: 1.4), pad: 110)),
      Positioned(right: 60, bottom: 44, child: Text('2 / 3', style: tx(34, c: const Color(0xFFB4B7C6), w: FontWeight.w600))),
    ]),
  );
}

// ───────────────────────────── 09 · tablet portrait ─────────────────────────────

class _Tablet extends StatelessWidget {
  const _Tablet(this.l);
  final Lang l;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: S.mist,
    body: Padding(
      padding: const EdgeInsets.fromLTRB(60, 60, 60, 60),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          BigButton(tr(l, 'Back to the lesson', 'ಪಾಠಕ್ಕೆ ಹಿಂತಿರುಗಿ'), icon: Icons.arrow_back_rounded, height: 110, size: 34),
          const Spacer(),
          HelpButton(lang: l, size: 30),
        ]),
        const SizedBox(height: 30),
        Text(tr(l, 'Gravitation · page 2 of 3', 'ಗುರುತ್ವಾಕರ್ಷಣೆ · ಪುಟ 2 / 3'), style: hd(56, l: l)),
        const SizedBox(height: 30),
        AspectRatio(aspectRatio: 1.45, child: _Sheet(child: _fit(_Ink(l), pad: 30))),
        const SizedBox(height: 36),
        FittedBox(alignment: Alignment.centerLeft, child: _Pages(l, vertical: false, thumbW: 300)),
        const Spacer(),
        LayoutBuilder(builder: (context, box) {
          const gap = 18.0;
          final w = (box.maxWidth - gap * 3) / 4;
          Widget b(String n, IconData ic, {Color? dot, Color bg = Colors.white, Color fg = S.ink, bool on = false}) =>
              ToolButton(n, ic, dot: dot, bg: bg, fg: fg, width: w, height: 170, on: on);
          return Wrap(spacing: gap, runSpacing: gap, children: [
            b(tr(l, 'Pen', 'ಪೆನ್'), Icons.circle, dot: _ink, bg: S.soft, on: true),
            b(tr(l, 'Blue', 'ನೀಲಿ'), Icons.circle, dot: _blue),
            b(tr(l, 'Red', 'ಕೆಂಪು'), Icons.circle, dot: _red),
            b(tr(l, 'Highlight', 'ಹೈಲೈಟ್'), Icons.border_color_rounded),
            b(tr(l, 'Eraser', 'ರಬ್ಬರ್'), Icons.auto_fix_normal_rounded),
            b(tr(l, 'Undo', 'ರದ್ದುಮಾಡು'), Icons.undo_rounded),
            b(tr(l, 'Insert', 'ಸೇರಿಸಿ'), Icons.add_photo_alternate_outlined),
            b(tr(l, 'Clear', 'ಅಳಿಸಿ'), Icons.delete_outline_rounded, bg: S.peach, fg: S.rust),
          ]);
        }),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 26),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40)),
          child: _showAll(l, on: false),
        ),
      ]),
    ),
  );
}
