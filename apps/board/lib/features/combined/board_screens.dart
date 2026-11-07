import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kinetix_ui/kinetix_ui.dart' show KxFonts;

import '../../blocks/math_text.dart';
import '../../core/theme.dart';
import 'kit.dart';

TextStyle hand(double s, Color c) => TextStyle(fontFamily: KxFonts.kalam, fontSize: s, color: c, height: 1.1);

/// The bar every teaching screen shares: the class, the lesson, the class clock and End class.
class TeachBar extends StatelessWidget {
  const TeachBar({super.key, required this.crumb, required this.title, required this.subj, this.extra = const [], this.clock = '18:24', this.left = '21 min left'});
  final String crumb, title, clock, left;
  final Subj subj;
  final List<Widget> extra;
  @override
  Widget build(BuildContext context) => Container(
    height: 156,
    padding: const EdgeInsets.symmetric(horizontal: 48),
    decoration: const BoxDecoration(color: Colors.white, boxShadow: P.shadow),
    child: Row(children: [
      Container(
        width: 92, height: 92,
        decoration: BoxDecoration(gradient: subj.grad, borderRadius: BorderRadius.circular(28)),
        child: Icon(subj.icon, size: 52, color: Colors.white),
      ),
      const SizedBox(width: 28),
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(crumb, style: bx(26, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(title, style: tt(42), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
      ...extra,
      const SizedBox(width: 24),
      Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(color: P.soft, borderRadius: BorderRadius.circular(32)),
        child: Row(children: [
          const Icon(Icons.timer_outlined, size: 40, color: P.ink2),
          const SizedBox(width: 14),
          Text(clock, style: tt(40)),
          const SizedBox(width: 16),
          Text(left, style: bx(26, P.muted)),
        ]),
      ),
      const SizedBox(width: 20),
      const PButton('End class', icon: Icons.stop_rounded, color: Color(0xFFC44D0B)),
    ]),
  );
}

/// The lesson flow bar: each step's planned minutes, the current one counting down.
class FlowBar extends StatelessWidget {
  const FlowBar({super.key, required this.steps, required this.current, this.dark = false, this.remain = '3:40'});
  final List<(String, int)> steps;
  final int current;
  final bool dark;
  final String remain;
  @override
  Widget build(BuildContext context) {
    final total = steps.fold<int>(0, (a, s) => a + s.$2);
    return Container(
      height: 136,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 22),
      decoration: BoxDecoration(color: dark ? const Color(0xFF0E1417) : Colors.white, boxShadow: dark ? null : P.shadow),
      child: Row(children: [
        Text('Lesson flow', style: bx(26, dark ? Colors.white60 : P.muted, FontWeight.w600)),
        const SizedBox(width: 28),
        Expanded(
          child: Row(children: [
            for (final (i, s) in steps.indexed)
              Expanded(
                flex: s.$2,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: i < current ? (dark ? const Color(0xFF1F3A2F) : const Color(0xFFDDF1E7)) : i == current ? P.primary : (dark ? const Color(0xFF1C2529) : P.soft),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: i == current ? [BoxShadow(color: P.primary.withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 8))] : null,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    if (i < current) const Icon(Icons.check, size: 30, color: Color(0xFF00875A)),
                    if (i < current) const SizedBox(width: 8),
                    Expanded(child: Text(s.$1, style: bx(24, i == current ? Colors.white : (dark ? Colors.white70 : P.ink2), FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(i == current ? remain : '${s.$2}′', style: bx(24, i == current ? Colors.white : (dark ? Colors.white54 : P.muted), FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 24),
        Text('$total min', style: bx(26, dark ? Colors.white60 : P.muted, FontWeight.w600)),
      ]),
    );
  }
}

const moleFlow = [('Hook', 3), ('Atomic mass', 5), ('Mole map', 5), ('The mole', 6), ('Explore', 6), ('Examples', 7), ('Quiz', 4), ('Exam', 4)];

/// 04 · The lesson player with a concept video inside the step-by-step lesson.
class LessonVideoScreen extends StatelessWidget {
  const LessonVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const s = Subj.chemistry;
    return Scaffold(
      backgroundColor: P.page,
      body: Column(children: [
        const TeachBar(
          crumb: '1st PUC B · Chemistry · Ch 1 Some Basic Concepts · Topic 4',
          title: 'Atomic mass, mole concept and percentage composition',
          subj: s,
          extra: [Pill('Step 5 of 18', icon: Icons.layers_outlined, color: P.ink2, size: 26), SizedBox(width: 16), Pill('Voice on', icon: Icons.record_voice_over_outlined, color: Color(0xFF00876A), size: 26)],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Expanded(child: _VideoStage()),
              const SizedBox(width: 40),
              SizedBox(
                width: 860,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(
                    child: PCard(
                      pad: const EdgeInsets.all(52),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Row(children: [ResBadge(Res.lesson), SizedBox(width: 12), Pill('Concept', color: Color(0xFF00876A), size: 24)]),
                        const SizedBox(height: 28),
                        Text('The mole', style: tt(64, P.ink, FontWeight.w700)),
                        const SizedBox(height: 16),
                        MathText(r'One mole contains exactly 6.02214076 × 10²³ elementary entities: the Avogadro constant, $N_A$.', style: bx(32, P.ink2, FontWeight.w400)),
                        const SizedBox(height: 36),
                        for (final (i, p) in [r'$n = m / M$', r'$N = n \times N_A$', 'Molar mass of H₂O = 18 g mol⁻¹'].indexed)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
                            decoration: BoxDecoration(
                              color: i < 2 ? s.tint : P.soft,
                              borderRadius: BorderRadius.circular(28),
                              border: i == 1 ? Border.all(color: s.a, width: 4) : null,
                            ),
                            child: Row(children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(color: i < 2 ? s.a : Colors.white, shape: BoxShape.circle, border: i < 2 ? null : Border.all(color: P.line, width: 3)),
                                alignment: Alignment.center,
                                child: Text('${i + 1}', style: tt(28, i < 2 ? Colors.white : P.muted)),
                              ),
                              const SizedBox(width: 24),
                              Expanded(child: i < 2 ? MathText(p, style: tt(40, P.ink)) : Text('Tap to reveal', style: bx(32, P.muted, FontWeight.w500))),
                            ]),
                          ),
                        const Spacer(),
                        Row(children: [
                          const Icon(Icons.graphic_eq, size: 40, color: Color(0xFF00876A)),
                          const SizedBox(width: 16),
                          Expanded(child: Text('“The number of moles is the mass divided by the molar mass…”', style: bx(28, P.muted, FontWeight.w400).copyWith(fontStyle: FontStyle.italic), maxLines: 2)),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Row(children: [
                    Expanded(child: PButton('Back', icon: Icons.arrow_back, filled: false, big: true)),
                    SizedBox(width: 24),
                    Expanded(flex: 2, child: PButton('Next point', icon: Icons.arrow_forward, big: true, color: Color(0xFF00876A))),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        const FlowBar(steps: moleFlow, current: 3, remain: '3:40'),
      ]),
    );
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Z.stage, borderRadius: BorderRadius.circular(P.rBig), boxShadow: P.shadowHi),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(44, 36, 44, 24),
        child: Row(children: [
          const ResBadge(Res.video),
          const SizedBox(width: 20),
          Expanded(child: Text('Zynetix School · Ep 9 · Mole concept and molar mass', style: bx(30, Colors.white, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Pill('Saved for offline', icon: Icons.download_done, color: const Color(0xFF3CC08E), bg: const Color(0x223CC08E), size: 24),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(fit: StackFit.expand, children: [
              const CustomPaint(painter: _PosterPainter()),
              Positioned(
                left: 64, top: 56,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('COUNTING BY WEIGHING', style: bx(28, const Color(0xFF8FE3C4), FontWeight.w700).copyWith(letterSpacing: 4)),
                  const SizedBox(height: 12),
                  Text('1 mol = 6.022 × 10²³', style: tt(96, Colors.white, FontWeight.w700)),
                  Text('particles, whatever the substance', style: bx(36, Colors.white70, FontWeight.w400)),
                ]),
              ),
              Center(
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .95), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 60, offset: Offset(0, 20))]),
                  child: const Icon(Icons.play_arrow_rounded, size: 140, color: Color(0xFF0A4B45)),
                ),
              ),
              Positioned(
                right: 40, bottom: 40,
                child: Container(
                  width: 600,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 40, offset: Offset(0, 16))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.pause_circle_filled, size: 44, color: Color(0xFFB07A00)),
                      const SizedBox(width: 14),
                      Text('Pause and think', style: tt(34, const Color(0xFF8A5A00))),
                    ]),
                    const SizedBox(height: 12),
                    Text('How many molecules are there in 36 g of water?', style: bx(32, P.ink, FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('The video stops here; the class answers first.', style: bx(26, P.muted, FontWeight.w400)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(44, 30, 44, 36),
        child: Column(children: [
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            const marks = [(.18, 'n = m/M'), (.42, 'N = n × N_A'), (.58, 'Pause and think'), (.8, 'Molar mass of H₂O')];
            return SizedBox(
              height: 100,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(left: 0, right: 0, top: 18, child: Container(height: 14, decoration: BoxDecoration(color: Z.stageTrack, borderRadius: BorderRadius.circular(7)))),
                Positioned(left: 0, top: 18, child: Container(width: w * .58, height: 14, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3CC08E), Color(0xFF00A07A)]), borderRadius: BorderRadius.circular(7)))),
                for (final (x, label) in marks) ...[
                  Positioned(left: w * x - 6, top: 10, child: Container(width: 12, height: 30, decoration: BoxDecoration(color: label.startsWith('Pause') ? Z.stageAccent : Colors.white, borderRadius: BorderRadius.circular(6)))),
                  Positioned(left: (w * x - 140).clamp(0, w - 280), top: 54, child: SizedBox(width: 280, child: Text(label, textAlign: TextAlign.center, style: bx(24, label.startsWith('Pause') ? Z.stageAccent : Colors.white70, FontWeight.w600), maxLines: 1))),
                ],
                Positioned(left: w * .58 - 18, top: 7, child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
              ]),
            );
          }),
          const SizedBox(height: 18),
          Row(children: [
            for (final i in [Icons.replay_10, Icons.play_arrow_rounded, Icons.forward_10])
              Container(
                margin: const EdgeInsets.only(right: 18),
                width: 88, height: 88,
                decoration: BoxDecoration(color: Z.stageButton, borderRadius: BorderRadius.circular(26)),
                child: Icon(i, size: 52, color: Colors.white),
              ),
            const SizedBox(width: 8),
            Text('Stops at each marker', style: bx(26, Colors.white70)),
            const Spacer(),
            for (final t in ['English', 'Captions', '1×'])
              Container(
                margin: const EdgeInsets.only(left: 14),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                decoration: BoxDecoration(color: Z.stagePill, borderRadius: BorderRadius.circular(999)),
                child: Text(t, style: bx(24, Colors.white, FontWeight.w600)),
              ),
          ]),
        ]),
      ),
    ]),
  );
}

class _PosterPainter extends CustomPainter {
  const _PosterPainter();
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..shader = const LinearGradient(colors: [Color(0xFF0B5A4E), Color(0xFF0A2E34), Color(0xFF101A2A)], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(Offset.zero & s));
    final rnd = math.Random(7);
    // A scale pan of particles on the right: counting by weighing.
    final cx = s.width * .74, base = s.height * .62;
    final beam = Paint()..color = Colors.white.withValues(alpha: .7)..strokeWidth = 8..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, base - 220), Offset(cx, base + 60), beam);
    canvas.drawLine(Offset(cx - 230, base - 200), Offset(cx + 230, base - 230), beam);
    canvas.drawLine(Offset(cx - 120, base + 60), Offset(cx + 120, base + 60), beam);
    for (final (px, py) in [(cx - 230, base - 200), (cx + 230, base - 230)]) {
      canvas.drawLine(Offset(px, py), Offset(px - 80, py + 120), beam..strokeWidth = 4);
      canvas.drawLine(Offset(px, py), Offset(px + 80, py + 120), beam);
      canvas.drawArc(Rect.fromCenter(center: Offset(px, py + 120), width: 200, height: 70), 0, math.pi, false, beam..strokeWidth = 8..style = PaintingStyle.stroke);
    }
    for (var i = 0; i < 26; i++) {
      final x = cx - 230 + (rnd.nextDouble() - .5) * 150, y = base - 80 - rnd.nextDouble() * 50;
      canvas.drawCircle(Offset(x, y), 13, Paint()..color = [const Color(0xFF3CC08E), const Color(0xFF56B4E9), const Color(0xFFF2A93B)][i % 3]);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 230, base - 130), width: 110, height: 70), const Radius.circular(12)), Paint()..color = const Color(0xFFE7EAE6));
    final tp = TextPainter(text: TextSpan(text: '18 g', style: zText(30, FontWeight.w700).copyWith(color: const Color(0xFF0A2E34))), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(cx + 230 - tp.width / 2, base - 130 - tp.height / 2));
    for (var i = 0; i < 60; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height), rnd.nextDouble() * 3 + 1, Paint()..color = Colors.white.withValues(alpha: .12));
    }
  }

  @override
  bool shouldRepaint(_PosterPainter o) => false;
}

