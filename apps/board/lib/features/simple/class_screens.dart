import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kinetix_ui/kinetix_ui.dart' show KxFonts;

import 'kit.dart';

const _pad = 140.0;
const _stageA = Color(0xFF0E1033), _stageB = Color(0xFF1D2266);
const _sun = Color(0xFFFFC857);

BoxDecoration get _stage => const BoxDecoration(gradient: LinearGradient(colors: [_stageA, _stageB], begin: Alignment.topLeft, end: Alignment.bottomRight));

/// The lesson stage's content: Gravitation · how g changes with height (step 3 of 12).
class _GravityStep extends StatelessWidget {
  const _GravityStep();
  @override
  Widget build(BuildContext context) {
    const k = 1.0;
    return Row(children: [
      Expanded(
        flex: 11,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('How g changes with height', style: tx(44 * k, c: _sun, w: FontWeight.w600)),
          SizedBox(height: 20 * k),
          Text('Go higher, and g gets a little smaller.', style: hd(116 * k, c: Colors.white)),
          SizedBox(height: 56 * k),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 56 * k, vertical: 36 * k),
            decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(40 * k), border: Border.all(color: const Color(0x33FFFFFF), width: 3)),
            child: Text('g at height h  =  g × (1 − 2h ⁄ R)', style: tx(68 * k, c: Colors.white, w: FontWeight.w600, h: 1.2)),
          ),
          SizedBox(height: 52 * k),
          for (final b in ['On the ground, g is 9.8 m/s².', 'On Mount Everest, 8.8 km up, g is about 9.77 m/s².'])
            Padding(
              padding: EdgeInsets.only(bottom: 22 * k),
              child: Row(children: [
                Container(width: 22 * k, height: 22 * k, decoration: const BoxDecoration(color: _sun, shape: BoxShape.circle)),
                SizedBox(width: 28 * k),
                Expanded(child: Text(b, style: tx(50 * k, c: const Color(0xFFE6E8FF)))),
              ]),
            ),
        ]),
      ),
      SizedBox(width: 60 * k),
      Expanded(flex: 8, child: SizedBox.expand(child: CustomPaint(painter: _EarthPainter()))),
    ]);
  }
}

class _EarthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = math.min(s.width, s.height) * .3;
    final c = Offset(s.width * .5, s.height * .6);
    canvas.drawCircle(c, r * 1.15, Paint()..color = const Color(0x1A6FB6FF));
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(colors: [Color(0xFF6FB6FF), Color(0xFF2457E6), Color(0xFF14307F)], stops: [0, .6, 1], center: Alignment(-.3, -.4)).createShader(Rect.fromCircle(center: c, radius: r)));
    final land = Paint()..color = const Color(0x8C3FBF7F);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(-r * .3, -r * .2), width: r * .7, height: r * .45), land);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(r * .35, r * .3), width: r * .5, height: r * .35), land);
    // A ball high above, and the pull back towards the centre.
    final ball = c + Offset(0, -r * 1.55);
    canvas.drawCircle(ball, r * .1, Paint()..color = _sun);
    final arrow = Paint()..color = _sun..strokeWidth = 10..strokeCap = StrokeCap.round;
    final tip = c + Offset(0, -r * 1.12);
    canvas.drawLine(ball + Offset(0, r * .14), tip, arrow);
    canvas.drawLine(tip, tip + Offset(-r * .09, -r * .1), arrow);
    canvas.drawLine(tip, tip + Offset(r * .09, -r * .1), arrow);
    void label(String t, Offset at, [Color col = Colors.white]) {
      final p = TextPainter(text: TextSpan(text: t, style: tx(r * .2, c: col, w: FontWeight.w700, h: 1)), textDirection: TextDirection.ltr)..layout();
      p.paint(canvas, at - Offset(0, p.height / 2));
    }

    label('g', c + Offset(r * .08, -r * 1.3), _sun);
    label('h', c + Offset(-r * .36, -r * 1.3));
    canvas.drawLine(c + Offset(-r * .16, -r), c + Offset(-r * .16, -r * 1.55), Paint()..color = Colors.white70..strokeWidth = 4);
    canvas.drawLine(c, c + Offset(r * .7, r * .7), Paint()..color = Colors.white70..strokeWidth = 4);
    label('R', c + Offset(r * .42, r * .25));
  }

  @override
  bool shouldRepaint(_EarthPainter old) => false;
}

