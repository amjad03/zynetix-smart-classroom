import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/expr.dart';
import '../engine/lesson_controller.dart';
import '../engine/model.dart';

/// Board ink names (schema `ink`) on the chalkboard.
const boardInk = <String, Color>{
  'white': Color(0xFFF4F4EC),
  'yellow': Color(0xFFFFE45C),
  'red': Color(0xFFFF7A70),
  'green': Color(0xFF8BE88F),
  'blue': Color(0xFF7CC4FF),
  'orange': Color(0xFFFFB25C),
};
Color inkColor(Object? name) => boardInk[name] ?? boardInk['white']!;

const chalkboardColor = Color(0xFF1C2B26);

/// A whiteboard block: a dark chalkboard where steps appear one at a time, each drawn with a
/// short animation (strokes drawn progressively, text fading in). Teacher Mode: "Next step"
/// (and each step's line is read aloud once the teacher has turned Read aloud on). Self-Learning
/// ([auto]): each step's line is read, then the next step comes (about 6 s for a silent step).
class WhiteboardView extends StatefulWidget {
  const WhiteboardView({super.key, required this.c, required this.block, this.auto = false});
  final LessonController c;
  final Block block;
  final bool auto;
  @override
  State<WhiteboardView> createState() => WhiteboardViewState();
}

class WhiteboardViewState extends State<WhiteboardView> with SingleTickerProviderStateMixin {
  late final List<BoardStep> steps = widget.block.boardSteps;
  late final AnimationController _draw = AnimationController(vsync: this, duration: _drawTime(0))..forward();
  int shown = 0;
  int _run = 0;

  bool get atEnd => shown >= steps.length - 1;

  static const silentStep = Duration(seconds: 6), afterLine = Duration(seconds: 3);

  Duration _drawTime(int i) => Duration(milliseconds: (350 * (i < steps.length ? steps[i].draw.length : 1)).clamp(700, 2400));

  @override
  void initState() {
    super.initState();
    widget.c.stepLine = steps.isEmpty ? null : steps[0].say;
    if (widget.auto) {
      unawaited(_autoRun());
    } else if (widget.c.readAloudOn) {
      _sayStep();
    }
  }

  @override
  void dispose() {
    _run++;
    _draw.dispose();
    super.dispose();
  }

  void _sayStep() {
    final say = steps[shown].say;
    if (say != null) unawaited(widget.c.speak(say));
  }

  /// Shows the next step (Teacher Mode's "Next step").
  void nextStep() {
    if (atEnd) return;
    setState(() => shown++);
    widget.c.stepLine = steps[shown].say;
    _draw
      ..duration = _drawTime(shown)
      ..forward(from: 0);
    if (!widget.auto && widget.c.readAloudOn) _sayStep();
  }

  Future<void> _wait(Duration d) => Future<void>.delayed(d);

  Future<void> _autoRun() async {
    final run = ++_run;
    bool live() => mounted && run == _run;
    while (live()) {
      final say = steps[shown].say;
      if (say != null) {
        await widget.c.speak(say);
        if (!live()) return;
        await _wait(afterLine);
      } else {
        await _wait(silentStep);
      }
      while (live() && widget.c.paused) {
        await _wait(const Duration(milliseconds: 500));
      }
      if (!live() || atEnd) return;
      nextStep();
    }
  }

  /// Items on the board now: from the last step that cleared it, to the step shown.
  List<(Map<String, dynamic>, int)> get _visible {
    var from = 0;
    for (var i = 0; i <= shown; i++) {
      if (steps[i].clear) from = i;
    }
    return [for (var i = from; i <= shown; i++) for (final d in steps[i].draw) (d, i)];
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.c.lang, text = Theme.of(context).textTheme;
    if (steps.isEmpty) return const SizedBox.shrink();
    final say = steps[shown].say;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 100 / 60,
            child: Container(
              key: const ValueKey('chalkboard'),
              decoration: BoxDecoration(
                color: chalkboardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF6D4C2F), width: 12),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AnimatedBuilder(animation: _draw, builder: (context, _) => _Board(items: _visible, current: shown, t: _draw.value, lang: l)),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: Z.gap),
      SizedBox(
        width: 380,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.draw_outlined, size: 48, color: Z.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.block.title?.t(l) ?? tr('whiteboard', l), style: text.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          Text('${tr('step', l)} ${shown + 1} / ${steps.length}', key: const ValueKey('wbStep'), style: text.bodyLarge?.copyWith(color: Z.accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(say?.t(l) ?? '', key: ValueKey(shown), style: text.bodyLarge),
              ),
            ),
          ),
          if (!widget.auto) ...[
            const SizedBox(height: 12),
            BigButton(key: const ValueKey('wbNext'), icon: Icons.skip_next, label: tr('nextStep', l), onPressed: atEnd ? null : nextStep),
          ],
        ]),
      ),
    ]);
  }
}

