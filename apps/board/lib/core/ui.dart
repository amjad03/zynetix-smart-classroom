import 'package:flutter/material.dart';

import 'theme.dart';

/// The pieces every screen is built from: white panels on the page, the dark stage with its
/// transport bar, tags, readout tiles, segmented controls and pill switches.

/// A white panel (radius 16).
class ZPanel extends StatelessWidget {
  const ZPanel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(44, 40, 44, 40), this.color = Z.panel, this.radius = Z.panelRadius});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
    child: child,
  );
}

/// A panel heading: Poppins 600.
class ZSectionTitle extends StatelessWidget {
  const ZSectionTitle(this.text, {super.key, this.size = 30, this.color = Z.ink, this.trailing});
  final String text;
  final double size;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Text(text, style: zTitle(size).copyWith(color: color), maxLines: 2, overflow: TextOverflow.ellipsis);
    if (trailing == null) return t;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [Expanded(child: t), const SizedBox(width: 16), trailing!],
    );
  }
}

/// The dark stage the subject sits on: an optional heading and hint, the content, and an inset
/// transport bar. [padding] is around the content.
class ZStage extends StatelessWidget {
  const ZStage({super.key, required this.child, this.title, this.hint, this.transport, this.padding = const EdgeInsets.fromLTRB(28, 16, 28, 16), this.radius = Z.stageRadius});
  final Widget child;
  final String? title, hint;
  final Widget? transport;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final compact = context.narrow;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Z.stage, borderRadius: BorderRadius.circular(radius)),
      child: Theme(
        data: zynetixStageTheme(),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Z.onStage),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || hint != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 28 : 44, compact ? 20 : 32, compact ? 28 : 44, 0),
                  child: Row(
                    children: [
                      if (title != null) Expanded(child: Text(title!, style: zTitle(34).copyWith(color: Z.onStage), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (hint != null && !(compact && context.portrait)) ...[
                        const SizedBox(width: 24),
                        Flexible(child: Text(hint!, style: zText(26, FontWeight.w400).copyWith(color: Z.onStage2), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: Padding(padding: padding, child: child),
              ),
              if (transport != null) Padding(padding: EdgeInsets.fromLTRB(compact ? 16 : 28, 0, compact ? 16 : 28, compact ? 16 : 28), child: transport),
            ],
          ),
        ),
      ),
    );
  }
}

/// The inset bar at the bottom of a stage (play, step, reset, scrubber, speed).
class ZTransport extends StatelessWidget {
  const ZTransport({super.key, required this.children, this.padding = const EdgeInsets.all(16), this.gap = 20});
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: Z.transport, borderRadius: BorderRadius.circular(Z.panelRadius)),
    child: Row(
      children: [
        for (final (i, c) in children.indexed) ...[if (i > 0) SizedBox(width: gap), c],
      ],
    ),
  );
}

/// A round button on the stage: [primary] is white with a dark icon (play/pause).
class StageButton extends StatelessWidget {
  const StageButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.primary = false, this.size});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool primary;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final d = size ?? (primary ? 92.0 : 84.0);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: primary ? Colors.white : Z.stageButton,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(dimension: d, child: Icon(icon, size: d * 0.42, color: primary ? Z.stage : Z.onStage)),
          ),
        ),
      ),
    );
  }
}

/// A pill on the stage with text (the speed chip, Reset view).
class StagePill extends StatelessWidget {
  const StagePill({super.key, required this.label, this.onPressed, this.height = 84, this.light = false});
  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool light;

  @override
  Widget build(BuildContext context) => Material(
    color: light ? Colors.white : Z.stageButton,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onPressed,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        alignment: Alignment.center,
        child: Text(label, style: zText(28, FontWeight.w600).copyWith(color: light ? Z.stage : Z.onStage)),
      ),
    ),
  );
}

/// A tag: blue on pale blue ("Class quiz", "Activity · Sort").
class ZTag extends StatelessWidget {
  const ZTag(this.text, {super.key, this.color = Z.primary, this.background = Z.tagBg, this.icon});
  final String text;
  final Color color, background;
  final IconData? icon;