/// 05 · Practice class: a pretend lesson whose checklist ticks itself as the teacher tries things.
class PracticeClassScreen extends StatelessWidget {
  const PracticeClassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const tasks = [
      ('Open the lesson', 'Done. Well done!', true),
      ('Go to the next step', 'Done. You tapped Next.', true),
      ('Write one word on the board', 'Tap Write at the bottom, then write any word.', false),
      ('Quiz the class', 'Tap Quiz and pretend to mark a few roll numbers.', false),
      ('Finish class', 'Tap Finish class to see your summary.', false),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(_pad, 60, _pad, 60),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(44, 22, 22, 22),
            decoration: BoxDecoration(color: S.butter, borderRadius: BorderRadius.circular(999)),
            child: Row(children: [
              const Icon(Icons.school_rounded, size: 56, color: S.ink),
              const SizedBox(width: 20),
              Text('Practice class', style: hd(54)),
              const SizedBox(width: 28),
              Tag('3 minutes', icon: Icons.timer_outlined, size: 30),
              const SizedBox(width: 14),
              Tag('Nothing here is saved', icon: Icons.lock_open_rounded, size: 30),
              const Spacer(),
              const BigButton('Leave practice', icon: Icons.close_rounded, bg: Colors.white, fg: S.ink, height: 112, size: 34, shadow: false),
            ]),
          ),
          const SizedBox(height: 44),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Container(
                  decoration: _stage.copyWith(borderRadius: BorderRadius.circular(56)),
                  padding: const EdgeInsets.fromLTRB(72, 56, 72, 48),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Text('Pretend lesson · Why do things fall?', style: tx(38, c: const Color(0xFFC9CBE6), w: FontWeight.w600)),
                      const Spacer(),
                      const StepProgress(step: 2, of: 4, width: 380, size: 32),
                    ]),
                    const Spacer(),
                    Text('Everything falls towards the Earth.', style: hd(104, c: Colors.white)),
                    const SizedBox(height: 28),
                    Text('A stone and a leaf both fall down, never up. That pull is called gravity.', style: tx(46, c: const Color(0xFFE6E8FF))),
                    const Spacer(),
                    Row(children: [
                      const BigButton('Back', icon: Icons.arrow_back_rounded, bg: Color(0x26FFFFFF), height: 150, size: 44, shadow: false),
                      const Spacer(),
                      // The task in hand glows.
                      Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(46), boxShadow: const [BoxShadow(color: Color(0xAAFFC857), blurRadius: 50, spreadRadius: 6)]),
                        child: const ToolButton('Write', Icons.edit_rounded, bg: _sun, fg: S.ink, width: 240, height: 150),
                      ),
                      const SizedBox(width: 24),
                      const ToolButton('Quiz', Icons.quiz_rounded, width: 240, height: 150),
                      const Spacer(),
                      const BigButton('Next', trailing: Icons.arrow_forward_rounded, bg: S.violet, height: 150, size: 48),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(width: 48),
              SizedBox(
                width: 1000,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(60, 56, 60, 52),
                  decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(56)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your practice', style: hd(76)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Text('2 of 5 done', style: tx(36, c: S.green, w: FontWeight.w700)),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Container(
                          height: 18,
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(color: S.line, borderRadius: BorderRadius.circular(99)),
                          child: FractionallySizedBox(widthFactor: .4, child: Container(decoration: BoxDecoration(color: S.green, borderRadius: BorderRadius.circular(99)))),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 36),
                    for (final (i, (t, hint, done)) in tasks.indexed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                        decoration: BoxDecoration(
                          color: i == 2 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(36),
                          border: i == 2 ? Border.all(color: S.violet, width: 5) : null,
                          boxShadow: i == 2 ? S.shadowSoft : null,
                        ),
                        child: Row(children: [
                          Tick(done: done, now: i == 2, n: i + 1, size: 80),
                          const SizedBox(width: 30),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t, style: tx(42, c: done ? S.muted : S.ink, w: FontWeight.w700, h: 1.2).copyWith(decoration: done ? TextDecoration.lineThrough : null, decorationColor: S.muted)),
                              if (done || i == 2) Text(hint, style: tx(30, c: done ? S.green : S.violet, w: FontWeight.w500, h: 1.3)),
                            ]),
                          ),
                        ]),
                      ),
                    const Spacer(),
                    const SafeLine('You can’t break anything — this is just practice.', size: 36),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 06 · A lesson in simple class mode: the content big, a giant Back and Next, and three named