/// The board's contents at one moment: everything before the current step fully drawn, the
/// current step drawn up to [t] (its items one after another).
class _Board extends StatelessWidget {
  const _Board({required this.items, required this.current, required this.t, required this.lang});
  final List<(Map<String, dynamic>, int)> items;
  final int current;
  final double t;
  final Lang lang;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final u = box.maxWidth / 100; // pixels per grid unit
        final n = items.where((e) => e.$2 == current).length;
        var k = 0;
        final progress = <double>[
          for (final e in items)
            if (e.$2 != current) 1 else ((t * n) - k++).clamp(0.0, 1.0),
        ];
        final widgets = <Widget>[];
        for (final (i, e) in items.indexed) {
          final d = e.$1, p = progress[i];
          if (d['kind'] != 'text' && d['kind'] != 'math') continue;
          final at = _pt(d['at']);
          final size = ((d['size'] as num?) ?? 3).toDouble() * u * 1.15;
          final style = zText(size).copyWith(color: inkColor(d['color']), height: 1.15);
          final child = d['kind'] == 'text'
              ? Text(L10n.of(d['text']).t(lang), style: style)
              : Math.tex(d['tex'] as String? ?? '', textStyle: style, onErrorFallback: (_) => Text(d['tex'] as String? ?? '', style: style));
          widgets.add(Positioned(
            left: at.dx * u,
            top: at.dy * u,
            child: Opacity(opacity: p, child: Transform.translate(offset: Offset(0, (1 - p) * 8), child: child)),
          ));
        }
        return Stack(children: [
          Positioned.fill(child: CustomPaint(painter: BoardPainter(items: [for (final e in items) e.$1], progress: progress))),
          ...widgets,
        ]);
      });
}

Offset _pt(Object? v) => v is List && v.length == 2 ? Offset((v[0] as num).toDouble(), (v[1] as num).toDouble()) : Offset.zero;