/// 05 · The smartboard: an infinite whiteboard with the drawing tools, the subject kit of this
/// chapter, pages, recording and projector mode.
class CombinedBoardScreen extends StatelessWidget {
  const CombinedBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const s = Subj.physics;
    return Scaffold(
      backgroundColor: const Color(0xFFE9ECE7),
      body: Column(children: [
        TeachBar(
          crumb: '1st PUC A · Physics · Gravitation · Smartboard',
          title: 'How g changes with height and depth',
          subj: s,
          clock: '24:10',
          left: '31 min left',
          extra: [
            Container(
              height: 96,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(32)),
              child: Row(children: [
                Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFFD13F3F), shape: BoxShape.circle)),
                const SizedBox(width: 14),
                Text('Recording 12:40', style: bx(28, const Color(0xFFB12E2E), FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 20),
            Container(
              height: 96,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(color: P.soft, borderRadius: BorderRadius.circular(32)),
              child: Row(children: [
                const Icon(Icons.cast_connected, size: 40, color: P.primary),
                const SizedBox(width: 14),
                Text('Projector', style: bx(28, P.ink, FontWeight.w600)),
                const SizedBox(width: 16),
                Container(
                  width: 92, height: 52, padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: P.primary, borderRadius: BorderRadius.circular(26)),
                  alignment: Alignment.centerRight,
                  child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ),
              ]),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 32, 36, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const _ToolRail(),
              const SizedBox(width: 32),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(P.r), boxShadow: P.shadow),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    const Positioned.fill(child: CustomPaint(painter: _BoardPainter())),
                    Positioned(left: 120, top: 70, child: Text('g changes with height and depth', style: hand(80, const Color(0xFF1A3FB0)))),
                    Positioned(left: 1060, top: 300, child: Text('g′ = g (1 − 2h/R)', style: hand(72, const Color(0xFF15191C)))),
                    Positioned(left: 1060, top: 400, child: Text('height h ≪ R', style: hand(48, const Color(0xFF5B6369)))),
                    Positioned(left: 1060, top: 520, child: Text('g′ = g (1 − d/R)', style: hand(72, const Color(0xFF00875A)))),
                    Positioned(left: 1060, top: 620, child: Text('depth d · falls half as fast', style: hand(48, const Color(0xFF5B6369)))),
                    Positioned(left: 120, top: 900, child: Text('Nandi Hills, h ≈ 1.5 km →  g′ ≈ 9.795', style: hand(56, const Color(0xFFC44D0B)))),
                    // A 3D model dropped from the subject kit, selected.
                    Positioned(right: 60, bottom: 110, child: _Dropped()),
                    Positioned(
                      left: 28, bottom: 28,
                      child: Row(children: [
                        for (final i in [Icons.zoom_out, Icons.zoom_in])
                          Container(margin: const EdgeInsets.only(right: 12), width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: P.shadow), child: Icon(i, size: 40, color: P.ink2)),
                        Container(height: 80, padding: const EdgeInsets.symmetric(horizontal: 24), alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: P.shadow), child: Text('85% · infinite board', style: bx(26, P.ink2, FontWeight.w600))),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 32),
              const SizedBox(width: 640, child: _SubjectKit()),
            ]),
          ),
        ),
        const _PageStrip(),
      ]),
    );
  }
}

