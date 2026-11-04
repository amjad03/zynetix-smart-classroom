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
    return LayoutBuilder(builder: (context, c) => FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(width: c.maxWidth * s, height: c.maxHeight * s, child: child),
        ));
  }
}

class _Scope extends InheritedWidget {
  const _Scope({required this.scale, required super.child});
  final double scale;
  @override
  bool updateShouldNotify(_Scope old) => old.scale != scale;
}
