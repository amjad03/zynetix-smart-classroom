import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/expr.dart';
import '../engine/model.dart';
import 'math_text.dart';
import 'whiteboard_view.dart' show chalkboardColor, inkColor, niceStep, paintAxes, paintFunction, tickLabel;

/// A slider of an interactive block.
class SliderSpec {
  SliderSpec({required this.name, required this.label, required this.min, required this.max, required this.step, required this.value, this.unit});
  final String name;
  final L10n label;
  final double min, max, step, value;
  final String? unit;

  factory SliderSpec.fromJson(Map<String, dynamic> j) {
    double n(String k, double d) => (j[k] as num?)?.toDouble() ?? d;
    final min = n('min', 0), max = math.max(n('max', 10), min + 1e-9);
    return SliderSpec(name: j['name'] as String? ?? 'a', label: L10n.of(j['label']), min: min, max: max, step: n('step', 1), value: n('value', min).clamp(min, max), unit: j['unit'] as String?);
  }
}

const _series = ['yellow', 'blue', 'red', 'green', 'orange', 'white'];

/// A data-driven interactive (schema `interactive`): a chart drawn with CustomPainter, huge
/// sliders the monitor can drag, live read-outs, and the caption and "Try this" beside it.
class InteractiveView extends StatefulWidget {
  const InteractiveView({super.key, required this.block, required this.lang});
  final Block block;
  final Lang lang;
  @override
  State<InteractiveView> createState() => InteractiveViewState();
}

class InteractiveViewState extends State<InteractiveView> {
  Map<String, dynamic> get raw => widget.block.raw;
  String get kind => raw['kind'] as String? ?? 'readouts';
  late final List<SliderSpec> sliders = [
    for (final s in (raw['sliders'] as List?) ?? const [])
      if (s is Map) SliderSpec.fromJson(s.cast<String, dynamic>()),
  ];
  late final Map<String, double> values = {for (final s in sliders) s.name: s.value};
  List<String> get names => [for (final s in sliders) s.name];

  void setValue(String name, double v) => setState(() => values[name] = v);

  /// A number, or an expression over the sliders (often just a slider's name).
  double resolve(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return tryCompileExpr(v, names)?.call(values) ?? double.nan;
    return double.nan;
  }

  List<double>? _range(String k) {
    final v = raw[k];
    return v is List && v.length == 2 ? [(v[0] as num).toDouble(), (v[1] as num).toDouble()] : null;
  }

  /// Read-outs: the block's, or sin/cos/tan for a unit circle that has none.
  List<({String label, String value})> readouts() {
    final l = widget.lang;
    final out = <({String label, String value})>[];
    final list = (raw['readouts'] as List?) ?? const [];
    for (final r in list) {
      if (r is! Map) continue;
      final f = tryCompileExpr(r['expr'] as String? ?? '', names);
      final v = f?.call(values) ?? double.nan;
      final digits = (r['digits'] as int?) ?? 2;
      final unit = r['unit'] as String?;
      out.add((label: L10n.of(r['label']).t(l), value: v.isFinite ? '${v.toStringAsFixed(digits)}${unit == null ? '' : ' $unit'}' : '—'));
    }
    if (out.isEmpty && kind == 'unit_circle') {
      final th = _theta * math.pi / 180;
      String f(double v) => v.abs() > 1e6 || !v.isFinite ? '∞' : v.toStringAsFixed(3);
      out.addAll([(label: 'sin θ', value: f(math.sin(th))), (label: 'cos θ', value: f(math.cos(th))), (label: 'tan θ', value: f(math.tan(th)))]);
    }
    return out;
  }

  double get _theta => values['theta'] ?? (sliders.isEmpty ? 30 : values[sliders.first.name]!);

