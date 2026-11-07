import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import 'data.dart';

/// The combined classroom (lessons + Zynetix School class tools + the KINETIX smartboard) in the
/// premium cut of the approved Option B tokens: the same page, stage, blue and Okabe–Ito data
/// colours, with layered soft shadows, a subject accent on hero cards and drawn subject art.
/// Sizes are layout-canvas units (two per design pixel), like the rest of the board.
abstract final class P {
  static const page = Z.page, ink = Z.ink, ink2 = Z.ink2, muted = Z.muted, line = Z.line, primary = Z.primary;
  static const rail = Color(0xFF101619);
  static const railItem = Color(0xFF1C2529);
  static const card = Colors.white;
  static const soft = Color(0xFFF6F7F4);
  static const r = 36.0, rBig = 48.0;

  /// Two layered shadows: a tight contact shadow and a wide ambient one.
  static const shadow = [
    BoxShadow(color: Color(0x0F15191C), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1415191C), blurRadius: 48, offset: Offset(0, 20)),
  ];
  static const shadowHi = [
    BoxShadow(color: Color(0x1415191C), blurRadius: 6, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x2915191C), blurRadius: 80, offset: Offset(0, 36)),
  ];
}

/// A subject's accent: hero gradients, the chapter art and its tags.
class Subj {
  const Subj(this.id, this.name, this.a, this.b, this.tint, this.icon, [this.kn]);
  final String id, name;
  final String? kn;
  final Color a, b, tint;
  final IconData icon;
  String label(Lang l) => l == Lang.kn && kn != null ? kn! : name;
  LinearGradient get grad => LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight);

  static const physics = Subj('physics', 'Physics', Color(0xFF2457E6), Color(0xFF0B2A7A), Color(0xFFE9EFFD), Icons.public, 'ಭೌತಶಾಸ್ತ್ರ');
  static const chemistry = Subj('chemistry', 'Chemistry', Color(0xFF00876A), Color(0xFF0A4B45), Color(0xFFE3F3EE), Icons.science_outlined, 'ರಸಾಯನಶಾಸ್ತ್ರ');
  static const maths = Subj('maths', 'Mathematics', Color(0xFF7A4FD6), Color(0xFF3B2580), Color(0xFFF0EAFB), Icons.functions, 'ಗಣಿತ');
  static const biology = Subj('biology', 'Biology', Color(0xFF3C9A3C), Color(0xFF1E5631), Color(0xFFE8F4E4), Icons.spa_outlined, 'ಜೀವಶಾಸ್ತ್ರ');
  static const cs = Subj('cs', 'Computer Science', Color(0xFFD55E00), Color(0xFF7A2E06), Color(0xFFFCEDE3), Icons.terminal, 'ಕಂಪ್ಯೂಟರ್ ವಿಜ್ಞಾನ');
}

/// The resource kinds a topic carries; each has one colour and one icon everywhere.
enum Res {
  lesson('Lesson', 'ಪಾಠ', Icons.slideshow_outlined, Color(0xFF2457E6)),
  video('Concept video', 'ವೀಡಿಯೊ', Icons.play_circle_outline, Color(0xFFD55E00)),
  interactive('Interactive', 'ಸಂವಾದ', Icons.touch_app_outlined, Color(0xFF0072B2)),
  sim('Simulation', 'ಸಿಮ್ಯುಲೇಶನ್', Icons.blur_circular, Color(0xFF009E73)),
  lab('Virtual lab', 'ವರ್ಚುವಲ್ ಲ್ಯಾಬ್', Icons.biotech_outlined, Color(0xFF00876A)),
  model3d('3D model', '3D ಮಾದರಿ', Icons.view_in_ar, Color(0xFF7A4FD6)),
  explainer('Explainer', 'ವಿವರಣೆ', Icons.auto_stories_outlined, Color(0xFFCC79A7)),
  practice('Exam practice', 'ಅಭ್ಯಾಸ', Icons.fact_check_outlined, Color(0xFFB07A00));

  const Res(this.en, this.kn, this.icon, this.color);
  final String en, kn;
  final IconData icon;
  final Color color;
  String label(Lang l) => l == Lang.kn ? kn : en;
}

