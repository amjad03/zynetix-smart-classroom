import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/model.dart';
import '../scene/scene_painter.dart';
import '../scene/strings.dart';
import '../whiteboard_view.dart' show chalkboardColor;
import 'activity_logic.dart';

/// Runs a change to the activity and clears the old feedback (ActivityViewState.update).
typedef ActivityChange = void Function(VoidCallback);

const _pairColors = [Color(0xFF42A5F5), Color(0xFFFFA726), Color(0xFFAB47BC), Color(0xFF26A69A), Color(0xFFEC407A), Color(0xFF9CCC65), Color(0xFF8D6E63), Color(0xFF78909C)];

/// A card the class drags or taps: big text, a coloured edge for selection and for the
/// right/wrong mark after Check.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.text, this.mark, this.selected = false, this.onTap, this.leading, this.compact = false});
  final String text;
  final bool? mark;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final edge = mark == true
        ? Z.correct
        : mark == false
        ? Z.wrong
        : selected
        ? Z.accent
        : Colors.white38;
    // A chalk-dark chip with white text on any page background; the state tints it.
    const base = Color(0xFF263A33);
    return Material(
      color: mark == true
          ? Color.alphaBlend(Z.correct.withValues(alpha: 0.35), base)
          : mark == false
          ? Color.alphaBlend(Z.wrong.withValues(alpha: 0.35), base)
          : selected
          ? Color.alphaBlend(Z.accent.withValues(alpha: 0.3), base)
          : base,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: edge, width: selected || mark != null ? 4 : 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 64 : 80, minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Flexible(child: Text(text, style: zText(compact ? 26 : 30).copyWith(color: Colors.white))),
              if (mark != null) ...[const SizedBox(width: 8), Icon(mark! ? Icons.check_circle : Icons.cancel, size: 36, color: mark! ? Z.correct : Z.wrong)],
            ],
          ),
        ),
      ),
    );
  }
}

Widget _draggable(int data, Widget card) => Draggable<int>(
  data: data,
  feedback: Material(
    color: Colors.transparent,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: card),
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

  Widget _chip(int i) {
    final g = widget.logic;
    return _draggable(
      i,
      ActivityCard(
        key: ValueKey('item-$i'),
        text: g.items[i].text.t(widget.lang),
        mark: g.marks.isEmpty ? null : g.marks[i],
        selected: selected == i,
        onTap: () => setState(() => selected = selected == i ? null : i),
        compact: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.logic;
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
            builder: (context, cand, _) => InkWell(
              key: ValueKey('bucket-${b.id}'),
              onTap: selected == null ? null : () => _place(selected!, b.id),
              borderRadius: BorderRadius.circular(Z.radius),
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cand.isNotEmpty ? Z.accent.withValues(alpha: 0.15) : chalkboardColor,
                  border: Border.all(color: cand.isNotEmpty || selected != null ? Z.accent : Colors.white38, width: 3),
                  borderRadius: BorderRadius.circular(Z.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(b.label.t(widget.lang), textAlign: TextAlign.center, style: zText(32, FontWeight.w800).copyWith(color: Z.accent)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < g.items.length; i++)
                              if (g.placed[i] == b.id) _chip(i),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DragTarget<int>(
              onAcceptWithDetails: (d) => _place(d.data, null),
              builder: (context, cand, _) => ConstrainedBox(
                constraints: BoxConstraints(minHeight: tray.isEmpty ? 0 : 88, maxHeight: box.maxHeight * 0.4),
                child: SingleChildScrollView(
                  child: Wrap(spacing: 10, runSpacing: 10, children: [for (final i in tray) _chip(i)]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                children: [
                  for (var r = 0; r < rows; r++)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = 0; c < cols; c++) Expanded(child: r * cols + c < g.buckets.length ? bucket(r * cols + c) : const SizedBox.shrink()),
                        ],
                      ),
                    ),
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
                  CircleAvatar(radius: 26, backgroundColor: Z.accent, child: Text('${k + 1}', style: zText(28, FontWeight.w800).copyWith(color: Colors.black))),
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
    child: Text('${left + 1}', style: zText(26, FontWeight.w800).copyWith(color: Colors.white)),
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
                leading: owner < 0 ? const CircleAvatar(radius: 24, backgroundColor: Colors.white12, child: Icon(Icons.link, size: 28)) : _badge(owner),
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
                      ? Z.accent
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
            decoration: BoxDecoration(color: chalkboardColor, borderRadius: BorderRadius.circular(Z.radius)),
            padding: const EdgeInsets.all(16),
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
          words.add(Text(w, style: zText(34, FontWeight.w500)));
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
