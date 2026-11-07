import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../blocks/math_text.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'class_quiz_screen.dart';
import 'strings.dart';

enum ExplainerTab { watch, tryIt, story, like }

/// A Zynetix School explainer on the whole board: the misconception it clears ("Many people
/// think / Actually"), then four ways in: Watch it (a scene and a narration line per step, the
/// teacher taps Next), Try it (the mission), Story and It's like (an everyday analogy).
class ExplainerScreen extends StatefulWidget {
  const ExplainerScreen({super.key, required this.samples, required this.explainer, this.initialStep = 0, this.initialTab = ExplainerTab.watch});
  final ClassSamples samples;
  final ClassExplainer explainer;
  final int initialStep;
  final ExplainerTab initialTab;

  @override
  State<ExplainerScreen> createState() => _ExplainerScreenState();
}

class _ExplainerScreenState extends State<ExplainerScreen> {
  late int step = widget.initialStep;
  late ExplainerTab tab = widget.initialTab;

  ClassExplainer get e => widget.explainer;

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final narrow = context.narrow;
      final n = e.steps.length;
      final last = step == n - 1;
      return ClassScaffold(
        crumbs: [widget.samples.subject.t(l), widget.samples.year.t(l), e.chapter.t(l)],
        title: e.title.t(l),
        trailing: [
          if (!narrow && tab == ExplainerTab.watch) ...[
            Text(ct('stepOf', l, {'n': step + 1, 'm': n}), style: zText(28, FontWeight.w500).copyWith(color: Z.muted)),
            ZProgress(value: (step + 1) / n, width: 200),
          ],
        ],
        bottomLeft: [
          BigButton(key: const ValueKey('exBack'), icon: Icons.arrow_back, label: ct('back', l), filled: false, collapse: true, onPressed: step > 0 ? () => setState(() => step--) : null),
          if (!narrow) ...[
            OutlinedButton(
              onPressed: () {},
              child: Tooltip(message: ct('readAloud', l), child: const Icon(Icons.volume_up_outlined, size: 40)),
            ),
            OutlinedButton(
              onPressed: () {},
              child: Tooltip(message: ct('pen', l), child: const Icon(Icons.edit_outlined, size: 40)),
            ),
          ],
        ],
        bottomRight: [
          if (!narrow)
            BigButton(
              icon: Icons.how_to_reg_outlined,
              label: ct('quizThis', l),
              filled: false,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClassQuizScreen(samples: widget.samples))),
            ),
          BigButton(
            key: const ValueKey('exNext'),
            icon: Icons.arrow_forward,
            trailingIcon: true,
            label: last || narrow ? ct('next', l) : '${ct('next', l)}: ${e.steps[step + 1].title.t(l)}',
            onPressed: last ? null : () => setState(() => step++),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MythBanner(myth: e.myth.t(l), truth: e.truth.t(l), lang: l),
            SizedBox(height: narrow ? 20 : 28),
            _Tabs(value: tab, lang: l, onChanged: (t) => setState(() => tab = t)),
            SizedBox(height: narrow ? 20 : 28),
            Expanded(
              child: switch (tab) {
                ExplainerTab.watch => _watch(context, l),
                ExplainerTab.tryIt => _tryIt(context, l),
                ExplainerTab.story => _story(context, l),
                ExplainerTab.like => _like(context, l),
              },
            ),
          ],
        ),
      );
    },
  );

  Widget _stage(Widget child) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: Z.stage, borderRadius: BorderRadius.circular(Z.stageRadius)),
    child: child,
  );

  Widget _watch(BuildContext context, Lang l) {
    final s = e.steps[step];
    final narrow = context.narrow;
    final scene = _stage(CustomPaint(key: ValueKey('scene-${s.scene}'), painter: ScenePainter(s.scene, l), child: const SizedBox.expand()));
    final text = ZPanel(
      padding: EdgeInsets.all(narrow ? 32 : 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZTag(ct('stepOf', l, {'n': step + 1, 'm': e.steps.length})),
              const SizedBox(width: 20),
              Expanded(
                child: _Dots(count: e.steps.length, at: step),
              ),
            ],
          ),
          SizedBox(height: narrow ? 20 : 36),
          Text(s.title.t(l), style: zTitle(narrow ? 44 : 60)),
          SizedBox(height: narrow ? 16 : 28),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.record_voice_over_outlined, size: narrow ? 36 : 48, color: Z.primary),
                  ),
                  SizedBox(width: narrow ? 16 : 24),
                  Expanded(
                    child: Text(s.say.t(l), style: zText(narrow ? 32 : 42, FontWeight.w400).copyWith(color: Z.ink, height: 1.45)),
                  ),
                ],
              ),
            ),
          ),
          if (!narrow && e.examLink.en.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
              child: Row(
                children: [
                  Text('${ct('examLink', l)}  ', style: zText(30, FontWeight.w600).copyWith(color: Z.muted)),
                  Expanded(
                    child: MathText(e.examLink.t(l), style: zText(36, FontWeight.w500).copyWith(color: Z.ink)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    if (context.portrait) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: scene),
          const SizedBox(height: 20),
          Expanded(flex: 6, child: text),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 11, child: scene),
        const SizedBox(width: 32),
        Expanded(flex: 9, child: text),
      ],
    );
  }

  Widget _tryIt(BuildContext context, Lang l) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        flex: 11,
        child: _stage(CustomPaint(painter: ScenePainter('same-time', l, dropped: false), child: const SizedBox.expand())),
      ),
      const SizedBox(width: 32),
      Expanded(
        flex: 9,
        child: ZPanel(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZTag(ct('missionGoal', l)),
              const SizedBox(height: 24),
              Text(e.mission.t(l), style: zTitle(44)),
              const SizedBox(height: 28),
              for (final (i, m) in e.missionSteps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: i == 0 ? Z.primary : Z.segTrack,
                        child: Text('${i + 1}', style: zText(30, FontWeight.w700).copyWith(color: i == 0 ? Colors.white : Z.ink2)),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(m.t(l), style: zText(34, i == 0 ? FontWeight.w600 : FontWeight.w400).copyWith(color: i == 0 ? Z.ink : Z.ink2)),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(ct('predictFirst', l), style: zText(30, FontWeight.w500).copyWith(color: Z.muted)),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _story(BuildContext context, Lang l) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, f) in e.story.indexed) ...[
        if (i > 0) const SizedBox(width: 28),
        Expanded(
          child: ZPanel(
            padding: const EdgeInsets.all(36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}', style: zTitle(36).copyWith(color: Z.primary)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Z.highlight, borderRadius: BorderRadius.circular(Z.radius)),
                  child: Text('“${f.speech.t(l)}”', style: zTitle(40)),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Text(f.caption.t(l), style: zText(34, FontWeight.w400).copyWith(color: Z.ink2, height: 1.45)),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  Widget _like(BuildContext context, Lang l) => ZPanel(
    padding: const EdgeInsets.all(48),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(e.likeHeadline.t(l), style: zTitle(46)),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: Kicker(ct('everyday', l))),
            const SizedBox(width: 88),
            Expanded(child: Kicker(ct('inPhysics', l))),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final (a, b) in e.likePairs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(child: _Cell(a.t(l), Z.tile)),
                        const SizedBox(width: 24, child: Icon(Icons.arrow_forward, size: 40, color: Z.faint)),
                        const SizedBox(width: 64),
                        Expanded(child: _Cell(b.t(l), Z.tagBg)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 36, color: Z.muted),
            const SizedBox(width: 16),
            Expanded(
              child: Text('${ct('whereStops', l)}: ${e.likeLimits.t(l)}', style: zText(28, FontWeight.w400).copyWith(color: Z.muted, height: 1.4)),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Z.radius)),
    child: Text(text, style: zText(34, FontWeight.w500)),
  );
}

/// "Many people think" (struck out, red stripe) beside "Actually" (green).
class _MythBanner extends StatelessWidget {
  const _MythBanner({required this.myth, required this.truth, required this.lang});
  final String myth, truth;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    Widget half(String kicker, String body, Color stripe, Color bg, Color ink, IconData icon, bool strike) => Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Z.panelRadius)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 14, color: stripe),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: narrow ? 24 : 36, vertical: narrow ? 18 : 26),
                child: Row(
                  children: [
                    Icon(icon, size: narrow ? 40 : 56, color: stripe),
                    SizedBox(width: narrow ? 16 : 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Kicker(kicker, color: ink, size: narrow ? 24 : 30),
                          const SizedBox(height: 6),
                          Text(
                            body,
                            style: zText(
                              narrow ? 28 : 38,
                              FontWeight.w600,
                            ).copyWith(color: Z.ink, height: 1.3, decoration: strike ? TextDecoration.lineThrough : null, decorationColor: stripe.withValues(alpha: 0.7), decorationThickness: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final a = half(ct('manyThink', lang), myth, Z.trap, Z.trapBg, Z.trap, Icons.do_not_disturb_alt_outlined, true);
    final b = half(ct('actually', lang), truth, Z.correct, Z.correctBg, Z.correctLabel, Icons.lightbulb_outline, false);
    if (context.portrait) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 16), b]);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 4, child: a),
          const SizedBox(width: 28),
          Expanded(flex: 6, child: b),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.value, required this.lang, required this.onChanged});
  final ExplainerTab value;
  final Lang lang;
  final ValueChanged<ExplainerTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    final items = [
      (ExplainerTab.watch, Icons.play_circle_outline, ct('watch', lang)),
      (ExplainerTab.tryIt, Icons.touch_app_outlined, ct('tryIt', lang)),
      (ExplainerTab.story, Icons.auto_stories_outlined, ct('story', lang)),
      (ExplainerTab.like, Icons.compare_arrows, ct('itsLike', lang)),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: Row(
        children: [
          for (final (t, icon, label) in items)
            Expanded(
              child: Material(
                color: t == value ? Z.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(Z.radius),
                child: InkWell(
                  key: ValueKey('tab-${t.name}'),
                  borderRadius: BorderRadius.circular(Z.radius),
                  onTap: () => onChanged(t),
                  child: SizedBox(
                    height: narrow ? 84 : 96,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!narrow) ...[Icon(icon, size: 40, color: t == value ? Colors.white : Z.ink2), const SizedBox(width: 14)],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: zText(narrow ? 26 : 34, FontWeight.w600).copyWith(color: t == value ? Colors.white : Z.ink2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.at});
  final int count, at;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < count; i++)
        Container(
          margin: const EdgeInsets.only(right: 10),
          width: i == at ? 56 : 28,
          height: 14,
          decoration: BoxDecoration(color: i <= at ? Z.primary : Z.track, borderRadius: BorderRadius.circular(Z.pill)),
        ),
    ],
  );
}

/// The explainer scenes, drawn for the dark stage (after the SVG scenes of the Zynetix School
/// explainer): the Earth pulling inward, a heavy and a light ball dropped together, and the
/// strobe of a falling ball. Other scenes show their title until drawn.
class ScenePainter extends CustomPainter {
  ScenePainter(this.scene, this.lang, {this.dropped = true});
  final String scene;
  final Lang lang;
  final bool dropped;

  void _text(Canvas c, String s, Offset at, double size, Color color, {FontWeight w = FontWeight.w700, TextAlign align = TextAlign.center, double? maxWidth}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: ZFonts.inter, fontFamilyFallback: ZFonts.fallback, fontSize: size, fontWeight: w, color: color),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    final dx = align == TextAlign.center ? tp.width / 2 : 0.0;
    tp.paint(c, at - Offset(dx, tp.height / 2));
  }

  void _arrow(Canvas c, Offset a, Offset b, Color color, double w) {
    final p = Paint()
      ..color = color
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    c.drawLine(a, b, p);
    final d = (b - a) / (b - a).distance;
    final n = Offset(-d.dy, d.dx);
    final head = Path()
      ..moveTo(b.dx + d.dx * w, b.dy + d.dy * w)
      ..lineTo(b.dx - d.dx * w * 3 + n.dx * w * 2.2, b.dy - d.dy * w * 3 + n.dy * w * 2.2)
      ..lineTo(b.dx - d.dx * w * 3 - n.dx * w * 2.2, b.dy - d.dy * w * 3 - n.dy * w * 2.2)
      ..close();
    c.drawPath(head, Paint()..color = color);
  }

  void _ball(Canvas c, Offset o, double r, {double alpha = 1}) {
    c.drawCircle(o, r, Paint()..color = const Color(0xFF3A4A55).withValues(alpha: alpha));
    c.drawCircle(
      o,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = Z.onStage2.withValues(alpha: alpha),
    );
    for (final h in [const Offset(-0.32, -0.38), const Offset(0.18, -0.5), const Offset(-0.06, -0.02)]) {
      c.drawCircle(o + h * r, r * 0.13, Paint()..color = Z.stage.withValues(alpha: alpha));
    }
  }

  void _apple(Canvas c, Offset o, double r, {double alpha = 1}) {
    c.drawCircle(o, r, Paint()..color = Z.vermillion.withValues(alpha: alpha));
    c.drawLine(
      o - Offset(0, r),
      o - Offset(-r * 0.15, r * 1.45),
      Paint()
        ..color = const Color(0xFFB07A3B).withValues(alpha: alpha)
        ..strokeWidth = r * 0.14
        ..strokeCap = StrokeCap.round,
    );
    c.drawOval(Rect.fromCenter(center: o - Offset(-r * 0.45, r * 1.3), width: r * 0.8, height: r * 0.38), Paint()..color = Z.green.withValues(alpha: alpha));
  }

  @override
  void paint(Canvas c, Size size) {
    final u = math.min(size.width, size.height) / 100;
    switch (scene) {
      case 'earth':
        final o = Offset(size.width / 2, size.height * 0.55);
        final r = u * 28;
        c.drawCircle(o, r, Paint()..color = Z.blue);
        for (var k = 0; k < 8; k++) {
          final a = k * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a));
          _arrow(c, o + d * (r + u * 22), o + d * (r + u * 6), Z.stageAccent, u * 1.2);
        }
        c.drawCircle(o, u * 1.4, Paint()..color = Colors.white);
        _text(c, ct('gravity', lang), Offset(size.width * 0.16, size.height * 0.12), u * 6, Z.stageAccent);
        _text(c, ct('pullsCentre', lang), Offset(size.width * 0.16, size.height * 0.2), u * 3.6, Z.onStage2, w: FontWeight.w500, maxWidth: size.width * 0.3);
      case 'same-time' || 'strobe':
        final strobe = scene == 'strobe';
        final top = size.height * (strobe ? 0.12 : 0.22), ground = size.height * 0.84;
        final r = u * (strobe ? 4.5 : 6.5);
        // Ground and a metre scale.
        c.drawLine(
          Offset(size.width * 0.08, ground + r * 1.25),
          Offset(size.width * 0.92, ground + r * 1.25),
          Paint()
            ..color = Z.onStage2
            ..strokeWidth = u * 0.8,
        );
        final scale = Paint()
          ..color = Z.stageAxis
          ..strokeWidth = u * 0.4;
        for (var k = 0; k <= 10; k++) {
          final y = top + (ground - top) * k / 10;
          c.drawLine(Offset(size.width * 0.1, y), Offset(size.width * 0.1 + (k.isEven ? u * 4 : u * 2.2), y), scale);
        }
        // Equal-time snapshots: the distance grows as t².
        const shots = 6;
        double yAt(int k) => top + (ground - top) * (k * k) / ((shots - 1) * (shots - 1));
        if (strobe) {
          final x = size.width * 0.5;
          for (var k = 1; k < shots; k++) {
            final y = yAt(k);
            _apple(c, Offset(x, y), r, alpha: k == shots - 1 ? 1 : 0.55);
            _text(c, '${(k * 0.1).toStringAsFixed(1)} s', Offset(x + u * 14, y), u * 3.6, Z.onStage, align: TextAlign.left);
            _text(c, '≈ $k m/s', Offset(x + u * 32, y), u * 3.6, Z.stageAccent, align: TextAlign.left);
          }
          _text(c, ct('speedsUp', lang), Offset(size.width * 0.24, size.height * 0.3), u * 4.4, Z.onStage);
          _text(c, '+1 m/s / 0.1 s', Offset(size.width * 0.24, size.height * 0.38), u * 4, Z.stageAccent);
          break;
        }
        final xl = size.width * 0.36, xr = size.width * 0.66;
        _text(c, ct('heavy', lang), Offset(xl, size.height * 0.07), u * 4.2, Z.onStage);
        _text(c, ct('light', lang), Offset(xr, size.height * 0.07), u * 4.2, Z.onStage);
        // Snapshots at t = 0, 1, 1.5 and 2 (distance ∝ t², so the gaps grow); both land together.
        final fracs = dropped ? const [0.0, 0.25, 0.5625, 1.0] : const [0.0];
        for (final (k, f) in fracs.indexed) {
          final isLast = k == fracs.length - 1;
          final a = isLast ? 1.0 : 0.22 + 0.14 * k;
          final y = top + (ground - top) * f;
          _ball(c, Offset(xl, y), r * 1.25, alpha: a);
          _apple(c, Offset(xr, y), r * 0.8, alpha: a);
          if (k > 0) {
            // Same height at the same moment: a dashed level line between them.
            final dash = Paint()
              ..color = Z.stageAccent.withValues(alpha: isLast ? 1 : 0.45)
              ..strokeWidth = u * 0.5;
            for (var x = xl + r * 1.6; x < xr - r; x += u * 3) {
              c.drawLine(Offset(x, y), Offset(math.min(x + u * 1.6, xr - r), y), dash);
            }
          }
        }
        if (dropped) {
          _arrow(c, Offset(size.width * 0.86, size.height * 0.3), Offset(size.width * 0.86, size.height * 0.62), Z.stageAccent, u * 1.1);
          _text(c, 'g', Offset(size.width * 0.86 + u * 5, size.height * 0.46), u * 6, Z.stageAccent);
          _text(c, ct('tie', lang), Offset(size.width * 0.51, ground - u * 10), u * 6.5, Z.stageAccent, w: FontWeight.w800);
        }
      default:
        _text(c, scene, Offset(size.width / 2, size.height / 2), u * 6, Z.onStage2);
    }
  }

  @override
  bool shouldRepaint(ScenePainter old) => old.scene != scene || old.lang != lang || old.dropped != dropped;
}