String tr(Lang l, String en, String kn) => l == Lang.kn ? kn : en;

TextStyle tt(double s, [Color c = P.ink, FontWeight w = FontWeight.w600]) => zTitle(s, w).copyWith(color: c, height: 1.2);
TextStyle bx(double s, [Color c = P.ink, FontWeight w = FontWeight.w500]) => zText(s, w).copyWith(color: c, height: 1.35);

/// A white card with the layered shadow.
class PCard extends StatelessWidget {
  const PCard({super.key, required this.child, this.pad = const EdgeInsets.all(40), this.color = P.card, this.radius = P.r, this.high = false, this.gradient, this.border});
  final Widget child;
  final EdgeInsets pad;
  final Color color;
  final double radius;
  final bool high;
  final Gradient? gradient;
  final Color? border;
  @override
  Widget build(BuildContext context) => Container(
    padding: pad,
    decoration: BoxDecoration(
      color: gradient == null ? color : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: high ? P.shadowHi : P.shadow,
      border: border == null ? null : Border.all(color: border!, width: 3),
    ),
    child: child,
  );
}

/// A rounded label: a tag, a status, a count.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = P.primary, this.bg, this.icon, this.size = 24, this.solid = false});
  final String text;
  final Color color;
  final Color? bg;
  final IconData? icon;
  final double size;
  final bool solid;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size * .8, vertical: size * .36),
    decoration: BoxDecoration(color: solid ? color : (bg ?? color.withValues(alpha: .12)), borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: size * 1.25, color: solid ? Colors.white : color), SizedBox(width: size * .4)],
      Text(text, style: bx(size, solid ? Colors.white : color, FontWeight.w600)),
    ]),
  );
}

/// A resource badge: coloured icon square + label.
class ResBadge extends StatelessWidget {
  const ResBadge(this.res, {super.key, this.lang = Lang.en, this.compact = false, this.count});
  final Res res;
  final Lang lang;
  final bool compact;
  final int? count;
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Tooltip(
        message: res.en,
        child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: res.color.withValues(alpha: .12), borderRadius: BorderRadius.circular(18)),
          child: Icon(res.icon, size: 36, color: res.color),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 20, 7),
      decoration: BoxDecoration(color: res.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: res.color, shape: BoxShape.circle),
          child: Icon(res.icon, size: 23, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(count == null ? res.label(lang) : '${res.label(lang)} · $count', style: bx(23, Color.lerp(res.color, P.ink, .25)!, FontWeight.w600)),
      ]),
    );
  }
}