class _Dropped extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 600, height: 440,
    decoration: BoxDecoration(color: Z.stage, borderRadius: BorderRadius.circular(24), border: Border.all(color: P.primary, width: 5), boxShadow: P.shadowHi),
    child: Stack(children: [
      const Positioned.fill(child: CustomPaint(painter: _EarthPainter())),
      Positioned(left: 24, top: 20, child: Pill('3D · earth_layers', icon: Icons.view_in_ar, color: Colors.white, bg: Colors.white.withValues(alpha: .14), size: 22)),
      Positioned(right: 24, bottom: 20, child: Text('Turn · cut open · label', style: bx(22, Colors.white70))),
      for (final a in [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
        Align(alignment: a, child: Transform.translate(offset: Offset(a.x * 12, a.y * 12), child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: P.primary, width: 5), shape: BoxShape.circle)))),
    ]),
  );
}

class _EarthPainter extends CustomPainter {
  const _EarthPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width * .36, s.height / 2 + 10);
    final r = s.height * .32;
    final layers = [const Color(0xFF3A7BD5), const Color(0xFFB4652A), const Color(0xFFE8613C), const Color(0xFFF2A93B), const Color(0xFFFFE08A)];
    for (final (i, col) in layers.indexed) {
      canvas.drawCircle(c, r * (1 - i * .19), Paint()..color = col);
    }
    canvas.drawCircle(c.translate(-r * .35, -r * .35), r * .3, Paint()..color = Colors.white.withValues(alpha: .12));
    final lp = Paint()..color = Colors.white70..strokeWidth = 3;
    for (final (i, t) in ['Crust', 'Mantle', 'Outer core', 'Inner core'].indexed) {
      final y = c.dy - r * (1 - i * .19) + 18;
      canvas.drawLine(Offset(c.dx, y), Offset(c.dx + r + 30, y), lp);
      final tp = TextPainter(text: TextSpan(text: t, style: zText(22, FontWeight.w600).copyWith(color: Colors.white)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(c.dx + r + 38, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_EarthPainter o) => false;
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final dot = Paint()..color = const Color(0xFFD9DDD6);
    for (var x = 30.0; x < s.width; x += 60) {
      for (var y = 30.0; y < s.height; y += 60) {
        canvas.drawCircle(Offset(x, y), 2.5, dot);
      }
    }
    final rnd = math.Random(4);
    Path wobble(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts.skip(1)) {
        p.lineTo(q.dx + (rnd.nextDouble() - .5) * 3, q.dy + (rnd.nextDouble() - .5) * 3);
      }
      return p;
    }

    final ink = Paint()..color = const Color(0xFF1A3FB0)..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    // The earth, hand drawn.
    const c = Offset(520, 560);
    const r = 260.0;
    canvas.drawPath(wobble([for (var a = 0.0; a <= math.pi * 2 + .05; a += .05) c + Offset(math.cos(a), math.sin(a)) * (r + math.sin(a * 3) * 4)]), ink);
    canvas.drawCircle(c, 10, Paint()..color = const Color(0xFF1A3FB0));
    // Radius R.
    canvas.drawPath(wobble([c, c + const Offset(r, 0)]), ink..strokeWidth = 5);
    // Height h above the surface.
    final top = c + const Offset(0, -r);
    final p = top + const Offset(0, -150);
    final orange = Paint()..color = const Color(0xFFC44D0B)..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawPath(wobble([top, p]), orange);
    canvas.drawCircle(p, 22, Paint()..color = const Color(0xFFC44D0B));
    // Depth d below.
    final q = top + const Offset(0, 120);
    final green = Paint()..color = const Color(0xFF00875A)..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
    canvas.drawPath(wobble([top, q]), green);
    canvas.drawCircle(q, 18, Paint()..color = const Color(0xFF00875A));
    // Highlighter swash under the first formula.
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(1050, 360, 560, 34), const Radius.circular(17)), Paint()..color = const Color(0x66F0E442));
    // Arrow from the drawing to the formula.
    canvas.drawPath(wobble([p + const Offset(40, 0), const Offset(1030, 340)]), orange..strokeWidth = 4);
    canvas.drawPath(wobble([q + const Offset(40, 0), const Offset(1030, 560)]), green..strokeWidth = 4);
    TextPainter label(String t, Color col) => TextPainter(text: TextSpan(text: t, style: hand(52, col)), textDirection: TextDirection.ltr)..layout();
    label('R', const Color(0xFF1A3FB0)).paint(canvas, c + const Offset(r / 2 - 14, -64));
    label('h', const Color(0xFFC44D0B)).paint(canvas, top + const Offset(-56, -110));
    label('d', const Color(0xFF00875A)).paint(canvas, top + const Offset(-52, 30));
  }

  @override
  bool shouldRepaint(_BoardPainter o) => false;
}