/// Paints the stroke items of a whiteboard (lines, arrows, shapes, axes and plots) in grid
/// units, each drawn up to its progress (0…1). Text and maths are widgets on top.
class BoardPainter extends CustomPainter {
  BoardPainter({required this.items, required this.progress});
  final List<Map<String, dynamic>> items;
  final List<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;
    Offset p(Object? v) => _pt(v) * u;
    Map<String, dynamic>? axes; // the latest axes: plots are drawn in its box
    for (final (i, d) in items.indexed) {
      final t = progress[i];
      if (d['kind'] == 'axes') axes = d;
      if (t <= 0) continue;
      final color = inkColor(d['color']);
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3, u * 0.32)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      switch (d['kind']) {
        case 'line' || 'arrow':
          final a = p(d['from']), b = p(d['to']);
          final path = Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy);
          _drawPartial(canvas, path, t, stroke, dashed: d['dashed'] == true, u: u);
          if (d['kind'] == 'arrow' && t >= 1) _arrowHead(canvas, a, b, stroke, u);
        case 'rect':
          final r = Rect.fromPoints(p(d['from']), p(d['to']));
          if (d['fill'] == true) canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.35 * t));
          _drawPartial(canvas, Path()..addRect(r), t, stroke);
        case 'circle':
          final r = Rect.fromCircle(center: p(d['at']), radius: ((d['r'] as num?) ?? 5).toDouble() * u);
          if (d['fill'] == true) canvas.drawOval(r, Paint()..color = color.withValues(alpha: 0.35 * t));
          _drawPartial(canvas, Path()..addOval(r), t, stroke);
        case 'path':
          final pts = [for (final q in (d['points'] as List?) ?? const []) p(q)];
          if (pts.length < 2) break;
          final path = Path()..addPolygon(pts, d['closed'] == true);
          _drawPartial(canvas, path, t, stroke);
        case 'axes':
          _axes(canvas, d, t, stroke, u);
        case 'plot':
          if (axes != null) _plot(canvas, axes, d, t, stroke, u);
      }
    }
  }

  static void _drawPartial(Canvas canvas, Path path, double t, Paint paint, {bool dashed = false, double u = 10}) {
    for (final m in path.computeMetrics()) {
      final len = m.length * t;
      if (!dashed) {
        canvas.drawPath(m.extractPath(0, len), paint);
        continue;
      }
      final dash = u * 1.6, gap = u * 1.1;
      for (var s = 0.0; s < len; s += dash + gap) {
        canvas.drawPath(m.extractPath(s, math.min(s + dash, len)), paint);
      }
    }
  }

  static void _arrowHead(Canvas canvas, Offset a, Offset b, Paint paint, double u) {
    final dir = b - a;
    if (dir.distance == 0) return;
    final ang = math.atan2(dir.dy, dir.dx), len = u * 2.2;
    final head = Path()
      ..moveTo(b.dx - len * math.cos(ang - 0.45), b.dy - len * math.sin(ang - 0.45))
      ..lineTo(b.dx, b.dy)
      ..lineTo(b.dx - len * math.cos(ang + 0.45), b.dy - len * math.sin(ang + 0.45));
    canvas.drawPath(head, paint);
  }

  static List<double> _range(Object? v, List<double> fallback) =>
      v is List && v.length == 2 ? [(v[0] as num).toDouble(), (v[1] as num).toDouble()] : fallback;

  void _axes(Canvas canvas, Map<String, dynamic> d, double t, Paint stroke, double u) {
    final box = Rect.fromPoints(_pt(d['from']) * u, _pt(d['to']) * u);
    final xr = _range(d['x'], [-5, 5]), yr = _range(d['y'], [-5, 5]);
    paintAxes(canvas, box, xr, yr, stroke.color, t: t, strokeWidth: math.max(2.5, u * 0.22), font: u * 2.1, xLabel: d['xLabel'] as String?, yLabel: d['yLabel'] as String?);
  }

  void _plot(Canvas canvas, Map<String, dynamic> axes, Map<String, dynamic> d, double t, Paint stroke, double u) {
    final f = tryCompileExpr(d['fn'] as String? ?? '', const ['x']);
    if (f == null) return;
    final box = Rect.fromPoints(_pt(axes['from']) * u, _pt(axes['to']) * u);
    paintFunction(canvas, box, _range(axes['x'], [-5, 5]), _range(axes['y'], [-5, 5]), (x) => f({'x': x}), stroke, t: t);
  }

  @override
  bool shouldRepaint(BoardPainter old) => true;
}

/// A "nice" tick step (1, 2 or 5 × 10ⁿ) giving about [target] ticks over [span].
double niceStep(double span, [int target = 8]) {
  if (span <= 0 || !span.isFinite) return 1;
  final raw = span / target, mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / mag;
  return (f < 1.5 ? 1 : f < 3.5 ? 2 : f < 7.5 ? 5 : 10) * mag;
}