  /// A neutral chip ("KCET · JEE Main pattern", "Phones 31").
  const ZTag.neutral(this.text, {super.key, this.icon}) : color = Z.ink2, background = Z.segTrack;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Z.pill)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 28, color: color), const SizedBox(width: 10)],
        Flexible(child: Text(text, style: zText(26, color == Z.primary ? FontWeight.w600 : FontWeight.w500).copyWith(color: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

enum Tone { neutral, correct, wrong }

/// A readout tile: a label over a value with its unit (radius 12). Tinted green or orange only
/// when the value means right or wrong.
class ZReadout extends StatelessWidget {
  const ZReadout({super.key, required this.label, required this.value, this.unit, this.tone = Tone.neutral, this.valueSize = 44, this.background});
  final String label, value;
  final String? unit;
  final Tone tone;
  final double valueSize;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final (bg, labelC, valueC, unitC) = switch (tone) {
      Tone.correct => (Z.correctBg, Z.correctLabel, Z.correct, Z.correct),
      Tone.wrong => (Z.wrongBg, Z.wrongText, Z.wrongText, Z.wrongText),
      Tone.neutral => (background ?? Z.tile, Z.muted, Z.ink, Z.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Z.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: zText(26, FontWeight.w400).copyWith(color: labelC), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          // Value and unit as two texts (the unit smaller), so the value reads on its own.
          // A long value shrinks to fit its tile rather than being cut.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: zText(valueSize, FontWeight.w600).copyWith(color: valueC), maxLines: 1),
                if (unit != null && unit!.isNotEmpty) Text(' $unit', style: zText(28, FontWeight.w500).copyWith(color: unitC), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiles two to a row (or [columns]), each the same width.
class ZTileGrid extends StatelessWidget {
  const ZTileGrid({super.key, required this.children, this.columns = 2, this.gap = 20});
  final List<Widget> children;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w.isFinite && w > 0 ? w : null, child: c)],
      );
    },
  );
}

/// A segmented control: a pale track with the selected item raised in white.
class ZSegmented<T> extends StatelessWidget {
  const ZSegmented({super.key, required this.items, required this.selected, required this.onChanged, this.height = 80, this.fontSize = 28, this.expand = true});
  final List<(T, String, Key?)> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height, fontSize;

  /// Items share the width equally (else each is as wide as its label).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget item((T, String, Key?) it) {
      final on = it.$1 == selected;
      final w = Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          key: it.$3,
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(it.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(18), boxShadow: on ? Z.lift : null),
            child: Text(it.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: zText(fontSize, on ? FontWeight.w600 : FontWeight.w500).copyWith(color: on ? Z.ink : Z.ink2)),
          ),
        ),
      );
      return expand ? Expanded(child: w) : w;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Z.segTrack, borderRadius: BorderRadius.circular(Z.radius)),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final (i, it) in items.indexed) ...[if (i > 0) const SizedBox(width: 8), item(it)],
        ],
      ),
    );
  }
}

/// A pill switch (44 × 26 in the design). [onStage] draws it for the dark stage.
class ZSwitch extends StatelessWidget {
  const ZSwitch({super.key, required this.value, required this.onChanged, this.onStage = false});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool onStage;

  @override
  Widget build(BuildContext context) {
    final track = value ? (onStage ? Z.stageAccent : Z.primary) : (onStage ? Z.stageTrack : Z.line);
    final knob = value && onStage ? Z.stage : Colors.white;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 88,
          height: 52,
          padding: const EdgeInsets.all(6),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(Z.pill)),
          child: Container(width: 40, height: 40, decoration: BoxDecoration(color: knob, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}

/// A labelled switch row: the label on the left, the switch on the right; the whole row taps.
class ZSwitchRow extends StatelessWidget {
  const ZSwitchRow({super.key, required this.label, required this.value, required this.onChanged, this.onStage = false, this.fontSize = 30});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool onStage;
  final double fontSize;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(Z.radius),
    onTap: () => onChanged(!value),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: [
          Expanded(child: Text(label, style: zText(fontSize, FontWeight.w500).copyWith(color: onStage ? Z.onStage : Z.ink))),
          const SizedBox(width: 16),
          ZSwitch(value: value, onChanged: onChanged, onStage: onStage),
        ],
      ),
    ),
  );
}

/// A thin pill progress bar.
class ZProgress extends StatelessWidget {
  const ZProgress({super.key, required this.value, this.width, this.height = 12, this.color = Z.primary, this.track = Z.track});
  final double value;
  final double? width;
  final double height;
  final Color color, track;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Container(decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(Z.pill))),
          Container(
            width: box.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Z.pill)),
          ),
        ],
      ),
    ),
  );
}