class _ToolRail extends StatelessWidget {
  const _ToolRail();
  @override
  Widget build(BuildContext context) {
    final tools = [
      (Icons.edit, true), (Icons.border_color_outlined, false), (Icons.category_outlined, false), (Icons.auto_fix_normal_outlined, false),
      (Icons.straighten, false), (Icons.architecture, false), (Icons.title, false), (Icons.add_photo_alternate_outlined, false),
    ];
    return Container(
      width: 152,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(P.r), boxShadow: P.shadow),
      child: Column(children: [
        for (final (i, on) in tools)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            width: 104, height: 84,
            decoration: BoxDecoration(color: on ? P.primary : null, borderRadius: BorderRadius.circular(28)),
            child: Icon(i, size: 48, color: on ? Colors.white : P.ink2),
          ),
        const SizedBox(height: 4),
        for (final pair in [[const Color(0xFF1A3FB0), const Color(0xFF15191C)], [const Color(0xFFC44D0B), const Color(0xFF00875A)]])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final c in pair) Container(margin: const EdgeInsets.symmetric(horizontal: 6), width: 48, height: 48, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: c == const Color(0xFF1A3FB0) ? const Color(0xFF9DB6F5) : Colors.white, width: 6))),
            ]),
          ),
        const Spacer(),
        Container(width: 100, height: 3, color: const Color(0xFFE3E6E1)),
        const SizedBox(height: 16),
        Text('Physics', style: bx(22, P.muted, FontWeight.w600)),
        const SizedBox(height: 12),
        for (final i in [Icons.north_east, Icons.show_chart, Icons.electrical_services])
          Container(margin: const EdgeInsets.only(bottom: 10), width: 104, height: 76, decoration: BoxDecoration(color: Subj.physics.tint, borderRadius: BorderRadius.circular(24)), child: Icon(i, size: 44, color: Subj.physics.a)),
      ]),
    );
  }
}