/// A primary or quiet button.
class PButton extends StatelessWidget {
  const PButton(this.label, {super.key, this.icon, this.filled = true, this.color = P.primary, this.onDark = false, this.big = false, this.onTap});
  final String label;
  final IconData? icon;
  final bool filled, onDark, big;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final h = big ? 120.0 : 96.0;
    final fg = filled ? (onDark ? color : Colors.white) : (onDark ? Colors.white : P.ink);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: big ? 52 : 40),
        decoration: BoxDecoration(
          color: filled ? (onDark ? Colors.white : color) : (onDark ? Colors.white.withValues(alpha: .14) : Colors.white),
          borderRadius: BorderRadius.circular(h / 2.6),
          border: filled ? null : Border.all(color: onDark ? Colors.white.withValues(alpha: .35) : P.line, width: 3),
          boxShadow: filled && !onDark ? [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 32, offset: const Offset(0, 14))] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: big ? 52 : 42, color: fg), const SizedBox(width: 18)],
          Text(label, style: bx(big ? 36 : 30, fg, FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// A section heading with an optional action on the right.
class SecHead extends StatelessWidget {
  const SecHead(this.text, {super.key, this.trailing, this.icon});
  final String text;
  final Widget? trailing;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Row(children: [
    if (icon != null) ...[Icon(icon, size: 40, color: P.primary), const SizedBox(width: 16)],
    Expanded(child: Text(text, style: tt(36), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ?trailing,
  ]);
}

/// The places in the app, in the order of the left rail.
enum Place { today, teach, board, tools, library, reports, settings }

/// The frame of every combined screen: the dark navigation rail (Today · Teach · Smartboard ·
/// Class tools · Library · Reports · Settings), a top bar with the screen's title and the class,
/// and the content. On a phone the rail becomes a bottom bar.
class Shell extends StatelessWidget {
  const Shell({super.key, required this.place, required this.title, this.crumb, required this.body, this.actions = const [], this.lang = Lang.en, this.padBody = true, this.who});
  final Teacher? who;
  final Place place;
  final String title;
  final String? crumb;
  final Widget body;
  final List<Widget> actions;
  final Lang lang;
  final bool padBody;

  static const rail = 248.0;

  static List<(Place, IconData, String, String)> items = [
    (Place.today, Icons.wb_sunny_outlined, 'Today', 'ಇಂದು'),
    (Place.teach, Icons.school_outlined, 'Teach', 'ಬೋಧನೆ'),
    (Place.board, Icons.draw_outlined, 'Smartboard', 'ಸ್ಮಾರ್ಟ್‌ಬೋರ್ಡ್'),
    (Place.tools, Icons.dashboard_customize_outlined, 'Class tools', 'ತರಗತಿ ಸಾಧನ'),
    (Place.library, Icons.collections_bookmark_outlined, 'Library', 'ಗ್ರಂಥಾಲಯ'),
    (Place.reports, Icons.insights_outlined, 'Reports', 'ವರದಿಗಳು'),
  ];

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 1200;
    if (phone) return _phone(context);
    return Scaffold(
      backgroundColor: P.page,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Rail(place: place, lang: lang, who: who ?? teachers.first),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(64, 44, 56, 0),
              child: SizedBox(
                height: 128,
                child: Row(children: [
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (crumb != null) Text(crumb!, style: bx(26, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(title, style: tt(52), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  for (final a in actions) ...[const SizedBox(width: 20), a],
                ]),
              ),
            ),
            Expanded(child: Padding(padding: padBody ? const EdgeInsets.fromLTRB(64, 36, 56, 52) : EdgeInsets.zero, child: body)),
          ]),
        ),
      ]),
    );
  }

  Widget _phone(BuildContext context) => Scaffold(
    backgroundColor: P.page,
    body: SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 28, 36, 8),
          child: Row(children: [
            const _Logo(size: 64),
            const SizedBox(width: 20),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (crumb != null) Text(crumb!, style: bx(24, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(title, style: tt(40), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const _Avatar(initials: 'KM', color: Color(0xFF2457E6), size: 72),
          ]),
        ),
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(32, 20, 32, 0), child: body)),
        Container(
          height: 132,
          decoration: const BoxDecoration(color: Colors.white, boxShadow: P.shadow),
          child: Row(children: [
            for (final (p, i, en, kn) in items.take(5))
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                    decoration: BoxDecoration(color: p == place ? Z.tagBg : null, borderRadius: BorderRadius.circular(999)),
                    child: Icon(i, size: 40, color: p == place ? P.primary : P.muted),
                  ),
                  const SizedBox(height: 6),
                  Text(tr(lang, en, kn), style: bx(20, p == place ? P.primary : P.muted, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
          ]),
        ),
      ]),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({this.size = 88});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF4F7BFF), Color(0xFF1A3FB0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(size * .3),
      boxShadow: [BoxShadow(color: const Color(0xFF2457E6).withValues(alpha: .45), blurRadius: 24, offset: const Offset(0, 8))],
    ),
    alignment: Alignment.center,
    child: Text('Z', style: tt(size * .56, Colors.white, FontWeight.w700)),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.color, this.size = 88});
  final String initials;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, .15)!, Color.lerp(color, Colors.black, .25)!], begin: Alignment.topLeft, end: Alignment.bottomRight)),
    alignment: Alignment.center,
    child: Text(initials, style: tt(size * .36, Colors.white)),
  );
}

/// A teacher's initials in a gradient disc.
Widget avatar(String initials, Color color, {double size = 88}) => _Avatar(initials: initials, color: color, size: size);