/// helpers (Write, Pause voice, Help). [help] opens the "What do I do now?" panel (07).
class SimpleLessonScreen extends StatelessWidget {
  const SimpleLessonScreen({super.key, this.help = false});
  final bool help;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(children: [
      Positioned.fill(
        child: Container(
          decoration: _stage,
          padding: const EdgeInsets.fromLTRB(_pad, 56, _pad, 56),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Brand(size: 64, dark: true),
              const SizedBox(width: 40),
              Text('1st PUC A · Physics · Gravitation', style: tx(36, c: const Color(0xFFC9CBE6), w: FontWeight.w600)),
              const Spacer(),
              const StepProgress(step: 3, of: 12, width: 640, size: 36),
              const SizedBox(width: 56),
              Tag('35 min left', icon: Icons.schedule_rounded, bg: const Color(0x26FFFFFF), fg: Colors.white, size: 30),
              const SizedBox(width: 18),
              Tag('Finish class', icon: Icons.flag_rounded, bg: const Color(0x26FFFFFF), fg: Colors.white, size: 30),
            ]),
            const SizedBox(height: 40),
            const Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: 40), child: _GravityStep())),
            Container(
              padding: const EdgeInsets.fromLTRB(28, 18, 40, 18),
              decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(999)),
              child: Row(children: [
                const Icon(Icons.volume_up_rounded, size: 46, color: _sun),
                const SizedBox(width: 22),
                Expanded(
                  child: Text('“As we go up, we move away from the Earth’s centre, so its pull gets a little weaker.”',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(36, c: const Color(0xFFE6E8FF), w: FontWeight.w500)),
                ),
              ]),
            ),
            const SizedBox(height: 40),
            Row(children: [
              const SizedBox(width: 640, child: BigButton('Back', icon: Icons.arrow_back_rounded, bg: Color(0x26FFFFFF), height: 190, size: 60, shadow: false)),
              const Spacer(),
              const ToolButton('Write', Icons.edit_rounded, width: 250, height: 190),
              const SizedBox(width: 24),
              const ToolButton('Pause voice', Icons.pause_rounded, width: 250, height: 190),
              const SizedBox(width: 24),
              ToolButton('Help', Icons.question_mark_rounded, width: 250, height: 190, bg: help ? Colors.white : const Color(0x1FFFFFFF), fg: help ? S.violet : Colors.white),
              const Spacer(),
              const SizedBox(width: 860, child: BigButton('Next', trailing: Icons.arrow_forward_rounded, bg: S.violet, height: 190, size: 68)),
            ]),
          ]),
        ),
      ),
      if (help) ...[
        const Positioned.fill(child: ColoredBox(color: Color(0x990B0D33))),
        const Positioned(top: 0, right: 0, bottom: 0, width: 1180, child: _HelpPanel()),
      ],
    ]),
  );
}

