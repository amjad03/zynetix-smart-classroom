import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Draws the app at [scale]: the screens are laid out on a canvas of (screen size / scale)
/// logical pixels and shrunk to fit, so a layout designed for a 75" board looks like a normal
/// app on a phone or tablet (scale 0.5: body text 17, buttons 48 high) and still fills any
/// screen size or orientation.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.scale, required this.child});
  final double scale;
  final Widget child;

  /// The scale in effect (1 outside a [UiScale]).
  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_Scope>()?.scale ?? 1;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (scale == 1) return _Scope(scale: 1, child: child);
    final size = mq.size / scale;
    return _Scope(
      scale: scale,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: MediaQuery(
            data: mq.copyWith(
              size: size,
              devicePixelRatio: mq.devicePixelRatio * scale,
              padding: mq.padding / scale,
              viewPadding: mq.viewPadding / scale,
              viewInsets: mq.viewInsets / scale,
              systemGestureInsets: mq.systemGestureInsets / scale,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Shows [child] (a WebView) at its real size inside a [UiScale]: web pages size themselves in
/// CSS pixels, so they are given the screen's own pixels instead of the scaled canvas.
class Unscaled extends StatelessWidget {
  const Unscaled({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = UiScale.of(context);
    if (s == 1) return child;
    return LayoutBuilder(
      builder: (context, c) => FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(width: c.maxWidth * s, height: c.maxHeight * s, child: child),
      ),
    );
  }
}

class _Scope extends InheritedWidget {
  const _Scope({required this.scale, required super.child});
  final double scale;
  @override
  bool updateShouldNotify(_Scope old) => old.scale != scale;
}

/// Shows [child] (a Kinetix lab, player or 3D viewer, designed in ordinary app pixels) near its
/// design size inside a [UiScale]. The board lays screens out at two canvas units per design
/// pixel, so a Kinetix widget placed straight on the canvas came out at half size: 7–10 px lab
/// text and 3D labels on a classroom board. Here it is magnified up to two canvas units per
/// pixel, as far as the space allows: it always keeps at least [minSize] logical pixels to lay
/// out in (its code editors and lab benches need that much), so on a phone it stays as it was.
class DesignPixels extends StatelessWidget {
  const DesignPixels({super.key, required this.child});
  final Widget child;

  /// Canvas units per design pixel (see `AppConfig.uiScale`).
  static const unitsPerPixel = 2.0;

  /// The least room a Kinetix widget is given, in its own pixels.
  static const minSize = Size(1000, 680);

  /// The magnification for a box of [box] canvas units: 1 to [unitsPerPixel].
  static double factorFor(Size box) => math.min(unitsPerPixel, math.min(box.width / minSize.width, box.height / minSize.height)).clamp(1.0, unitsPerPixel);

  @override
  Widget build(BuildContext context) {
    if (UiScale.of(context) == 1) return child;
    final mq = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        if (!c.hasBoundedWidth || !c.hasBoundedHeight) return child;
        final k = factorFor(c.biggest);
        if (k <= 1.001) return child;
        return FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: c.maxWidth / k,
            height: c.maxHeight / k,
            child: MediaQuery(
              data: mq.copyWith(
                size: mq.size / k,
                devicePixelRatio: mq.devicePixelRatio * k,
                padding: mq.padding / k,
                viewPadding: mq.viewPadding / k,
                viewInsets: mq.viewInsets / k,
                systemGestureInsets: mq.systemGestureInsets / k,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