String tickLabel(double v) {
  if ((v - v.roundToDouble()).abs() < 1e-9) return v.round().toString();
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

void _label(Canvas canvas, String s, Offset at, double size, Color color, {Alignment align = Alignment.center}) {
  final tp = TextPainter(text: TextSpan(text: s, style: zText(size).copyWith(color: color)), textDirection: TextDirection.ltr)..layout();
  final off = at - Offset(tp.width * (align.x + 1) / 2, tp.height * (align.y + 1) / 2);
  tp.paint(canvas, off);
}

/// Axes in [box] for ranges [xr] × [yr]: the axis lines (at 0 when in range, else at the
/// box edge), ticks with labels, and the axis names. Shared by whiteboards and interactives.
void paintAxes(Canvas canvas, Rect box, List<double> xr, List<double> yr, Color color,
    {double t = 1, double strokeWidth = 3, double font = 22, String? xLabel, String? yLabel, bool grid = false}) {
  Offset map(double x, double y) => Offset(box.left + (x - xr[0]) / (xr[1] - xr[0]) * box.width, box.bottom - (y - yr[0]) / (yr[1] - yr[0]) * box.height);
  final double x0 = (0.0).clamp(math.min(xr[0], xr[1]), math.max(xr[0], xr[1])), y0 = (0.0).clamp(math.min(yr[0], yr[1]), math.max(yr[0], yr[1]));
  final paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round;
  final xs = map(xr[0], y0), xe = map(xr[1], y0), ys = map(x0, yr[0]), ye = map(x0, yr[1]);
  final sx = niceStep(xr[1] - xr[0]), sy = niceStep(yr[1] - yr[0]);
  if (grid) {
    final g = Paint()
      ..color = color.withValues(alpha: 0.12 * t)
      ..strokeWidth = 1;
    for (var x = (xr[0] / sx).ceil() * sx; x <= xr[1] + 1e-9; x += sx) {
      canvas.drawLine(map(x, yr[0]), map(x, yr[1]), g);
    }
    for (var y = (yr[0] / sy).ceil() * sy; y <= yr[1] + 1e-9; y += sy) {
      canvas.drawLine(map(xr[0], y), map(xr[1], y), g);
    }
  }
  canvas.drawLine(xs, Offset.lerp(xs, xe, t)!, paint);
  canvas.drawLine(ys, Offset.lerp(ys, ye, t)!, paint);
  if (t < 1) return;
  // Arrow tips on the positive ends.
  for (final (a, b) in [(xs, xe), (ys, ye)]) {
    final dir = (b - a) / (b - a).distance, n = Offset(-dir.dy, dir.dx), k = font * 0.45;
    canvas.drawLine(b, b - dir * k + n * k * 0.6, paint);
    canvas.drawLine(b, b - dir * k - n * k * 0.6, paint);
  }
  final tick = font * 0.3, lc = color.withValues(alpha: 0.85);
  for (var x = (xr[0] / sx).ceil() * sx; x <= xr[1] + 1e-9; x += sx) {
    if (x.abs() < sx * 1e-6 || (xr[1] - x).abs() < sx * 0.3) continue;
    final at = map(x, y0);
    canvas.drawLine(at - Offset(0, tick), at + Offset(0, tick), paint);
    _label(canvas, tickLabel(x), at + Offset(0, tick + font * 0.65), font * 0.8, lc);
  }
  for (var y = (yr[0] / sy).ceil() * sy; y <= yr[1] + 1e-9; y += sy) {
    if (y.abs() < sy * 1e-6 || (yr[1] - y).abs() < sy * 0.3) continue;
    final at = map(x0, y);
    canvas.drawLine(at - Offset(tick, 0), at + Offset(tick, 0), paint);
    _label(canvas, tickLabel(y), at - Offset(tick + font * 0.25, 0), font * 0.8, lc, align: Alignment.centerRight);
  }
  if (xLabel != null) _label(canvas, xLabel, xe + Offset(-font * 0.2, -font * 0.9), font, color, align: Alignment.centerRight);
  if (yLabel != null) _label(canvas, yLabel, ye + Offset(font * 0.5, font * 0.3), font, color, align: Alignment.centerLeft);
}

/// y = f(x) in [box], sampled across [xr], drawn up to [t] from the left; breaks where f is
/// undefined or leaves the box far behind (tan, 1/x).
void paintFunction(Canvas canvas, Rect box, List<double> xr, List<double> yr, double Function(double) f, Paint paint, {double t = 1, int samples = 240}) {
  canvas.save();
  canvas.clipRect(box.inflate(paint.strokeWidth));
  final path = Path();
  var pen = false;
  final last = (samples * t).round();
  final span = yr[1] - yr[0];
  for (var i = 0; i <= last; i++) {
    final x = xr[0] + (xr[1] - xr[0]) * i / samples;
    final y = f(x);
    if (!y.isFinite || y < yr[0] - span * 2 || y > yr[1] + span * 2) {
      pen = false;
      continue;
    }
    final o = Offset(box.left + (x - xr[0]) / (xr[1] - xr[0]) * box.width, box.bottom - (y - yr[0]) / span * box.height);
    pen ? path.lineTo(o.dx, o.dy) : path.moveTo(o.dx, o.dy);
    pen = true;
  }
  canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  canvas.restore();
}