class _HelpPanel extends StatelessWidget {
  const _HelpPanel();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(80, 72, 80, 64),
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.horizontal(left: Radius.circular(72)), boxShadow: S.shadow),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 96, height: 96, decoration: const BoxDecoration(color: S.violet, shape: BoxShape.circle), child: const Icon(Icons.question_mark_rounded, size: 60, color: Colors.white)),
        const SizedBox(width: 28),
        Expanded(child: Text('What do I do now?', style: hd(80))),
        const BigButton('Close', icon: Icons.close_rounded, bg: S.mist, fg: S.ink, height: 112, size: 34, shadow: false),
      ]),
      const SizedBox(height: 52),
      Container(
        padding: const EdgeInsets.fromLTRB(56, 48, 56, 52),
        decoration: BoxDecoration(color: S.lavender, borderRadius: BorderRadius.circular(56)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your next step', style: tx(36, c: S.eyebrow, w: FontWeight.w600)),
          const SizedBox(height: 14),
          Text('Tap Next to show the next part of the lesson.', style: hd(76)),
          const SizedBox(height: 18),
          Text('You are on step 3 of 12. About 25 minutes to go.', style: tx(36, c: S.cardText)),
          const SizedBox(height: 40),
          const BigButton('Show me', icon: Icons.pan_tool_alt_rounded, bg: S.violet, height: 150, size: 46),
        ]),
      ),
      const SizedBox(height: 40),
      _row(Icons.undo_rounded, S.peach, 'Undo last action', 'You wrote “g” on the board', 'Undo'),
      const SizedBox(height: 24),
      _row(Icons.call_rounded, S.mint, 'Call for help', 'School office · Mr. Ramesh, ext. 204', 'Call'),
      const Spacer(),
      const SafeLine('You can’t break anything. Every action can be undone.', size: 36),
    ]),
  );

  Widget _row(IconData icon, Color bg, String t, String sub, String btn) => Container(
    padding: const EdgeInsets.fromLTRB(36, 30, 30, 30),
    decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(44)),
    child: Row(children: [
      Container(width: 104, height: 104, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(32)), child: Icon(icon, size: 56, color: S.ink)),
      const SizedBox(width: 32),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: tx(44, c: S.ink, w: FontWeight.w700, h: 1.2)),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(32, c: S.muted)),
        ]),
      ),
      BigButton(btn, icon: icon, bg: S.ink, height: 120, size: 36, shadow: false),
    ]),
  );
}

/// 08 · The simple whiteboard: a pen in four colours, eraser, Undo, Clear (asks first) and one
/// big "Add a 3D model or lab".
class SimpleBoardScreen extends StatelessWidget {
  const SimpleBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    TextStyle hand(double s, Color c) => TextStyle(fontFamily: KxFonts.kalam, fontSize: s, color: c, height: 1.1, fontWeight: FontWeight.w400);
    const ink = Color(0xFF1B1D2E), blue = Color(0xFF2457E6), red = Color(0xFFD7263D), green = Color(0xFF1F9D55);
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF8),
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _Strokes())),
        Positioned(left: 420, top: 330, child: Text('g = GM ⁄ R²', style: hand(190, ink))),
        Positioned(left: 440, top: 640, child: Text('Higher up  →  g smaller', style: hand(130, blue))),
        Positioned(left: 1880, top: 300, child: Text('Everest: 9.77', style: hand(110, green))),
        Positioned(
          left: _pad, top: 60, right: _pad,
          child: Row(children: [
            const BigButton('Back to the lesson', icon: Icons.arrow_back_rounded, height: 140, size: 44),
            const Spacer(),
            Tag('Board · page 1', icon: Icons.description_outlined, bg: S.mist, size: 32),
            const SizedBox(width: 24),
            const HelpButton(size: 36),
          ]),
        ),
        // Clear asks first.
        Positioned(
          left: 1077, bottom: 330, width: 840,
          child: Container(
            padding: const EdgeInsets.fromLTRB(52, 44, 44, 44),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), boxShadow: S.shadow, border: Border.all(color: S.line, width: 3)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Clear the whole board?', style: hd(60)),
              const SizedBox(height: 10),
              Text('Your writing goes away. You can still Undo it.', style: tx(34)),
              const SizedBox(height: 32),
              const Row(children: [
                BigButton('Keep it', bg: S.ink, height: 120, size: 38),
                SizedBox(width: 20),
                BigButton('Yes, clear', icon: Icons.delete_outline_rounded, bg: S.peach, fg: S.rust, height: 120, size: 38, shadow: false),
              ]),
            ]),
          ),
        ),
        Positioned(
          left: _pad, right: _pad, bottom: 60,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(60), boxShadow: S.shadow),
              child: Row(children: [
                for (final (n, c) in [('Black', ink), ('Blue', blue), ('Red', red), ('Green', green)]) ...[
                  ToolButton(n, Icons.circle, dot: c, bg: n == 'Black' ? S.soft : Colors.white, fg: S.ink, width: 190, height: 170, on: n == 'Black'),
                  const SizedBox(width: 12),
                ],
                Container(width: 3, height: 120, color: S.line, margin: const EdgeInsets.symmetric(horizontal: 14)),
                const ToolButton('Eraser', Icons.auto_fix_normal_rounded, bg: Colors.white, fg: S.ink, width: 190, height: 170),
                const SizedBox(width: 12),
                const ToolButton('Undo', Icons.undo_rounded, bg: Colors.white, fg: S.ink, width: 190, height: 170),
                const SizedBox(width: 12),
                const ToolButton('Clear', Icons.delete_outline_rounded, bg: S.peach, fg: S.rust, width: 190, height: 170, on: true),
              ]),
            ),
            const Spacer(),
            const BigButton('Add a 3D model or lab', icon: Icons.view_in_ar_rounded, bg: S.butter, fg: S.ink, height: 210, size: 50, shadow: true),
          ]),
        ),
      ]),
    );
  }
}