/// The top bar panel: breadcrumb, title, then whatever follows ([trailing]: step, buttons, close).
class ZTopBar extends StatelessWidget {
  const ZTopBar({super.key, this.leading, this.crumbs = const [], required this.title, this.trailing = const [], this.titleKey});
  final Widget? leading;
  final List<String> crumbs;
  final String title;
  final List<Widget> trailing;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    final titleW = Text(title, key: titleKey, style: zTitle(narrow ? 36 : Z.title), maxLines: 1, overflow: TextOverflow.ellipsis);
    final crumbText = crumbs.join('  ›  ');
    return Container(
      constraints: const BoxConstraints(minHeight: 128),
      padding: EdgeInsets.fromLTRB(leading == null ? (narrow ? 32 : 44) : 16, narrow ? 16 : 12, 24, narrow ? 16 : 12),
      decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 16)],
          Expanded(
            child: narrow || crumbs.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (crumbs.isNotEmpty) Text(crumbText, style: zText(24, FontWeight.w400).copyWith(color: Z.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      titleW,
                    ],
                  )
                : Row(
                    children: [
                      Flexible(flex: 2, child: Text(crumbText, style: zText(28, FontWeight.w400).copyWith(color: Z.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 36),
                      Flexible(flex: 3, child: titleW),
                    ],
                  ),
          ),
          for (final w in trailing) ...[const SizedBox(width: 20), w],
        ],
      ),
    );
  }
}

/// The square close / back button of a top bar (pale fill, no border).
class ZIconSquare extends StatelessWidget {
  const ZIconSquare({super.key, required this.icon, required this.tooltip, required this.onPressed, this.size = 84});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Z.segTrack,
        borderRadius: BorderRadius.circular(Z.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(Z.radius),
          onTap: onPressed,
          child: SizedBox.square(dimension: size, child: Icon(icon, size: 36, color: Z.ink)),
        ),
      ),
    ),
  );
}

/// A compact secondary button (top bar: Smartboard, ಕನ್ನಡ): 42 px high in the design.
class ZSmallButton extends StatelessWidget {
  const ZSmallButton({super.key, this.icon, required this.label, required this.onPressed, this.iconOnly = false});
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 84,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(minimumSize: const Size(84, 84), padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 28), textStyle: zText(28, FontWeight.w500)),
      child: iconOnly
          ? Tooltip(message: label, child: Icon(icon, size: 32))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 32), const SizedBox(width: 14)],
                Text(label),
              ],
            ),
    ),
  );
}

/// The stage on the left (flexible) and a rail of panels on the right, about 380 design px wide.
/// Upright, the rail goes under the stage; on a short landscape phone, the rail narrows.
class StageLayout extends StatelessWidget {
  const StageLayout({super.key, required this.stage, required this.rail, this.railWidth = 760, this.stageFlexPortrait = 5, this.railFlexPortrait = 4});
  final Widget stage;
  final List<Widget> rail;
  final double railWidth;
  final int stageFlexPortrait, railFlexPortrait;

  @override
  Widget build(BuildContext context) {
    final gap = context.narrow ? 20.0 : Z.gap;
    final railCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, r) in rail.indexed) ...[if (i > 0) SizedBox(height: gap), r],
      ],
    );
    if (context.portrait) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: stageFlexPortrait, child: stage),
          if (rail.isNotEmpty) ...[SizedBox(height: gap), Expanded(flex: railFlexPortrait, child: RailScroll(child: railCol))],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final w = railWidth.clamp(0.0, box.maxWidth * 0.4);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: stage),
            if (rail.isNotEmpty) ...[SizedBox(width: gap), SizedBox(width: w, child: RailScroll(child: railCol))],
          ],
        );
      },
    );
  }
}

/// The rail beside a stage: its panels scroll as a column, whole (none is squeezed or cut off for
/// good). When there is more below, a slim scrollbar shows and the bottom edge fades, so a panel
/// that runs past the edge reads as "scroll for more" rather than as clipped.
class RailScroll extends StatefulWidget {
  const RailScroll({super.key, required this.child});
  final Widget child;
  @override
  State<RailScroll> createState() => _RailScrollState();
}

class _RailScrollState extends State<RailScroll> {
  final _scroll = ScrollController();
  bool _more = false, _scrolled = false;

  bool _onMetrics(Notification n) {
    final m = switch (n) {
      ScrollMetricsNotification(:final metrics) => metrics,
      ScrollNotification(:final metrics) => metrics,
      _ => null,
    };
    // Only the rail's own scroll view, not one inside a panel or a lab.
    if (m == null || m.axis != Axis.vertical || (n is ViewportNotificationMixin && n.depth > 0)) return false;
    final more = m.extentAfter > 1, scrolled = m.extentBefore > 1;
    if (more != _more || scrolled != _scrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _more = more;
          _scrolled = scrolled;
        });
      });
    }
    return false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fade = 72.0;
    // Always the same tree (only the gradient changes), so the scroll position is kept.
    final list = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Colors.white, _more ? Colors.transparent : Colors.white],
        stops: [0, r.height <= fade ? 0 : (r.height - fade) / r.height, 1],
      ).createShader(r),
      child: SingleChildScrollView(key: const ValueKey('railScroll'), controller: _scroll, child: widget.child),
    );
    return NotificationListener<Notification>(
      onNotification: _onMetrics,
      child: RawScrollbar(
        controller: _scroll,
        thumbVisibility: _more || _scrolled,
        thickness: 8,
        radius: const Radius.circular(Z.pill),
        thumbColor: Z.ghost,
        crossAxisMargin: 6,
        mainAxisMargin: 12,
        child: list,
      ),
    );
  }
}