class _SubjectKit extends StatelessWidget {
  const _SubjectKit();
  @override
  Widget build(BuildContext context) {
    Widget item(Res r, String t, String id, {bool on = false}) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 20, 16),
      decoration: BoxDecoration(color: on ? Subj.physics.tint : P.soft, borderRadius: BorderRadius.circular(24), border: on ? Border.all(color: P.primary, width: 3) : null),
      child: Row(children: [
        ResBadge(r, compact: true),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: bx(27, P.ink, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(id, style: bx(22, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Icon(on ? Icons.check_circle : Icons.add_circle_outline, size: 40, color: on ? P.primary : P.muted),
      ]),
    );
    Widget head(String t) => Padding(padding: const EdgeInsets.only(top: 10, bottom: 14), child: Text(t, style: bx(24, P.muted, FontWeight.w700).copyWith(letterSpacing: 1.5)));
    return PCard(
      pad: const EdgeInsets.fromLTRB(36, 36, 36, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.backpack_outlined, size: 44, color: P.primary),
          const SizedBox(width: 16),
          Expanded(child: Text('Subject kit', style: tt(38))),
          const Pill('Ch 7', size: 22),
        ]),
        const SizedBox(height: 6),
        Text('Drag onto the board, or tap +', style: bx(24, P.muted)),
        const SizedBox(height: 14),
        head('3D MODELS'),
        item(Res.model3d, 'Layers of the Earth', 'earth_layers · on the board', on: true),
        item(Res.model3d, 'Solar system', 'solar_system · Kepler’s laws'),
        item(Res.model3d, 'Globe', 'globe · satellites'),
        head('LABS & SIMULATIONS'),
        item(Res.lab, 'The simple pendulum', 'pendulum · measure g'),
        item(Res.sim, 'Simple pendulum explorer', 'lab.pendulum'),
        head('EXPLAINERS & VIDEOS'),
        item(Res.explainer, 'Gravity and falling', 'feather vs hammer · 6 scenes'),
        item(Res.practice, 'Exam questions on the board', '5 PYQs · NEET · JEE · KCET'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE3E6E1), width: 3)),
          child: Row(children: [
            const Icon(Icons.play_circle_outline, size: 40, color: Color(0xFFD55E00)),
            const SizedBox(width: 16),
            Expanded(child: Text('Concept videos for Gravitation are on the way', style: bx(24, P.muted), maxLines: 2)),
          ]),
        ),
      ]),
    );
  }
}