class _Strokes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final red = Paint()..color = const Color(0xFFD7263D)..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round;
    canvas.drawOval(const Rect.fromLTWH(1830, 268, 720, 196), red);
    final blue = Paint()..color = const Color(0xFF2457E6)..style = PaintingStyle.stroke..strokeWidth = 9..strokeCap = StrokeCap.round;
    final p = Path()..moveTo(430, 600)..quadraticBezierTo(900, 575, 1420, 598);
    canvas.drawPath(p, blue);
  }

  @override
  bool shouldRepaint(_Strokes old) => false;
}

/// 09 · Quiz the class: the question big, then tap the roll numbers who got it right.
class SimpleQuizScreen extends StatelessWidget {
  const SimpleQuizScreen({super.key});

  static const right = {1, 2, 4, 5, 8, 9, 11, 12, 14, 17, 18, 21, 23, 26, 27, 30, 33, 36};

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Padding(
      padding: const EdgeInsets.fromLTRB(_pad, 60, _pad, 60),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const BigButton('Back to the lesson', icon: Icons.arrow_back_rounded, bg: S.mist, fg: S.ink, height: 120, size: 36, shadow: false),
          const SizedBox(width: 40),
          Text('Quiz the class', style: hd(64)),
          const Spacer(),
          const StepProgress(step: 1, of: 5, dark: false, width: 420, size: 34),
        ]),
        const SizedBox(height: 52),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 1060,
              child: Container(
                padding: const EdgeInsets.fromLTRB(60, 56, 60, 56),
                decoration: BoxDecoration(color: S.lavender, borderRadius: BorderRadius.circular(56)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Read it out to the class', style: tx(34, c: S.eyebrow, w: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Text('You climb a tall mountain. What happens to g?', style: hd(84)),
                  const SizedBox(height: 44),
                  for (final (k, o) in [('A', 'It gets a little smaller'), ('B', 'It gets bigger'), ('C', 'It stays exactly the same'), ('D', 'It becomes zero')])
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.fromLTRB(20, 18, 28, 18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: Row(children: [
                        Container(width: 76, height: 76, decoration: const BoxDecoration(color: S.soft, shape: BoxShape.circle), alignment: Alignment.center, child: Text(k, style: tx(38, c: S.violet, w: FontWeight.w700, h: 1))),
                        const SizedBox(width: 26),
                        Text(o, style: tx(42, c: S.ink, w: FontWeight.w500, h: 1.2)),
                      ]),
                    ),
                  const Spacer(),
                  const Row(children: [
                    BigButton('Show the answer', icon: Icons.visibility_rounded, bg: Colors.white, fg: S.ink, height: 120, size: 36, shadow: false),
                    SizedBox(width: 20),
                    Flexible(child: Tag('Answer: A', icon: Icons.lock_outline_rounded, size: 30)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(width: 80),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tap the roll numbers who got it right', style: hd(72)),
                const SizedBox(height: 14),
                Text('Everyone you don’t tap counts as not right yet. Tap again to undo.', style: tx(38)),
                const SizedBox(height: 40),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    const gap = 20.0;
                    final w = (box.maxWidth - gap * 7) / 8, h = math.min(150.0, (box.maxHeight - gap * 4) / 5);
                    return Wrap(spacing: gap, runSpacing: gap, children: [
                      for (var n = 1; n <= 40; n++)
                        Container(
                          width: w, height: h,
                          decoration: BoxDecoration(
                            color: right.contains(n) ? S.mint : S.mist,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: right.contains(n) ? S.green : Colors.transparent, width: 4),
                          ),
                          child: Stack(children: [
                            Center(child: Text('$n', style: hd(64, c: right.contains(n) ? S.green : S.ink))),
                            if (right.contains(n)) const Positioned(top: 12, right: 12, child: Icon(Icons.check_circle_rounded, size: 40, color: S.green)),
                          ]),
                        ),
                    ]);
                  }),
                ),
                const SizedBox(height: 28),
                Row(children: [
                  Tag('18 got it right', icon: Icons.check_circle_rounded, bg: S.greenSoft, fg: S.green, size: 34),
                  const SizedBox(width: 16),
                  Tag('22 not yet', bg: S.mist, size: 34),
                  const Spacer(),
                  const SizedBox(width: 520, child: BigButton('Done', icon: Icons.check_rounded, bg: S.violet, height: 170, size: 56)),
                ]),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  );
}

