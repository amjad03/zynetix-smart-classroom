import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The built-in scene icons, drawn with vector paths (no images): bulb, battery, resistor,
/// capacitor, switch, magnet, lens, mirror, cell, beaker. Each fits a box [size] wide centred
/// on [c], turned by [angle] degrees. [on] (0..1) lights a bulb, closes a switch, or fills a beaker.
const sceneIcons = ['bulb', 'battery', 'resistor', 'capacitor', 'switch', 'magnet', 'lens', 'mirror', 'cell', 'beaker'];

void paintSceneIcon(Canvas canvas, String icon, Offset c, double size, {double angle = 0, double on = 0, Color color = Colors.white, double opacity = 1}) {
  if (!size.isFinite || size <= 0) return;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(-angle * math.pi / 180);
  final u = size; // the icon is drawn in a 1 × 1 box scaled by u
  final ink = color.withValues(alpha: opacity);
  final stroke = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(3, u * 0.04)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final fill = Paint()..color = ink;
  Offset p(double x, double y) => Offset(x * u, -y * u);
  void line(double x1, double y1, double x2, double y2, [Paint? paint]) => canvas.drawLine(p(x1, y1), p(x2, y2), paint ?? stroke);
  final k = on.isFinite ? on.clamp(0.0, 1.0) : 0.0;
  switch (icon) {
    case 'bulb':
      if (k > 0) {
        canvas.drawCircle(p(0, 0.12), u * (0.3 + 0.25 * k), Paint()..shader = RadialGradient(colors: [const Color(0xFFFFF59D).withValues(alpha: 0.9 * k * opacity), const Color(0x00FFF59D)]).createShader(Rect.fromCircle(center: p(0, 0.12), radius: u * (0.3 + 0.25 * k))));
      }
      canvas.drawCircle(p(0, 0.12), u * 0.26, Paint()..color = Color.lerp(const Color(0x33FFFFFF), const Color(0xFFFFEE58), k)!.withValues(alpha: opacity));
      canvas.drawCircle(p(0, 0.12), u * 0.26, stroke);
      // Filament and base.
      canvas.drawPath(Path()..moveTo(p(-0.08, -0.1).dx, p(-0.08, -0.1).dy)..lineTo(p(-0.08, 0.1).dx, p(-0.08, 0.1).dy)..lineTo(p(0, 0.18).dx, p(0, 0.18).dy)..lineTo(p(0.08, 0.1).dx, p(0.08, 0.1).dy)..lineTo(p(0.08, -0.1).dx, p(0.08, -0.1).dy), stroke);
      canvas.drawRect(Rect.fromPoints(p(-0.12, -0.12), p(0.12, -0.32)), stroke);
      line(-0.12, -0.19, 0.12, -0.19);
      line(-0.12, -0.26, 0.12, -0.26);
    case 'cell' || 'battery':
      // Leads, then long (+) and short (−) plates; a battery is two cells.
      final cells = icon == 'battery' ? 2 : 1;
      final w = 0.12, gap = 0.1, total = cells * (gap + w) - w;
      line(-0.5, 0, -total / 2 - 0.01, 0);
      line(total / 2 + 0.01, 0, 0.5, 0);
      for (var i = 0; i < cells; i++) {
        final x = -total / 2 + i * (gap + w);
        line(x, 0.3, x, -0.3, stroke..strokeWidth = math.max(3, u * 0.04));
        line(x + gap, 0.15, x + gap, -0.15, Paint()
          ..color = ink
          ..strokeWidth = math.max(5, u * 0.08));
      }
      _text(canvas, '+', p(-total / 2 - 0.08, 0.32), u * 0.18, ink);
      _text(canvas, '−', p(total / 2 + 0.08, 0.32), u * 0.18, ink);
    case 'resistor':
      final path = Path()..moveTo(p(-0.5, 0).dx, 0);
      path.lineTo(p(-0.3, 0).dx, 0);
      for (var i = 0; i < 6; i++) {
        final x = -0.3 + (i + 0.5) * 0.1;
        path.lineTo(p(x, 0).dx, p(0, i.isEven ? 0.12 : -0.12).dy);
      }
      path.lineTo(p(0.3, 0).dx, 0);
      path.lineTo(p(0.5, 0).dx, 0);
      canvas.drawPath(path, stroke);
    case 'capacitor':
      line(-0.5, 0, -0.06, 0);
      line(0.06, 0, 0.5, 0);
      line(-0.06, 0.25, -0.06, -0.25, Paint()
        ..color = ink
        ..strokeWidth = math.max(5, u * 0.06));
      line(0.06, 0.25, 0.06, -0.25, Paint()
        ..color = ink
        ..strokeWidth = math.max(5, u * 0.06));
    case 'switch':
      line(-0.5, 0, -0.25, 0);
      line(0.25, 0, 0.5, 0);
      canvas.drawCircle(p(-0.25, 0), u * 0.04, fill);
      canvas.drawCircle(p(0.25, 0), u * 0.04, fill);
      final a = (1 - k) * 0.55; // open: the lever is lifted
      line(-0.25, 0, -0.25 + 0.5 * math.cos(a), 0.5 * math.sin(a));
    case 'magnet':
      canvas.drawRect(Rect.fromPoints(p(-0.5, 0.15), p(0, -0.15)), Paint()..color = const Color(0xFFE53935).withValues(alpha: opacity));
      canvas.drawRect(Rect.fromPoints(p(0, 0.15), p(0.5, -0.15)), Paint()..color = const Color(0xFF1E88E5).withValues(alpha: opacity));
      canvas.drawRect(Rect.fromPoints(p(-0.5, 0.15), p(0.5, -0.15)), stroke);
      _text(canvas, 'N', p(-0.25, 0), u * 0.2, Colors.white.withValues(alpha: opacity));
      _text(canvas, 'S', p(0.25, 0), u * 0.2, Colors.white.withValues(alpha: opacity));
    case 'lens':
      // A biconvex lens [size] tall: two arcs meeting at the top and bottom.
      final h = 0.5, w = 0.09;
      final path = Path()
        ..moveTo(p(0, h).dx, p(0, h).dy)
        ..quadraticBezierTo(p(w * 2, 0).dx, p(w * 2, 0).dy, p(0, -h).dx, p(0, -h).dy)
        ..quadraticBezierTo(p(-w * 2, 0).dx, p(-w * 2, 0).dy, p(0, h).dx, p(0, h).dy);
      canvas.drawPath(path, Paint()..color = const Color(0xFF80DEEA).withValues(alpha: 0.35 * opacity));
      canvas.drawPath(path, stroke);
    case 'mirror':
      // A concave mirror [size] tall, silvered side to the left, hatched behind.
      final path = Path()
        ..moveTo(p(0.06, 0.5).dx, p(0.06, 0.5).dy)
        ..quadraticBezierTo(p(-0.06, 0).dx, p(-0.06, 0).dy, p(0.06, -0.5).dx, p(0.06, -0.5).dy);
      canvas.drawPath(path, stroke..strokeWidth = math.max(4, u * 0.05));
      for (var i = 0; i <= 8; i++) {
        final y = -0.45 + i * 0.1125;
        final x = 0.06 * (y / 0.5) * (y / 0.5);
        line(x + 0.03, y, x + 0.12, y - 0.07, Paint()
          ..color = ink.withValues(alpha: 0.6 * opacity)
          ..strokeWidth = 2);
      }
    case 'beaker':
      final level = -0.4 + 0.75 * k;
      if (k > 0) canvas.drawRect(Rect.fromPoints(p(-0.32, level), p(0.32, -0.42)), Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: 0.55 * opacity));
      canvas.drawPath(
        Path()
          ..moveTo(p(-0.4, 0.45).dx, p(-0.4, 0.45).dy)
          ..lineTo(p(-0.34, 0.4).dx, p(-0.34, 0.4).dy)
          ..lineTo(p(-0.34, -0.45).dx, p(-0.34, -0.45).dy)
          ..lineTo(p(0.34, -0.45).dx, p(0.34, -0.45).dy)
          ..lineTo(p(0.34, 0.45).dx, p(0.34, 0.45).dy),
        stroke,
      );
      for (var i = 1; i <= 3; i++) {
        line(0.2, -0.45 + i * 0.2, 0.34, -0.45 + i * 0.2, Paint()
          ..color = ink.withValues(alpha: 0.7 * opacity)
          ..strokeWidth = 2);
      }
  }
  canvas.restore();
}

void _text(Canvas canvas, String s, Offset at, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontSize: math.max(12, size), color: color, fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
}