class _PageStrip extends StatelessWidget {
  const _PageStrip();
  @override
  Widget build(BuildContext context) {
    const pages = ['Recap', 'Title', 'Nandi Hills?', 'g at surface', 'Height & depth', 'Pendulum'];
    return Container(
      height: 168,
      padding: const EdgeInsets.fromLTRB(36, 22, 36, 22),
      child: Row(children: [
        for (final (i, p) in pages.indexed)
          Container(
            margin: const EdgeInsets.only(right: 20),
            width: 200,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: i == 4 ? P.primary : const Color(0xFFDDE1DA), width: i == 4 ? 5 : 2), boxShadow: i == 4 ? P.shadow : null),
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}', style: bx(22, i == 4 ? P.primary : P.muted, FontWeight.w700)),
              const Spacer(),
              Text(p, style: bx(22, P.ink2, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        Container(width: 120, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: P.line, width: 3)), child: const Icon(Icons.add, size: 52, color: P.ink2)),
        const Spacer(),
        for (final (i, t) in [(Icons.slideshow_outlined, 'Import PowerPoint'), (Icons.phone_android, 'Phone as remote'), (Icons.record_voice_over_outlined, 'Read aloud')])
          Container(
            margin: const EdgeInsets.only(left: 18),
            height: 96,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: P.shadow),
            child: Row(children: [Icon(i, size: 38, color: P.ink2), const SizedBox(width: 12), Text(t, style: bx(26, P.ink, FontWeight.w600))]),
          ),
      ]),
    );
  }
}

