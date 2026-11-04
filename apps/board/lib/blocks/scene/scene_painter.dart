import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/expr.dart';
import '../../engine/model.dart';
import '../whiteboard_view.dart' show inkColor, paintAxes;
import 'icons.dart';
import 'play_model.dart';

/// Where a scene's world (x right, y up) sits on screen: the plot box inside [size], with room
/// for axis labels when there are axes, and equal scales on both axes when [equal].
class SceneFrame {
  SceneFrame(Size size, this.view, {bool axes = false, bool equal = false}) {
    final pad = axes ? const EdgeInsets.fromLTRB(64, 16, 24, 48) : const EdgeInsets.all(12);
    var box = pad.deflateRect(Offset.zero & size);
    if (box.width < 10 || box.height < 10) box = Offset.zero & size;
    final (x0, x1, y0, y1) = view;
    if (equal) {
      final k = math.min(box.width / (x1 - x0), box.height / (y1 - y0));
      box = Rect.fromCenter(center: box.center, width: k * (x1 - x0), height: k * (y1 - y0));
    }
    rect = box;
  }
  final (double, double, double, double) view;
  late final Rect rect;

  double get sx => rect.width / (view.$2 - view.$1);
  double get sy => rect.height / (view.$4 - view.$3);
  Offset toScreen(double x, double y) => Offset(rect.left + (x - view.$1) * sx, rect.bottom - (y - view.$3) * sy);
  (double, double) toWorld(Offset o) => (view.$1 + (o.dx - rect.left) / sx, view.$3 + (rect.bottom - o.dy) / sy);
}

/// Text with `{expr}` or `{expr:2}` values filled in.
final _interp = RegExp(r'\{([^{}:]+)(?::(\d))?\}');