class _Rail extends StatelessWidget {
  const _Rail({required this.place, required this.lang, required this.who});
  final Teacher who;
  final Place place;
  final Lang lang;
  @override
  Widget build(BuildContext context) => Container(
    width: Shell.rail,
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF141C20), Color(0xFF0C1114)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
    ),
    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
    child: Column(children: [
      const _Logo(),
      const SizedBox(height: 14),
      Text('ZYNETIX', style: bx(22, Colors.white70, FontWeight.w700).copyWith(letterSpacing: 4)),
      const SizedBox(height: 44),
      for (final (p, i, en, kn) in Shell.items) _item(p, i, tr(lang, en, kn)),
      const Spacer(),
      _item(Place.settings, Icons.settings_outlined, tr(lang, 'Settings', 'ಸೆಟ್ಟಿಂಗ್ಸ್')),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(color: P.railItem, borderRadius: BorderRadius.circular(32)),
        child: Column(children: [
          _Avatar(initials: who.initials, color: who.color, size: 72),
          const SizedBox(height: 10),
          Text(who.name, style: bx(24, Colors.white, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(tr(lang, 'Sign out', 'ನಿರ್ಗಮಿಸಿ'), style: bx(22, Colors.white54), maxLines: 1),
        ]),
      ),
    ]),
  );

  Widget _item(Place p, IconData icon, String label) {
    final on = p == place;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 124,
      decoration: BoxDecoration(
        color: on ? null : Colors.transparent,
        gradient: on ? const LinearGradient(colors: [Color(0xFF3D6DF2), Color(0xFF2457E6)]) : null,
        borderRadius: BorderRadius.circular(32),
        boxShadow: on ? [BoxShadow(color: const Color(0xFF2457E6).withValues(alpha: .45), blurRadius: 30, offset: const Offset(0, 10))] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 46, color: on ? Colors.white : const Color(0xFF9AA6AC)),
        const SizedBox(height: 8),
        Text(label, style: bx(23, on ? Colors.white : const Color(0xFFB6BFC4), FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

/// A small ring that fills to [value] (0–1), with [center] inside.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, required this.size, this.color = P.primary, this.track = const Color(0x22FFFFFF), this.stroke = 16, this.center});
  final double value, size, stroke;
  final Color color, track;
  final Widget? center;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: CustomPaint(painter: _RingPainter(value, color, track, stroke), child: Center(child: center)),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.c, this.t, this.w);
  final double v, w;
  final Color c, t;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(w / 2, w / 2, size.width - w, size.height - w);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()..color = t..style = PaintingStyle.stroke..strokeWidth = w);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v;
}

/// Drawn subject art for hero cards and chapter tiles: orbits and a planet for gravitation,
/// a flask and molecule for chemistry, a pendulum, lens rays, an atom.
enum Art { orbit, pendulum, molecule, flask, lens, atom, wave, graph, earth, circuit }