/// 11 · Projector / TV: the lesson as the students see it, no toolbars.
class ProjectorScreen extends StatelessWidget {
  const ProjectorScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Z.stage,
    body: Stack(children: [
      const Positioned.fill(child: CustomPaint(painter: _GraphPainter())),
      Positioned(
        left: 140, top: 110,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('GRAVITATION · TOPIC 3', style: bx(34, Z.stageAccent, FontWeight.w700).copyWith(letterSpacing: 5)),
          const SizedBox(height: 12),
          Text('How g changes with height and depth', style: tt(96, Colors.white, FontWeight.w700)),
        ]),
      ),
      Positioned(
        left: 140, right: 140, bottom: 100,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white.withValues(alpha: .12), width: 2)),
          child: Text('Inside the earth only the inner sphere pulls, so g grows in proportion to r. Outside, g falls as one over r squared, so it is greatest at the surface.', style: bx(48, Colors.white, FontWeight.w400).copyWith(height: 1.4)),
        ),
      ),
      Positioned(right: 140, top: 130, child: Text('Step 3 of 4', style: bx(34, Colors.white60, FontWeight.w600))),
    ]),
  );
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final o = Offset(s.width * .2, s.height * .72);
    final w = s.width * .6, h = s.height * .36;
    final axis = Paint()..color = Z.stageAxis..strokeWidth = 5;
    canvas.drawLine(o, o.translate(w + 40, 0), axis);
    canvas.drawLine(o, o.translate(0, -h - 40), axis);
    final rx = w * .32; // R on the axis
    final inside = Paint()..color = Z.green..strokeWidth = 12..strokeCap = StrokeCap.round;
    canvas.drawLine(o, o.translate(rx, -h), inside);
    final out = Path()..moveTo(o.dx + rx, o.dy - h);
    for (var x = rx; x <= w; x += 4) {
      out.lineTo(o.dx + x, o.dy - h * (rx / x) * (rx / x));
    }
    canvas.drawPath(out, Paint()..color = Z.sky..strokeWidth = 12..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawLine(o.translate(rx, 0), o.translate(rx, -h), Paint()..color = Colors.white24..strokeWidth = 4);
    canvas.drawCircle(o.translate(rx, -h), 22, Paint()..color = Z.stageAccent);
    void text(String t, Offset at, Color c, [double sz = 44]) {
      final tp = TextPainter(text: TextSpan(text: t, style: zText(sz, FontWeight.w600).copyWith(color: c)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, at);
    }

    text('g', o.translate(-70, -h - 50), Colors.white);
    text('r', o.translate(w + 50, -30), Colors.white);
    text('R', o.translate(rx - 14, 16), Colors.white);
    text('g ∝ r\ninside', o.translate(rx * .52, -h * .36), Z.green, 40);
    text('g ∝ 1/r²  (outside)', o.translate(rx * 1.6, -h * .55), Z.sky, 40);
    text('greatest at the surface', o.translate(rx + 36, -h - 60), Z.stageAccent, 38);
  }

  @override
  bool shouldRepaint(_GraphPainter o) => false;
}