String formatValue(double v, [int? digits]) {
  if (!v.isFinite) return '—';
  if (digits != null) return v.toStringAsFixed(digits);
  if ((v - v.roundToDouble()).abs() < 1e-9) return v.round().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// One shape of a scene, compiled once: every numeric field an expression of the env.
class SceneShape {
  SceneShape(this.raw, this.index, List<String> names) : type = raw['shape'] as String? ?? '' {
    final own = type == 'particles' ? [...names, 'i'] : names;
    Expr ex(Object? v, [List<String> extra = const []]) {
      if (v is num) {
        final d = v.toDouble();
        return (_) => d;
      }
      if (v is String) return tryCompileExpr(v, [...own, ...extra]) ?? (_) => double.nan;
      return (_) => double.nan;
    }

    for (final k in const ['x', 'y', 'r', 'w', 'h', 'x1', 'y1', 'x2', 'y2', 'dx', 'dy', 'from', 'to', 'width', 'size', 'amp', 'angle', 'on', 'opacity']) {
      if (raw.containsKey(k)) f[k] = ex(raw[k]);
    }
    if (raw['visibleIf'] is String) visibleIf = tryCompileExpr(raw['visibleIf'] as String, own);
    final c = raw['color'];
    if (c is Map) {
      colorBy = ex(c['by']);
      scale = [for (final s in (c['scale'] as List?) ?? const []) inkColor(s)];
    } else {
      color = inkColor(c ?? 'white');
    }
    if (raw['fn'] is String) fn = tryCompileExpr(raw['fn'] as String, [...own, 'x']);
    points = [
      for (final p in (raw['points'] as List?) ?? const [])
        if (p is List && p.length == 2) (ex(p[0]), ex(p[1])),
    ];
    final text = raw['text'];
    if (text != null) this.text = L10n.of(text);
    for (final m in _interp.allMatches('${this.text?.en ?? ''} ${this.text?.kn ?? ''}')) {
      texts[m.group(1)!.trim()] = ex(m.group(1)!.trim());
    }
  }

  final Map<String, dynamic> raw;
  final int index;
  final String type;
  final f = <String, Expr>{};
  Expr? visibleIf, colorBy, fn;
  Color color = Colors.white;
  List<Color> scale = const [];
  List<(Expr, Expr)> points = const [];
  L10n? text;
  final texts = <String, Expr>{};

  double v(String k, Vars env, double d) {
    final e = f[k];
    if (e == null) return d;
    return e(env);
  }

  bool visible(Vars env) {
    final g = visibleIf;
    if (g == null) return true;
    final x = g(env);
    return x != 0 && !x.isNaN;
  }

  Color colorAt(Vars env) {
    final by = colorBy;
    Color c;
    if (by == null || scale.length < 2) {
      c = scale.isNotEmpty ? scale.first : color;
    } else {
      final k = by(env);
      final z = (k.isFinite ? k : 0.0).clamp(0.0, 1.0) * (scale.length - 1);
      final i = math.min(z.floor(), scale.length - 2);
      c = Color.lerp(scale[i], scale[i + 1], z - i)!;
    }
    final o = v('opacity', env, 1);
    return c.withValues(alpha: (o.isFinite ? o : 1.0).clamp(0.0, 1.0));
  }

  String textAt(Vars env, Lang lang) => (text?.t(lang) ?? '').replaceAllMapped(_interp, (m) {
    final e = texts[m.group(1)!.trim()];
    return formatValue(e?.call(env) ?? double.nan, m.group(2) == null ? null : int.parse(m.group(2)!));
  });
}

/// Compiles a scene's shapes (bad ones are skipped, never fatal).
List<SceneShape> compileShapes(Object? raw, List<String> names) => [
  for (final (i, s) in ((raw as List?) ?? const []).indexed)
    if (s is Map) SceneShape(s.cast<String, dynamic>(), i, names),
];

/// Paints a scene: chalkboard, optional grid and axes, the shapes back to front, then handles.
class ScenePainter extends CustomPainter {
  ScenePainter({required this.runtime, required this.shapes, required this.lang, this.selectedHandle}) : super(repaint: runtime);
  final PlayRuntime runtime;
  final List<SceneShape> shapes;
  final Lang lang;
  final String? selectedHandle;

  @override
  void paint(Canvas canvas, Size size) {
    final rt = runtime;
    final viewRaw = (rt.model.raw['view'] as Map?)?.cast<String, dynamic>() ?? const {};
    final frame = SceneFrame(size, rt.model.view, axes: viewRaw['axes'] == true, equal: viewRaw['equal'] == true);
    paintSceneFrame(canvas, frame, viewRaw);
    canvas.save();
    canvas.clipRect(frame.rect.inflate(4));
    paintShapes(canvas, frame, shapes, rt.env, lang, trails: rt.trails);
    canvas.restore();
    for (final h in rt.model.handles) {
      final x = rt.controls[h.xName] ?? h.x, y = rt.controls[h.yName] ?? h.y;
      paintHandle(canvas, frame.toScreen(x, y), h.label, inkColor(h.color ?? 'yellow'), active: h.name == selectedHandle);
    }
  }

  @override
  bool shouldRepaint(ScenePainter old) => true;
}

/// Grid and axes of a view (as `view` in the schema).
void paintSceneFrame(Canvas canvas, SceneFrame frame, Map<String, dynamic> viewRaw) {
  final (x0, x1, y0, y1) = frame.view;
  if (viewRaw['axes'] == true || viewRaw['grid'] == true) {
    if (viewRaw['axes'] == true) {
      paintAxes(canvas, frame.rect, [x0, x1], [y0, y1], const Color(0xFF4A5459), strokeWidth: 3, font: 26, xLabel: viewRaw['xLabel'] as String?, yLabel: viewRaw['yLabel'] as String?, grid: viewRaw['grid'] == true, gridColor: const Color(0xFF20282C), labelColor: const Color(0xFF8E979C));
    } else {
      // Grid alone: faint lines at whole units (or a nicer step).
      final g = Paint()
        ..color = const Color(0xFF20282C)
        ..strokeWidth = 2;
      final step = _niceStep(x1 - x0);
      for (var x = (x0 / step).ceil() * step; x <= x1; x += step) {
        canvas.drawLine(frame.toScreen(x, y0), frame.toScreen(x, y1), g);
      }
      final stepY = _niceStep(y1 - y0);
      for (var y = (y0 / stepY).ceil() * stepY; y <= y1; y += stepY) {
        canvas.drawLine(frame.toScreen(x0, y), frame.toScreen(x1, y), g);
      }
    }
  }
}

double _niceStep(double span) {
  if (span <= 0 || !span.isFinite) return 1;
  final raw = span / 10, mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / mag;
  return (f < 1.5 ? 1 : (f < 3.5 ? 2 : (f < 7.5 ? 5 : 10))) * mag;
}

/// A draggable point: a big ring with a dot (and its label), easy to grab on a board or phone.
void paintHandle(Canvas canvas, Offset at, String? label, Color color, {bool active = false}) {
  canvas.drawCircle(at, active ? 34 : 28, Paint()..color = color.withValues(alpha: 0.25));
  canvas.drawCircle(
    at,
    active ? 34 : 28,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );
  canvas.drawCircle(at, 9, Paint()..color = color);
  if (label != null) _text(canvas, label, at + const Offset(0, -52), 26, color);
}

void _text(Canvas canvas, String s, Offset at, double size, Color color, {TextAlign align = TextAlign.center, bool pill = false}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: zText(size, FontWeight.w500).copyWith(color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (align) {
    TextAlign.left => 0.0,
    TextAlign.right => tp.width,
    _ => tp.width / 2,
  };
  final o = at - Offset(dx, tp.height / 2);
  if (pill) {
    final r = RRect.fromRectAndRadius(Rect.fromLTRB(o.dx - 20, o.dy - 10, o.dx + tp.width + 20, o.dy + tp.height + 10), Radius.circular(tp.height / 2 + 10));
    canvas.drawRRect(r, Paint()..color = const Color(0xFF232C30));
  }
  tp.paint(canvas, o);
}

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

bool _ok(double v) => v.isFinite;

void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
  final d = (b - a).distance;
  if (d < 1) return;
  final dir = (b - a) / d;
  for (var s = 0.0; s < d; s += 26) {
    canvas.drawLine(a + dir * s, a + dir * math.min(s + 14, d), p);
  }
}

/// Paints [shapes] with the values in [env]. Shapes that cannot be computed are skipped.
void paintShapes(Canvas canvas, SceneFrame frame, List<SceneShape> shapes, Vars env, Lang lang, {List<TrailSource> trails = const []}) {
  var trailIndex = 0;
  for (final s in shapes) {
    if (s.type == 'trail') {
      final tr = trailIndex < trails.length ? trails[trailIndex] : null;
      trailIndex++;
      if (tr == null || !s.visible(env) || tr.points.length < 2) continue;
      final c = s.colorAt(env), w = s.v('width', env, 4);
      final n = tr.points.length;
      for (var k = 1; k < n; k++) {
        final a = tr.points[k - 1], b = tr.points[k];
        canvas.drawLine(frame.toScreen(a.$1, a.$2), frame.toScreen(b.$1, b.$2), _stroke(c.withValues(alpha: c.a * (0.2 + 0.8 * k / n)), _ok(w) ? w : 4));
      }
      continue;
    }
    if (s.type == 'particles') {
      final count = ((s.raw['count'] as num?)?.toInt() ?? 0).clamp(0, 400);
      final e = Map.of(env);
      for (var i = 0; i < count; i++) {
        e['i'] = i.toDouble();
        if (!s.visible(e)) continue;
        final x = s.v('x', e, double.nan), y = s.v('y', e, double.nan), r = s.v('r', e, 0.1);
        if (!_ok(x) || !_ok(y) || !_ok(r)) continue;
        canvas.drawCircle(frame.toScreen(x, y), math.max(2, r * frame.sx), Paint()..color = s.colorAt(e));
      }
      continue;
    }
    if (!s.visible(env)) continue;
    final c = s.colorAt(env);
    final w = s.v('width', env, s.type == 'wave' ? 5 : 4);
    final width = _ok(w) ? w.clamp(0.5, 40.0) : 4.0;
    switch (s.type) {
      case 'circle':
        final x = s.v('x', env, double.nan), y = s.v('y', env, double.nan), r = s.v('r', env, double.nan);
        if (!_ok(x) || !_ok(y) || !_ok(r)) continue;
        final rad = (r * frame.sx).abs();
        canvas.drawCircle(frame.toScreen(x, y), rad, s.raw['fill'] == false ? _stroke(c, width) : (Paint()..color = c));
      case 'rect':
        final x = s.v('x', env, double.nan), y = s.v('y', env, double.nan), rw = s.v('w', env, double.nan), rh = s.v('h', env, double.nan);
        if (![x, y, rw, rh].every(_ok)) continue;
        final r = Rect.fromPoints(frame.toScreen(x, y), frame.toScreen(x + rw, y + rh));
        canvas.drawRect(r, s.raw['fill'] == false ? _stroke(c, width) : (Paint()..color = c));
      case 'line':
        final a = frame.toScreen(s.v('x1', env, double.nan), s.v('y1', env, double.nan)), b = frame.toScreen(s.v('x2', env, double.nan), s.v('y2', env, double.nan));
        if (![a.dx, a.dy, b.dx, b.dy].every(_ok)) continue;
        s.raw['dashed'] == true ? _dashed(canvas, a, b, _stroke(c, width)) : canvas.drawLine(a, b, _stroke(c, width));
      case 'arrow':
        final x = s.v('x', env, double.nan), y = s.v('y', env, double.nan), dx = s.v('dx', env, double.nan), dy = s.v('dy', env, double.nan);
        if (![x, y, dx, dy].every(_ok)) continue;
        final a = frame.toScreen(x, y), b = frame.toScreen(x + dx, y + dy);
        final d = (b - a).distance;
        if (d < 2) continue;
        final dir = (b - a) / d, n = Offset(-dir.dy, dir.dx), head = math.min(28.0, d * 0.5);
        canvas.drawLine(a, b - dir * head * 0.6, _stroke(c, math.max(width, 5)));
        canvas.drawPath(Path()..addPolygon([b, b - dir * head + n * head * 0.55, b - dir * head - n * head * 0.55], true), Paint()..color = c);
        final label = s.raw['label'] as String?;
        if (label != null) _text(canvas, label, b + dir * 22 + n * 22, 26, c);
      case 'path' || 'wave':
        final path = Path();
        final fn = s.fn;
        if (fn != null) {
          final from = s.v('from', env, frame.view.$1), to = s.v('to', env, frame.view.$2);
          if (!_ok(from) || !_ok(to)) continue;
          final n = s.type == 'wave' ? 240 : 160;
          final e = Map.of(env);
          var pen = false;
          for (var k = 0; k <= n; k++) {
            final x = from + (to - from) * k / n;
            e['x'] = x;
            final y = fn(e);
            if (!_ok(y) || y.abs() > 1e6) {
              pen = false;
              continue;
            }
            final o = frame.toScreen(x, y);
            pen ? path.lineTo(o.dx, o.dy) : path.moveTo(o.dx, o.dy);
            pen = true;
          }
        } else {
          final ps = [for (final (px, py) in s.points) frame.toScreen(px(env), py(env))];
          if (ps.length < 2 || !ps.every((o) => _ok(o.dx) && _ok(o.dy))) continue;
          path.addPolygon(ps, s.raw['closed'] == true);
        }
        if (s.raw['dashed'] == true) {
          for (final m in path.computeMetrics()) {
            for (var d = 0.0; d < m.length; d += 26) {
              canvas.drawPath(m.extractPath(d, math.min(d + 14, m.length)), _stroke(c, width));
            }
          }
        } else {
          canvas.drawPath(path, _stroke(c, width));
        }
      case 'polygon':
        final ps = [for (final (px, py) in s.points) frame.toScreen(px(env), py(env))];
        if (ps.length < 3 || !ps.every((o) => _ok(o.dx) && _ok(o.dy))) continue;
        final path = Path()..addPolygon(ps, true);
        if (s.raw['fill'] != false) canvas.drawPath(path, Paint()..color = c.withValues(alpha: c.a * 0.45));
        canvas.drawPath(path, _stroke(c, width));
      case 'text' || 'label':
        final x = s.v('x', env, double.nan), y = s.v('y', env, double.nan), size = s.v('size', env, 30);
        if (!_ok(x) || !_ok(y)) continue;
        final align = switch (s.raw['align']) {
          'left' => TextAlign.left,
          'right' => TextAlign.right,
          _ => TextAlign.center,
        };
        _text(canvas, s.textAt(env, lang), frame.toScreen(x, y), _ok(size) ? size.clamp(12.0, 120.0) : 30, c, align: align, pill: s.type == 'label');
      case 'spring':
        final a = frame.toScreen(s.v('x1', env, double.nan), s.v('y1', env, double.nan)), b = frame.toScreen(s.v('x2', env, double.nan), s.v('y2', env, double.nan));
        if (![a.dx, a.dy, b.dx, b.dy].every(_ok)) continue;
        final d = (b - a).distance;
        if (d < 2) continue;
        final dir = (b - a) / d, n = Offset(-dir.dy, dir.dx);
        final coils = ((s.raw['coils'] as num?)?.toInt() ?? 10).clamp(2, 40);
        final amp = s.v('amp', env, 14);
        final lead = d * 0.08;
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo((a + dir * lead).dx, (a + dir * lead).dy);
        final body = d - 2 * lead;
        for (var k = 0; k < coils * 2; k++) {
          final o = a + dir * (lead + body * (k + 0.5) / (coils * 2)) + n * (k.isEven ? amp : -amp);
          path.lineTo(o.dx, o.dy);
        }
        path
          ..lineTo((b - dir * lead).dx, (b - dir * lead).dy)
          ..lineTo(b.dx, b.dy);
        canvas.drawPath(path, _stroke(c, width));
      case 'icon':
        final x = s.v('x', env, double.nan), y = s.v('y', env, double.nan), size = s.v('size', env, 1);
        if (!_ok(x) || !_ok(y) || !_ok(size)) continue;
        paintSceneIcon(canvas, s.raw['icon'] as String? ?? '', frame.toScreen(x, y), size * frame.sx, angle: s.v('angle', env, 0), on: s.v('on', env, 0), color: c.withValues(alpha: 1), opacity: c.a);
    }
  }
}

/// A still diagram (activities): the view's frame and constant shapes.
class DiagramPainter extends CustomPainter {
  DiagramPainter({required this.view, required this.viewRaw, required this.shapes, required this.lang});
  final (double, double, double, double) view;
  final Map<String, dynamic> viewRaw;
  final List<SceneShape> shapes;
  final Lang lang;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = SceneFrame(size, view, axes: viewRaw['axes'] == true, equal: viewRaw['equal'] == true);
    paintSceneFrame(canvas, frame, viewRaw);
    paintShapes(canvas, frame, shapes, const {}, lang);
  }

  @override
  bool shouldRepaint(DiagramPainter old) => old.shapes != shapes || old.lang != lang;
}