class ArtView extends StatelessWidget {
  const ArtView(this.art, {super.key, this.color = Colors.white, this.size = 200, this.opacity = 1});
  final Art art;
  final Color color;
  final double size, opacity;
  @override
  Widget build(BuildContext context) => Opacity(opacity: opacity, child: SizedBox(width: size, height: size, child: CustomPaint(painter: _ArtPainter(art, color))));
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, this.c);
  final Art art;
  final Color c;
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, cx = w / 2, cy = s.height / 2;
    final line = Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = w * .022..strokeCap = StrokeCap.round;
    final thin = Paint()..color = c.withValues(alpha: c.a * .45)..style = PaintingStyle.stroke..strokeWidth = w * .012;
    final fill = Paint()..color = c;
    final soft = Paint()..color = c.withValues(alpha: c.a * .18);
    switch (art) {
      case Art.orbit:
        canvas.drawCircle(Offset(cx, cy), w * .16, Paint()..shader = RadialGradient(colors: [const Color(0xFFFFD68A), const Color(0xFFF2A93B)]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * .16)));
        canvas.drawCircle(Offset(cx, cy), w * .24, soft);
        for (final (rx, ry, a) in [(.44, .22, -.35), (.36, .16, .5)]) {
          canvas.save();
          canvas.translate(cx, cy);
          canvas.rotate(a);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * rx * 2, height: w * ry * 2), thin);
          canvas.drawCircle(Offset(w * rx, 0), w * .045, fill);
          canvas.restore();
        }
      case Art.earth:
        canvas.drawCircle(Offset(cx, cy), w * .4, soft);
        canvas.drawCircle(Offset(cx, cy), w * .4, line);
        canvas.drawCircle(Offset(cx, cy), w * .27, thin);
        canvas.drawCircle(Offset(cx, cy), w * .14, Paint()..color = const Color(0xFFF2A93B).withValues(alpha: c.a));
        canvas.drawLine(Offset(cx, cy), Offset(cx, cy - w * .4), thin);
        _arrow(canvas, Offset(cx + w * .3, cy - w * .44), Offset(cx + w * .18, cy - w * .3), line);
      case Art.pendulum:
        canvas.drawLine(Offset(w * .2, w * .12), Offset(w * .8, w * .12), line);
        canvas.drawLine(Offset(cx, w * .12), Offset(w * .66, w * .74), line);
        canvas.drawLine(Offset(cx, w * .12), Offset(cx, w * .8), thin);
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, w * .12), radius: w * .66), math.pi / 2 - .5, 1.0, false, thin);
        canvas.drawCircle(Offset(w * .66, w * .74), w * .08, fill);
      case Art.molecule:
        final o = Offset(cx, cy);
        final hs = [Offset(cx - w * .3, cy + w * .2), Offset(cx + w * .3, cy + w * .2)];
        for (final h in hs) {
          canvas.drawLine(o, h, line);
        }
        canvas.drawCircle(o, w * .17, Paint()..color = const Color(0xFFE8613C).withValues(alpha: c.a));
        for (final h in hs) {
          canvas.drawCircle(h, w * .11, fill);
        }
        canvas.drawCircle(o.translate(-w * .05, -w * .05), w * .05, Paint()..color = Colors.white.withValues(alpha: .5 * c.a));
      case Art.flask:
        final p = Path()
          ..moveTo(w * .4, w * .12)
          ..lineTo(w * .4, w * .38)
          ..lineTo(w * .18, w * .82)
          ..quadraticBezierTo(w * .16, w * .88, w * .24, w * .88)
          ..lineTo(w * .76, w * .88)
          ..quadraticBezierTo(w * .84, w * .88, w * .82, w * .82)
          ..lineTo(w * .6, w * .38)
          ..lineTo(w * .6, w * .12);
        final liquid = Path()
          ..moveTo(w * .29, w * .6)
          ..lineTo(w * .71, w * .6)
          ..lineTo(w * .82, w * .82)
          ..quadraticBezierTo(w * .84, w * .88, w * .76, w * .88)
          ..lineTo(w * .24, w * .88)
          ..quadraticBezierTo(w * .16, w * .88, w * .18, w * .82)
          ..close();
        canvas.drawPath(liquid, Paint()..color = const Color(0xFF3CC08E).withValues(alpha: .8 * c.a));
        canvas.drawPath(p, line);
        canvas.drawLine(Offset(w * .34, w * .12), Offset(w * .66, w * .12), line);
        for (final (x, y, r) in [(.45, .72, .035), (.58, .78, .025), (.52, .66, .02)]) {
          canvas.drawCircle(Offset(w * x, w * y), w * r, Paint()..color = Colors.white.withValues(alpha: .7 * c.a));
        }
      case Art.lens:
        final p = Path()
          ..moveTo(cx, w * .12)
          ..quadraticBezierTo(cx + w * .16, cy, cx, w * .88)
          ..quadraticBezierTo(cx - w * .16, cy, cx, w * .12);
        canvas.drawPath(p, soft);
        canvas.drawPath(p, line);
        for (final y in [.3, .5, .7]) {
          canvas.drawLine(Offset(w * .06, w * y), Offset(cx, w * y), thin);
          canvas.drawLine(Offset(cx, w * y), Offset(w * .9, w * (.5 + (.5 - y) * .6)), Paint()..color = const Color(0xFFF2A93B).withValues(alpha: c.a)..strokeWidth = w * .016);
        }
      case Art.atom:
        for (final a in [0.0, math.pi / 3, -math.pi / 3]) {
          canvas.save();
          canvas.translate(cx, cy);
          canvas.rotate(a);
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * .84, height: w * .3), thin);
          canvas.drawCircle(Offset(w * .42, 0), w * .035, fill);
          canvas.restore();
        }
        canvas.drawCircle(Offset(cx, cy), w * .09, Paint()..color = const Color(0xFFE8613C).withValues(alpha: c.a));
      case Art.wave:
        final p = Path()..moveTo(0, cy);
        for (var x = 0.0; x <= w; x += 2) {
          p.lineTo(x, cy - math.sin(x / w * math.pi * 4) * w * .22);
        }
        canvas.drawPath(p, line);
        canvas.drawLine(Offset(0, cy), Offset(w, cy), thin);
      case Art.graph:
        canvas.drawLine(Offset(w * .12, w * .1), Offset(w * .12, w * .88), line);
        canvas.drawLine(Offset(w * .12, w * .88), Offset(w * .92, w * .88), line);
        final p = Path()..moveTo(w * .12, w * .88);
        for (var t = 0.0; t <= 1; t += .02) {
          p.lineTo(w * (.12 + .78 * t), w * (.88 - .74 * t * t));
        }
        canvas.drawPath(p, Paint()..color = const Color(0xFFF2A93B).withValues(alpha: c.a)..style = PaintingStyle.stroke..strokeWidth = w * .024);
      case Art.circuit:
        final r = Rect.fromLTWH(w * .14, w * .22, w * .72, w * .56);
        canvas.drawRect(r, line);
        canvas.drawLine(Offset(w * .44, w * .16), Offset(w * .44, w * .28), line);
        canvas.drawLine(Offset(w * .52, w * .19), Offset(w * .52, w * .25), line);
        canvas.drawCircle(Offset(w * .5, w * .78), w * .08, Paint()..color = const Color(0xFFF0E442).withValues(alpha: c.a));
    }
  }

  void _arrow(Canvas c, Offset a, Offset b, Paint p) {
    c.drawLine(a, b, p);
    final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
    for (final d in [2.5, -2.5]) {
      c.drawLine(b, b + Offset(math.cos(ang + d), math.sin(ang + d)) * 14, p);
    }
  }

  @override
  bool shouldRepaint(_ArtPainter o) => o.art != art || o.c != c;
}