/// 10 · Finish class: well done, three big ticks, and one button.
class FinishClassScreen extends StatelessWidget {
  const FinishClassScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _Confetti())),
      Padding(
        padding: const EdgeInsets.fromLTRB(_pad + 40, 80, _pad, 80),
        child: Row(children: [
          Expanded(
            flex: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 220, height: 220,
                decoration: const BoxDecoration(color: S.green, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x551F7A4D), blurRadius: 60, offset: Offset(0, 24))]),
                child: const Icon(Icons.check_rounded, size: 150, color: Colors.white),
              ),
              const SizedBox(height: 60),
              Text('Well done!', style: tx(54, c: S.eyebrow, w: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('Class finished.', style: hd(160)),
              const SizedBox(height: 24),
              Text('1st PUC A · Physics · 42 minutes', style: tx(48)),
              const SizedBox(height: 70),
              const SizedBox(width: 760, child: BigButton('Done', icon: Icons.check_rounded, height: 190, size: 64)),
              const SizedBox(height: 36),
              Text('Next: 2nd PUC A · Ray optics at 10:55', style: tx(38, c: S.muted)),
            ]),
          ),
          const SizedBox(width: 80),
          Expanded(
            flex: 11,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _tick(S.mint, 'Lesson covered', 'Gravitation · How g changes with height · all 12 steps', null),
              const SizedBox(height: 36),
              _tick(S.peach, 'Homework given', 'Textbook questions 8.3 and 8.5', 'Change'),
              const SizedBox(height: 36),
              _tick(S.sky, 'Attendance', '36 of 40 present · absent: 7, 15, 22, 31', 'Change'),
              const SizedBox(height: 44),
              const SafeLine('Saved on this board. It works without internet.', size: 34, c: S.muted),
            ]),
          ),
        ]),
      ),
    ]),
  );

  Widget _tick(Color bg, String t, String sub, String? edit) => Container(
    padding: const EdgeInsets.fromLTRB(48, 44, 40, 44),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(56)),
    child: Row(children: [
      const Tick(done: true, size: 120),
      const SizedBox(width: 40),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: hd(64)),
          const SizedBox(height: 8),
          Text(sub, style: tx(36, c: S.cardText)),
        ]),
      ),
      if (edit != null) ...[const SizedBox(width: 24), BigButton(edit, icon: Icons.edit_rounded, bg: Colors.white, fg: S.ink, height: 116, size: 34, shadow: false)],
    ]),
  );
}

class _Confetti extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final rnd = math.Random(7);
    const cols = [S.lavender, S.peach, S.mint, S.sky, S.butter, S.pink];
    for (var i = 0; i < 46; i++) {
      final x = rnd.nextDouble() * s.width, t = rnd.nextDouble();
      // Only along the top and bottom edges, clear of the words.
      final y = t < .5 ? t * s.height * .28 : s.height * (.86 + (t - .5) * .28);
      canvas.drawCircle(Offset(x, y), 12 + rnd.nextDouble() * 26, Paint()..color = cols[i % cols.length]);
    }
  }

  @override
  bool shouldRepaint(_Confetti old) => false;
}