  @override
  Widget build(BuildContext context) {
    final l = widget.lang, text = Theme.of(context).textTheme;
    final reads = readouts();
    final chart = kind == 'readouts'
        ? Center(
            child: Wrap(
              spacing: 32,
              runSpacing: 32,
              alignment: WrapAlignment.center,
              children: [for (final (i, r) in reads.indexed) _Readout(key: ValueKey('readout-$i'), label: r.label, value: r.value, big: true)],
            ),
          )
        : CustomPaint(key: const ValueKey('interactiveChart'), painter: _ChartPainter(this), child: const SizedBox.expand());
    final portrait = context.portrait;
    final controls = [for (final s in sliders) _BigSlider(spec: s, value: values[s.name]!, lang: l, onChanged: (v) => setValue(s.name, v))];
    return Flex(
      direction: portrait ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: LayoutBuilder(
            builder: (context, box) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: chalkboardColor, borderRadius: BorderRadius.circular(Z.radius)),
                    padding: const EdgeInsets.all(20),
                    child: chart,
                  ),
                ),
                // The sliders take at most half the height and scroll on a short screen.
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: box.maxHeight * 0.5),
                  child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: controls),
                  ),
                ),
              ],
            ),
          ),
        ),
        portrait ? const SizedBox(height: Z.gap) : const SizedBox(width: Z.gap),
        Expanded(
          flex: portrait ? 2 : 1,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MathText(widget.block.f('caption').t(l), style: text.bodyLarge),
                if (kind != 'readouts' && reads.isNotEmpty) ...[
                  const SizedBox(height: Z.gap),
                  for (final (i, r) in reads.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Readout(key: ValueKey('readout-$i'), label: r.label, value: r.value),
                    ),
                ],
                if (widget.block.list('tryThis').isNotEmpty) ...[
                  const SizedBox(height: Z.gap),
                  Text(tr('tryThis', l), style: text.headlineMedium),
                  const SizedBox(height: 8),
                  for (final p in widget.block.list('tryThis'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.touch_app_outlined, size: 40, color: Z.accent),
                          const SizedBox(width: 12),
                          Expanded(child: MathText(p.t(l), style: text.bodyLarge?.copyWith(fontSize: 30))),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({super.key, required this.label, required this.value, this.big = false});
  final String label, value;
  final bool big;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: big ? 40 : 20, vertical: big ? 28 : 14),
    decoration: BoxDecoration(
      color: Z.accent.withValues(alpha: 0.14),
      border: Border.all(color: Z.accent, width: 3),
      borderRadius: BorderRadius.circular(Z.radius),
    ),
    child: Column(
      crossAxisAlignment: big ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: big ? 34 : 26, color: big ? Colors.white : null),
        ),
        Text(
          value,
          style: TextStyle(fontSize: big ? 64 : 42, fontWeight: FontWeight.w800, color: Z.accent),
        ),
      ],
    ),
  );
}