/// Soft circles behind hero content.
class Glow extends StatelessWidget {
  const Glow({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _GlowPainter(), size: Size.infinite),
  );
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawCircle(Offset(s.width * .92, s.height * .05), s.height * .7, Paint()..color = Colors.white.withValues(alpha: .07));
    canvas.drawCircle(Offset(s.width * .75, s.height * 1.1), s.height * .5, Paint()..color = Colors.white.withValues(alpha: .05));
  }

  @override
  bool shouldRepaint(_GlowPainter o) => false;
}

/// Reads the language from config and rebuilds when it changes.
class LangOf extends StatelessWidget {
  const LangOf({super.key, required this.builder});
  final Widget Function(BuildContext, Lang) builder;
  @override
  Widget build(BuildContext context) {
    final c = ServicesScope.of(context).config;
    return ListenableBuilder(listenable: c, builder: (context, _) => builder(context, c.lang));
  }
}

/// A horizontal progress bar with rounded ends.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color = P.primary, this.track = const Color(0xFFE6E9E4), this.height = 18, this.marker});
  final double value, height;
  final double? marker;
  final Color color, track;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SizedBox(
      height: height + (marker != null ? 16 : 0),
      child: Stack(alignment: Alignment.centerLeft, clipBehavior: Clip.none, children: [
        Container(height: height, decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height))),
        Container(width: c.maxWidth * value.clamp(0, 1), height: height, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, .25)!, color]), borderRadius: BorderRadius.circular(height))),
        if (marker != null) Positioned(left: c.maxWidth * marker! - 3, top: 0, bottom: 0, child: Container(width: 6, decoration: BoxDecoration(color: P.ink, borderRadius: BorderRadius.circular(3)))),
      ]),
    ),
  );
}