/// A Kinetix lab (or player) on the stage. A lab lays out its own side panel (readouts, controls,
/// its aim) that scrolls by itself when the stage is shorter than the panel, and nothing said so:
/// the panel just ended mid-card at the stage's edge. The lab keeps the stage's size (its circuit
/// and graph stay in view); when a scroll view inside it has more below, its bottom edge fades
/// and a round "more" button sits there, which scrolls it on (as does dragging it), so every
/// control is reachable on a board and on a phone.
class LabFrame extends StatefulWidget {
  const LabFrame({super.key, required this.child});
  final Widget child;
  @override
  State<LabFrame> createState() => _LabFrameState();
}

class _LabFrameState extends State<LabFrame> {
  /// The lab's scroll view that has more below (its panel), and where it is in this frame.
  ScrollPosition? _pos;
  Rect? _rect;
  bool _scheduled = false;

  bool _onScroll(Notification n) {
    if (n is! ScrollNotification && n is! ScrollMetricsNotification) return false;
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) _measure();
      });
    }
    return false;
  }

  /// Finds the tallest vertical scroll view inside the lab that is not at its end.
  void _measure() {
    final frame = context.findRenderObject() as RenderBox?;
    if (frame == null || !frame.hasSize) return;
    ScrollPosition? best;
    Rect? bestRect;
    void visit(Element e) {
      if (e is StatefulElement && e.state is ScrollableState) {
        final st = e.state as ScrollableState;
        final p = st.position;
        final box = e.findRenderObject();
        if (p.axis == Axis.vertical && p.hasContentDimensions && p.extentAfter > 1 && box is RenderBox && box.hasSize && box.attached) {
          final r = box.localToGlobal(Offset.zero, ancestor: frame) & box.size;
          if (bestRect == null || r.height > bestRect!.height) {
            best = p;
            bestRect = r;
          }
        }
      }
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    if (best != _pos || bestRect != _rect) {
      setState(() {
        _pos = best;
        _rect = bestRect;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _rect, p = _pos;
    const fade = 120.0;
    return NotificationListener<Notification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (r != null && p != null) ...[
            Positioned(
              left: r.left,
              width: r.width,
              top: r.bottom - fade,
              height: fade,
              child: const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00141A1D), Color(0xE6141A1D)])),
                ),
              ),
            ),
            Positioned(
              left: r.left,
              width: r.width,
              top: r.bottom - 88,
              height: 72,
              child: Center(
                child: StageButton(
                  key: const ValueKey('labMore'),
                  icon: Icons.keyboard_double_arrow_down,
                  tooltip: 'More',
                  size: 72,
                  onPressed: () => p.animateTo((p.pixels + p.viewportDimension * 0.7).clamp(0.0, p.maxScrollExtent), duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A white rail panel with its heading and a column of children.
class RailPanel extends StatelessWidget {
  const RailPanel({super.key, required this.title, required this.children, this.gap = 28, this.trailing});
  final String title;
  final List<Widget> children;
  final double gap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ZPanel(
    padding: EdgeInsets.fromLTRB(context.narrow ? 32 : 44, 40, context.narrow ? 32 : 44, 40),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZSectionTitle(title, trailing: trailing),
        for (final c in children) ...[SizedBox(height: gap), c],
      ],
    ),
  );
}

/// Body text in a rail panel (14 px, secondary ink).
class RailNote extends StatelessWidget {
  const RailNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: zText(28, FontWeight.w400).copyWith(color: Z.ink2, height: 1.55));
}

/// A white content panel that fills its space and scrolls when the content is taller.
class ContentPanel extends StatelessWidget {
  const ContentPanel({super.key, required this.child, this.tag, this.center = false});
  final Widget child;
  final String? tag;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    return Container(
      decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 36 : 80, vertical: narrow ? 32 : 64),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: center ? (box.maxHeight - (narrow ? 64 : 128)).clamp(0, double.infinity) : 0),
            child: Align(
              alignment: center ? Alignment.centerLeft : Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tag != null) ...[ZTag(tag!), const SizedBox(height: 24)],
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