/// A slider sized for the board: a 60 px thumb, a thick track, and its value in big type.
class _BigSlider extends StatelessWidget {
  const _BigSlider({required this.spec, required this.value, required this.lang, required this.onChanged});
  final SliderSpec spec;
  final double value;
  final Lang lang;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final divisions = ((spec.max - spec.min) / spec.step).round();
    final decimals = spec.step >= 1 ? 0 : (math.log(1 / spec.step) / math.ln10).ceil().clamp(1, 4);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: MathText(spec.label.t(lang), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 14,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 30, elevation: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 48),
                activeTrackColor: Z.accent,
                thumbColor: Z.accent,
                inactiveTrackColor: Colors.white24,
                showValueIndicator: ShowValueIndicator.never,
                tickMarkShape: SliderTickMarkShape.noTickMark,
              ),
              child: SizedBox(
                height: Z.tap,
                child: Slider(
                  key: ValueKey('slider-${spec.name}'),
                  min: spec.min,
                  max: spec.max,
                  divisions: divisions > 0 && divisions <= 2000 ? divisions : null,
                  value: value.clamp(spec.min, spec.max),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: Text(
              '${value.toStringAsFixed(decimals)}${spec.unit == null ? '' : ' ${spec.unit}'}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Z.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.s) : snapshot = Map.of(s.values);
  final InteractiveViewState s;
  final Map<String, double> snapshot;

  Map<String, dynamic> get raw => s.raw;
  static const font = 26.0;

  Paint _stroke(Color c, [double w = 6]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _text(Canvas canvas, String t, Offset at, {double size = font, Color color = Colors.white, Alignment align = Alignment.center, FontWeight weight = FontWeight.w600}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: zText(size, weight).copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width * (align.x + 1) / 2, tp.height * (align.y + 1) / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    switch (s.kind) {
      case 'function_plot':
        _functions(canvas, box);
      case 'vectors':
        _vectors(canvas, box);
      case 'bar_chart':
        _bars(canvas, box);
      case 'pie_chart':
        _pie(canvas, box);
      case 'unit_circle':
        _unitCircle(canvas, box);
      case 'number_line':
        _numberLine(canvas, box);
    }
  }

  Rect _plotBox(Rect box) => Rect.fromLTRB(box.left + 70, box.top + 20, box.right - 30, box.bottom - 50);

  void _functions(Canvas canvas, Rect box) {
    final xr = s._range('x') ?? [-10, 10], yr = s._range('y') ?? [-10, 10];
    final pb = _plotBox(box);
    paintAxes(canvas, pb, xr, yr, Colors.white70, strokeWidth: 3, font: font, xLabel: raw['xLabel'] as String? ?? 'x', yLabel: raw['yLabel'] as String? ?? 'y', grid: true);
    final fns = (raw['fns'] as List?) ?? const [];
    var legendY = pb.top + 10;
    for (final (i, f) in fns.indexed) {
      if (f is! Map) continue;
      final e = tryCompileExpr(f['fn'] as String? ?? '', ['x', ...s.names]);
      final color = inkColor(f['color'] ?? _series[i % _series.length]);
      if (e != null) {
        final vars = Map.of(snapshot);
        paintFunction(canvas, pb, xr, yr, (x) => e(vars..['x'] = x), _stroke(color));
      }
      final label = f['label'] as String? ?? 'y = ${f['fn']}';
      canvas.drawLine(Offset(pb.right - 300, legendY + 16), Offset(pb.right - 250, legendY + 16), _stroke(color));
      _text(canvas, label, Offset(pb.right - 240, legendY + 16), color: color, align: Alignment.centerLeft);
      legendY += 44;
    }
  }

  void _vectors(Canvas canvas, Rect box) {
    final vs = [
      for (final v in (raw['vectors'] as List?) ?? const [])
        if (v is List && v.length == 2) Offset(s.resolve(v[0]), s.resolve(v[1])),
    ].where((o) => o.dx.isFinite && o.dy.isFinite).toList();
    final r = vs.fold(Offset.zero, (a, b) => a + b);
    final reach =
        [
          for (final v in [...vs, r]) math.max(v.dx.abs(), v.dy.abs()),
        ].fold(1.0, math.max) *
        1.2;
    final xr = s._range('x') ?? [-reach, reach], yr = s._range('y') ?? [-reach, reach];
    // Equal scale on both axes, so angles look right.
    final pb0 = _plotBox(box);
    final k = math.min(pb0.width / (xr[1] - xr[0]), pb0.height / (yr[1] - yr[0]));
    final pb = Rect.fromCenter(center: pb0.center, width: k * (xr[1] - xr[0]), height: k * (yr[1] - yr[0]));
    paintAxes(canvas, pb, xr, yr, Colors.white60, strokeWidth: 3, font: font, xLabel: raw['xLabel'] as String? ?? 'x', yLabel: raw['yLabel'] as String? ?? 'y', grid: true);
    Offset map(Offset v) => Offset(pb.left + (v.dx - xr[0]) * k, pb.bottom - (v.dy - yr[0]) * k);
    final o = map(Offset.zero);
    if (vs.length == 2) {
      // The parallelogram that makes the resultant.
      final dash = _stroke(Colors.white38, 3);
      canvas.drawLine(map(vs[0]), map(r), dash);
      canvas.drawLine(map(vs[1]), map(r), dash);
    }
    void arrow(Offset v, Color c, String label, double w) {
      final a = o, b = map(v);
      if ((b - a).distance < 2) return;
      final p = _stroke(c, w);
      canvas.drawLine(a, b, p);
      final dir = (b - a) / (b - a).distance, n = Offset(-dir.dy, dir.dx);
      canvas.drawPath(Path()..addPolygon([b, b - dir * 26 + n * 14, b - dir * 26 - n * 14], true), Paint()..color = c);
      _text(canvas, '$label (${tickLabel(_round(v.dx))}, ${tickLabel(_round(v.dy))})', b + dir * 18 + n * 26, color: c, align: Alignment.center);
    }

    for (final (i, v) in vs.indexed) {
      arrow(v, inkColor(_series[(i + 1) % _series.length]), String.fromCharCode(65 + i), 6);
    }
    if (vs.length > 1) arrow(r, inkColor('yellow'), 'R', 9);
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  List<(String, double)> get _data => [for (final e in ((raw['data'] as Map?) ?? const {}).entries) (e.key.toString(), s.resolve(e.value))];

  void _bars(Canvas canvas, Rect box) {
    final data = _data;
    if (data.isEmpty) return;
    final top = data.map((e) => e.$2.isFinite ? e.$2 : 0).fold(0.0, math.max);
    final yr = s._range('y') ?? [0, top <= 0 ? 1 : top * 1.15];
    final pb = _plotBox(box);
    paintAxes(canvas, pb, [0, 1], yr, Colors.white70, strokeWidth: 3, font: font, yLabel: raw['yLabel'] as String?, grid: true);
    final slot = pb.width / data.length;
    for (final (i, (label, v)) in data.indexed) {
      final val = v.isFinite ? v.clamp(yr[0], yr[1]) : 0.0;
      final h = (val - yr[0]) / (yr[1] - yr[0]) * pb.height;
      final r = Rect.fromLTWH(pb.left + slot * i + slot * 0.18, pb.bottom - h, slot * 0.64, h);
      final c = inkColor(_series[i % _series.length]);
      canvas.drawRRect(RRect.fromRectAndCorners(r, topLeft: const Radius.circular(10), topRight: const Radius.circular(10)), Paint()..color = c.withValues(alpha: 0.85));
      _text(canvas, v.isFinite ? tickLabel(_round(v)) : '—', Offset(r.center.dx, r.top - 22), size: 30, color: c, weight: FontWeight.w800);
      _text(canvas, label, Offset(r.center.dx, pb.bottom + 26), size: 26);
    }
  }

  void _pie(Canvas canvas, Rect box) {
    final data = [
      for (final d in _data)
        if (d.$2.isFinite && d.$2 > 0) d,
    ];
    final total = data.fold(0.0, (a, d) => a + d.$2);
    if (total <= 0) return;
    final radius = math.min(box.height / 2 - 20, box.width * 0.3);
    final c = Offset(box.left + radius + 40, box.center.dy);
    var start = -math.pi / 2;
    for (final (i, (label, v)) in data.indexed) {
      final sweep = v / total * 2 * math.pi;
      final col = inkColor(_series[i % _series.length]);
      canvas.drawArc(Rect.fromCircle(center: c, radius: radius), start, sweep, true, Paint()..color = col.withValues(alpha: 0.9));
      canvas.drawArc(Rect.fromCircle(center: c, radius: radius), start, sweep, true, _stroke(chalkboardColor, 4));
      final mid = start + sweep / 2;
      if (sweep > 0.25) _text(canvas, '${(v / total * 100).toStringAsFixed(0)}%', c + Offset(math.cos(mid), math.sin(mid)) * radius * 0.62, size: 32, color: Colors.black87, weight: FontWeight.w800);
      // Legend.
      final ly = box.top + 40 + i * 56.0;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(c.dx + radius + 60, ly - 16, 32, 32), const Radius.circular(6)), Paint()..color = col);
      _text(canvas, '$label: ${tickLabel(_round(v))}', Offset(c.dx + radius + 108, ly), size: 30, align: Alignment.centerLeft);
      start += sweep;
    }
  }

  void _unitCircle(Canvas canvas, Rect box) {
    final th = s._theta * math.pi / 180;
    final r = math.min(box.height, box.width) / 2 - 60;
    final c = box.center;
    final axis = _stroke(Colors.white54, 3);
    canvas.drawLine(Offset(c.dx - r - 40, c.dy), Offset(c.dx + r + 40, c.dy), axis);
    canvas.drawLine(Offset(c.dx, c.dy - r - 40), Offset(c.dx, c.dy + r + 40), axis);
    canvas.drawCircle(c, r, _stroke(Colors.white70, 4));
    for (final (t, s) in [(r, '1'), (-r, '−1')]) {
      _text(canvas, s, Offset(c.dx + t, c.dy + 24), size: 24, color: Colors.white70);
    }
    final p = c + Offset(math.cos(th), -math.sin(th)) * r;
    // tan: the tangent at (1, 0) up to where the radius line meets it.
    final tanV = math.tan(th);
    if (math.cos(th).abs() > 0.05 && tanV.abs() < 4) {
      final tp = Offset(c.dx + r, c.dy - tanV * r);
      canvas.drawLine(Offset(c.dx + r, c.dy), tp, _stroke(inkColor('orange'), 6));
      canvas.drawLine(c, tp, _stroke(inkColor('orange').withValues(alpha: 0.4), 3));
      _text(canvas, 'tan θ', tp + const Offset(56, 0), color: inkColor('orange'));
    }
    canvas.drawLine(c, p, _stroke(Colors.white, 5));
    canvas.drawLine(Offset(p.dx, c.dy), p, _stroke(inkColor('red'), 7)); // sin
    canvas.drawLine(c, Offset(p.dx, c.dy), _stroke(inkColor('blue'), 7)); // cos
    canvas.drawArc(Rect.fromCircle(center: c, radius: 56), 0, -th, false, _stroke(Z.accent, 4));
    _text(canvas, 'θ = ${tickLabel(_round(s._theta))}°', c + Offset(math.cos(-th / 2), math.sin(-th / 2)) * 100, color: Z.accent, size: 28);
    canvas.drawCircle(p, 14, Paint()..color = Z.accent);
    _text(canvas, 'sin θ', Offset(p.dx + (math.cos(th) >= 0 ? 52 : -52), (p.dy + c.dy) / 2), color: inkColor('red'));
    _text(canvas, 'cos θ', Offset((p.dx + c.dx) / 2, c.dy + (math.sin(th) >= 0 ? 28 : -28)), color: inkColor('blue'));
    _text(canvas, 'P(cos θ, sin θ)', p + Offset(math.cos(th) >= 0 ? 24 : -24, math.sin(th) >= 0 ? -30 : 30), align: math.cos(th) >= 0 ? Alignment.centerLeft : Alignment.centerRight);
  }

  void _numberLine(Canvas canvas, Rect box) {
    final pts = [for (final p in (raw['points'] as List?) ?? const []) (p is String ? p : null, s.resolve(p))];
    final finite = [
      for (final p in pts)
        if (p.$2.isFinite) p.$2,
    ];
    final lo = finite.isEmpty ? -5.0 : finite.reduce(math.min), hi = finite.isEmpty ? 5.0 : finite.reduce(math.max);
    final xr = s._range('x') ?? [(lo - 1).floorToDouble(), (hi + 1).ceilToDouble()];
    final y = box.center.dy, left = box.left + 40, right = box.right - 40;
    double map(double x) => left + (x - xr[0]) / (xr[1] - xr[0]) * (right - left);
    final line = _stroke(Colors.white, 4);
    canvas.drawLine(Offset(left - 20, y), Offset(right + 20, y), line);
    for (final (a, d) in [(left - 20, 1.0), (right + 20, -1.0)]) {
      canvas.drawLine(Offset(a, y), Offset(a + 22 * d, y - 14), line);
      canvas.drawLine(Offset(a, y), Offset(a + 22 * d, y + 14), line);
    }
    final step = niceStep(xr[1] - xr[0], 12);
    for (var x = (xr[0] / step).ceil() * step; x <= xr[1] + 1e-9; x += step) {
      canvas.drawLine(Offset(map(x), y - 14), Offset(map(x), y + 14), line);
      _text(canvas, tickLabel(_round(x)), Offset(map(x), y + 40), size: 26, color: Colors.white70);
    }
    if (raw['xLabel'] is String) _text(canvas, raw['xLabel'] as String, Offset(right, y + 84), align: Alignment.centerRight);
    for (final (i, (name, v)) in pts.indexed) {
      if (!v.isFinite) continue;
      final c = inkColor(_series[i % _series.length]);
      final at = Offset(map(v.clamp(xr[0], xr[1])), y);
      canvas.drawCircle(at, 16, Paint()..color = c);
      final up = i.isEven ? -1 : 1;
      _text(canvas, name == null ? tickLabel(_round(v)) : '$name = ${tickLabel(_round(v))}', at + Offset(0, up * (up < 0 ? 52.0 : 92.0)), color: c, size: 30, weight: FontWeight.w800);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
