import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/model.dart';
import '../scene/scene_painter.dart';
import '../scene/strings.dart';
import 'activity_logic.dart';

/// Runs a change to the activity and clears the old feedback (ActivityViewState.update).
typedef ActivityChange = void Function(VoidCallback);

/// Pairs in a match activity: Okabe–Ito colours, told apart by colour-blind eyes too.
const _pairColors = [Color(0xFF0072B2), Color(0xFFD55E00), Color(0xFF009E73), Color(0xFFCC79A7), Color(0xFFE69F00), Color(0xFF56B4E9), Color(0xFF8A6D00), Color(0xFF5B6369)];

/// A card the class drags or taps: white with a hairline and the 1 px lift, a grip; blue when
/// selected, green or orange after Check. [placed] is the flat row it becomes inside a column.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.text, this.mark, this.selected = false, this.onTap, this.leading, this.compact = false, this.placed = false});
  final String text;
  final bool? mark;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool compact;
  final bool placed;

  @override
  Widget build(BuildContext context) {
    final edge = mark == true
        ? Z.correct
        : mark == false
        ? Z.wrong
        : selected
        ? Z.primary
        : (placed ? Colors.transparent : Z.line);
    final bg = mark == true
        ? Z.correctBg
        : mark == false
        ? Z.wrongBg
        : selected
        ? Z.tagBg
        : Z.panel;
    final strong = selected || mark != null;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Z.radius), boxShadow: placed || strong ? null : Z.lift),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius), side: BorderSide(color: edge, width: strong ? 4 : 2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(Z.radius),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: context.narrow ? 72 : (compact || placed ? 92 : 96), minWidth: 80),
            padding: EdgeInsets.fromLTRB(placed || leading != null ? 28 : 24, 10, 32, 10),
            child: Row(
              mainAxisSize: placed ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 16)] else if (!placed) ...[_Grip(color: selected ? Z.primary : Z.ghost), const SizedBox(width: 20)],
                Flexible(child: Text(text, style: zText(context.narrow ? 27 : (compact || placed ? 30 : 32), strong && !placed ? FontWeight.w600 : FontWeight.w500).copyWith(color: Z.ink))),
                if (mark != null) ...[const SizedBox(width: 12), Icon(mark! ? Icons.check_circle : Icons.cancel, size: 36, color: mark! ? Z.correct : Z.wrong)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Six dots: "this can be dragged".
class _Grip extends StatelessWidget {
  const _Grip({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 32,
    child: CustomPaint(painter: _GripPainter(color)),
  );
}

class _GripPainter extends CustomPainter {
  _GripPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (final x in [4.0, 16.0]) {
      for (final y in [6.0, 16.0, 26.0]) {
        canvas.drawCircle(Offset(x, y), 2.8, p);
      }
    }
  }

  @override
  bool shouldRepaint(_GripPainter old) => old.color != color;
}

/// A rounded rectangle with a dashed border (the tray, a "Drop here" slot).
class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.child, this.color = Z.line, this.radius = Z.panelRadius, this.width = 4, this.fill});
  final Widget child;
  final Color color;
  final double radius, width;
  final Color? fill;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DashPainter(color, radius, width, fill), child: child);
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.radius, this.width, this.fill);
  final Color color;
  final double radius, width;
  final Color? fill;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius((Offset.zero & size).deflate(width / 2), Radius.circular(radius));
    if (fill != null) canvas.drawRRect(r, Paint()..color = fill!);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final m in (Path()..addRRect(r)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 22) {
        canvas.drawPath(m.extractPath(d, math.min(d + 12, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.fill != fill;
}

Widget _draggable(int data, Widget card) => Draggable<int>(
  data: data,
  feedback: Material(
    color: Colors.transparent,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: card),
  ),
  childWhenDragging: Opacity(opacity: 0.3, child: card),
  child: card,
);

// ---------------------------------------------------------------- sort

class SortBoard extends StatefulWidget {
  const SortBoard({super.key, required this.logic, required this.lang, required this.onChange});
  final SortLogic logic;
  final Lang lang;
  final ActivityChange onChange;
  @override
  State<SortBoard> createState() => _SortBoardState();
}

class _SortBoardState extends State<SortBoard> {
  int? selected;

  void _place(int item, String? bucket) => widget.onChange(() {
    widget.logic.place(item, bucket);
    selected = null;
  });

  Widget _chip(int i, {bool placed = false}) {
    final g = widget.logic;
    return _draggable(
      i,
      ActivityCard(
        key: ValueKey('item-$i'),
        text: g.items[i].text.t(widget.lang),
        mark: g.marks.isEmpty ? null : g.marks[i],
        selected: selected == i,
        placed: placed && selected != i,
        onTap: () => setState(() => selected = selected == i ? null : i),
        compact: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.logic, l = widget.lang;
    final narrow = context.narrow;
    final tray = [
      for (final i in g.trayOrder)
        if (g.placed[i] == null) i,
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = math.max(1, math.min(g.buckets.length, (box.maxWidth / 340).floor()));
        final rows = (g.buckets.length / cols).ceil();
        Widget bucket(int k) {
          final b = g.buckets[k];
          return DragTarget<int>(
            onAcceptWithDetails: (d) => _place(d.data, b.id),
            builder: (context, cand, _) {
              // A dragged item over the column lights it up; a tapped item shows a slot in each.
              final hot = cand.isNotEmpty;
              final slot = hot || selected != null;
              return Material(
                color: hot ? Z.tagBg : Z.tile,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.panelRadius), side: hot ? const BorderSide(color: Z.primary, width: 4) : BorderSide.none),
                child: InkWell(
                  key: ValueKey('bucket-${b.id}'),
                  onTap: selected == null ? null : () => _place(selected!, b.id),
                  borderRadius: BorderRadius.circular(Z.panelRadius),
                  child: Padding(
                    padding: EdgeInsets.all(narrow ? 16 : 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(b.label.t(l), style: zTitle(narrow ? 30 : 34), maxLines: 1, overflow: TextOverflow.ellipsis),
                        SizedBox(height: narrow ? 10 : 20),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < g.items.length; i++)
                                  if (g.placed[i] == b.id) Padding(padding: const EdgeInsets.only(bottom: 20), child: _chip(i, placed: true)),
                                if (slot)
                                  DashedBox(
                                    color: Z.primary,
                                    radius: Z.radius,
                                    child: SizedBox(height: 92, child: Center(child: Text(st('dropHere', l), style: zText(28, FontWeight.w600).copyWith(color: Z.primary)))),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DragTarget<int>(
              onAcceptWithDetails: (d) => _place(d.data, null),
              builder: (context, cand, _) => tray.isEmpty
                  ? const SizedBox.shrink()
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: box.maxHeight * 0.4),
                      child: DashedBox(
                        fill: Z.well,
                        child: Padding(
                          padding: EdgeInsets.all(narrow ? 16 : 28),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: narrow ? 12 : 20,
                              runSpacing: narrow ? 12 : 20,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [for (final i in tray) _chip(i)],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            SizedBox(height: tray.isEmpty ? 0 : (narrow ? 16 : 40)),
            Expanded(
              child: Column(
                children: [
                  for (var r = 0; r < rows; r++) ...[
                    if (r > 0) SizedBox(height: narrow ? 12 : 28),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = 0; c < cols; c++) ...[
                            if (c > 0) SizedBox(width: narrow ? 12 : 28),
                            Expanded(child: r * cols + c < g.buckets.length ? bucket(r * cols + c) : const SizedBox.shrink()),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- order

class OrderBoard extends StatelessWidget {
  const OrderBoard({super.key, required this.logic, required this.lang, required this.onChange});
  final OrderLogic logic;
  final Lang lang;
  final ActivityChange onChange;

  @override
  Widget build(BuildContext context) {
    final g = logic;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: g.order.length,
      onReorderItem: (from, to) => onChange(() => g.move(from, to)),
      itemBuilder: (context, k) {
        final step = g.order[k];
        return Padding(
          key: ValueKey('step-$step'),
          padding: const EdgeInsets.only(bottom: 10),
          child: ReorderableDragStartListener(
            index: k,
            child: ActivityCard(
              text: g.steps[step].t(lang),
              mark: g.marks.isEmpty ? null : g.marks[k],
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 28, backgroundColor: Z.primary, child: Text('${k + 1}', style: zText(28, FontWeight.w600).copyWith(color: Colors.white))),
                  const SizedBox(width: 4),
                  IconButton(key: ValueKey('up-$step'), tooltip: st('moveUp', lang), iconSize: 44, constraints: const BoxConstraints(minWidth: 72, minHeight: 72), onPressed: k == 0 ? null : () => onChange(() => g.move(k, k - 1)), icon: const Icon(Icons.arrow_upward)),
                  IconButton(key: ValueKey('down-$step'), tooltip: st('moveDown', lang), iconSize: 44, constraints: const BoxConstraints(minWidth: 72, minHeight: 72), onPressed: k == g.order.length - 1 ? null : () => onChange(() => g.move(k, k + 1)), icon: const Icon(Icons.arrow_downward)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- match

class MatchBoard extends StatefulWidget {
  const MatchBoard({super.key, required this.logic, required this.lang, required this.onChange});
  final MatchLogic logic;
  final Lang lang;
  final ActivityChange onChange;
  @override
  State<MatchBoard> createState() => _MatchBoardState();
}

class _MatchBoardState extends State<MatchBoard> {
  int? selected;

  Widget _badge(int left) => CircleAvatar(
    radius: 24,
    backgroundColor: _pairColors[left % _pairColors.length],
    child: Text('${left + 1}', style: zText(26, FontWeight.w600).copyWith(color: Colors.white)),
  );

  @override
  Widget build(BuildContext context) {
    final g = widget.logic, l = widget.lang;
    final left = [
      for (var i = 0; i < g.pairs.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _draggable(
            i,
            ActivityCard(
              key: ValueKey('left-$i'),
              text: g.pairs[i].left.t(l),
              leading: _badge(i),
              selected: selected == i,
              mark: g.marks.isEmpty ? null : g.marks[i],
              onTap: () => setState(() => selected = selected == i ? null : i),
            ),
          ),
        ),
    ];
    final right = [
      for (final r in g.rightOrder)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DragTarget<int>(
            onAcceptWithDetails: (d) => widget.onChange(() {
              g.join(d.data, r);
              selected = null;
            }),
            builder: (context, cand, _) {
              final owner = g.link.indexOf(r);
              return ActivityCard(
                key: ValueKey('right-$r'),
                text: g.pairs[r].right.t(l),
                leading: owner < 0 ? const CircleAvatar(radius: 24, backgroundColor: Z.segTrack, child: Icon(Icons.link, size: 28, color: Z.muted)) : _badge(owner),
                selected: cand.isNotEmpty,
                onTap: selected == null
                    ? null
                    : () => widget.onChange(() {
                        g.join(selected!, r);
                        selected = null;
                      }),
              );
            },
          ),
        ),
    ];
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- label & hotspot

class DiagramBoard extends StatefulWidget {
  const DiagramBoard.label({super.key, required this.block, required LabelLogic this.logic, required this.lang, required this.onChange}) : showLabels = true;
  const DiagramBoard.hotspot({super.key, required this.block, required HotspotLogic this.logic, required this.lang, required this.onChange, this.showLabels = false});
  final Block block;
  final ActivityLogic logic;
  final Lang lang;
  final ActivityChange onChange;

  /// Hotspot: target names appear only after Check or Show answer.
  final bool showLabels;
  @override
  State<DiagramBoard> createState() => _DiagramBoardState();
}

class _DiagramBoardState extends State<DiagramBoard> {
  int? selected;
  late final viewRaw = (widget.block.raw['view'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  late final (double, double, double, double) view = () {
    List<double> r(Object? v) => v is List && v.length == 2 ? [(v[0] as num).toDouble(), (v[1] as num).toDouble()] : [0, 10];
    final x = r(viewRaw['x']), y = r(viewRaw['y']);
    return (x[0], x[1], y[0], y[1]);
  }();
  late final shapes = compileShapes(widget.block.raw['shapes'], const []);

  List<ActivityTarget> get targets => switch (widget.logic) {
    final LabelLogic g => g.targets,
    final HotspotLogic g => g.targets,
    _ => const [],
  };

  void _tapTarget(int i) {
    switch (widget.logic) {
      case final LabelLogic g:
        final placed = g.onTarget[i];
        if (selected != null) {
          widget.onChange(() {
            g.place(selected!, i);
            selected = null;
          });
        } else if (placed != null) {
          widget.onChange(() => g.place(placed, null));
        }
      case final HotspotLogic g:
        widget.onChange(() => g.tap(i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang;
    final g = widget.logic;
    final label = g is LabelLogic ? g : null;
    final diagram = LayoutBuilder(
      builder: (context, box) {
        final frame = SceneFrame(box.biggest, view, axes: viewRaw['axes'] == true, equal: viewRaw['equal'] == true);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: DiagramPainter(view: view, viewRaw: viewRaw, shapes: shapes, lang: l)),
            ),
            for (final (i, t) in targets.indexed)
              Builder(
                builder: (context) {
                  final c = frame.toScreen(t.x, t.y);
                  final tw = (t.w ?? 2 * (t.r ?? 0.5)) * frame.sx, th = (t.h ?? 2 * (t.r ?? 0.5)) * frame.sy;
                  final w = math.max(tw, label != null ? 200.0 : 96.0), h = math.max(th, label != null ? 72.0 : 96.0);
                  final mark = g.marks.isEmpty ? null : g.marks[i];
                  final picked = g is HotspotLogic && g.picked.contains(i);
                  final chip = label?.onTarget[i];
                  final color = mark == true
                      ? Z.correct
                      : mark == false
                      ? Z.wrong
                      : picked
                      ? Z.stageAccent
                      : Colors.white54;
                  Widget inner;
                  if (label != null) {
                    inner = chip == null
                        ? Icon(Icons.add_location_alt_outlined, size: 40, color: color)
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(label.chips[chip].text.t(l), style: zText(28, FontWeight.w700).copyWith(color: Colors.white)),
                            ),
                          );
                  } else {
                    inner = widget.showLabels
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(t.label.t(l), style: zText(26, FontWeight.w700).copyWith(color: Colors.white)),
                            ),
                          )
                        : const SizedBox.shrink();
                  }
                  final target = InkWell(
                    key: ValueKey('target-${t.id}'),
                    onTap: () => _tapTarget(i),
                    customBorder: label == null && t.w == null ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (chip != null || picked || mark != null) ? color.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.04),
                        shape: label == null && t.w == null ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: label == null && t.w == null ? null : BorderRadius.circular(16),
                        border: Border.all(color: color, width: picked || mark != null || chip != null ? 4 : 2),
                      ),
                      child: inner,
                    ),
                  );
                  return Positioned(
                    left: c.dx - w / 2,
                    top: c.dy - h / 2,
                    width: w,
                    height: h,
                    child: label == null
                        ? Material(type: MaterialType.transparency, child: target)
                        : DragTarget<int>(
                            onAcceptWithDetails: (d) => widget.onChange(() {
                              label.place(d.data, i);
                              selected = null;
                            }),
                            builder: (context, cand, _) => Material(type: MaterialType.transparency, child: target),
                          ),
                  );
                },
              ),
          ],
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          DragTarget<int>(
            onAcceptWithDetails: (d) => widget.onChange(() => label.place(d.data, null)),
            builder: (context, cand, _) => LayoutBuilder(
              builder: (context, box) => ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in label.free)
                        _draggable(
                          c,
                          ActivityCard(key: ValueKey('chip-$c'), text: label.chips[c].text.t(l), selected: selected == c, compact: true, onTap: () => setState(() => selected = selected == c ? null : c)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (label != null) const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: Z.stage, borderRadius: BorderRadius.circular(Z.stageRadius)),
            padding: const EdgeInsets.all(24),
            child: diagram,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- fill

class FillBoard extends StatefulWidget {
  const FillBoard({super.key, required this.block, required this.logic, required this.lang, required this.onChange});
  final Block block;
  final FillLogic logic;
  final Lang lang;
  final ActivityChange onChange;
  @override
  State<FillBoard> createState() => _FillBoardState();
}

class _FillBoardState extends State<FillBoard> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    final g = widget.logic, l = widget.lang;
    final pieces = FillLogic.pieces(widget.block.f('passage').t(l));
    final words = <Widget>[];
    for (final p in pieces) {
      if (p is String) {
        for (final w in p.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
          words.add(Text(w, style: zText(36, FontWeight.w400).copyWith(color: Z.ink)));
        }
      } else if (p is int && p >= 0 && p < g.blanks.length) {
        final c = g.chosen[p];
        words.add(
          ActivityCard(
            key: ValueKey('blank-$p'),
            compact: true,
            text: c == null ? '____ ${p + 1}' : g.blanks[p].options[c].t(l),
            selected: selected == p,
            mark: g.marks.isEmpty ? null : g.marks[p],
            onTap: () => setState(() => selected = selected == p ? null : p),
          ),
        );
      }
    }
    final sel = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: words),
          ),
        ),
        if (sel != null) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (k, o) in g.blanks[sel].options.indexed)
                    SizedBox(
                      height: Z.tap * 0.85,
                      child: OutlinedButton(
                        key: ValueKey('option-$sel-$k'),
                        onPressed: () => widget.onChange(() {
                          g.choose(sel, k);
                          selected = sel + 1 < g.blanks.length && g.chosen[sel + 1] == null ? sel + 1 : null;
                        }),
                        child: Text(o.t(l), style: zText(30)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
