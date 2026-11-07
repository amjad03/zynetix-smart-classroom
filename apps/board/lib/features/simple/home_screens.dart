import 'package:flutter/material.dart';

import '../../engine/model.dart';
import '../combined/data.dart' show teachers;
import '../combined/kit.dart' show LangOf, ArtView, Art;
import 'kit.dart';

const _pad = 140.0;

/// 01 · First open: one question, the language, in two huge cards.
class FirstOpenScreen extends StatelessWidget {
  const FirstOpenScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Padding(
      padding: const EdgeInsets.fromLTRB(_pad, 70, _pad, 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Brand(),
          const Spacer(),
          Tag('Takes 1 minute', icon: Icons.timer_outlined, bg: S.mist, size: 32),
        ]),
        const SizedBox(height: 110),
        Text('Namaskara! ನಮಸ್ಕಾರ!', style: tx(44, c: S.eyebrow, w: FontWeight.w600)),
        const SizedBox(height: 20),
        Text('Let’s get your class ready.', style: hd(150)),
        const SizedBox(height: 28),
        Text('First, which language would you like? You can change it any time.', style: tx(46, c: S.body)),
        const SizedBox(height: 90),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _LangCard(bg: S.lavender, big: 'Aa', name: 'English', sub: 'Buttons, voice and help in English', on: true)),
            const SizedBox(width: 56),
            Expanded(child: _LangCard(bg: S.peach, big: 'ಅ', name: 'ಕನ್ನಡ', sub: 'ಬಟನ್‌ಗಳು, ಧ್ವನಿ ಮತ್ತು ಸಹಾಯ ಕನ್ನಡದಲ್ಲಿ', on: false)),
          ]),
        ),
        const SizedBox(height: 72),
        Row(children: [
          const StepProgress(step: 1, of: 3, dark: false, width: 460),
          const SizedBox(width: 60),
          Expanded(child: Text('Next: tap your name. No password needed.', style: tx(36, c: S.muted))),
          const BigButton('Continue in English', icon: null, trailing: Icons.arrow_forward_rounded, height: 170, size: 54),
        ]),
      ]),
    ),
  );
}

class _LangCard extends StatelessWidget {
  const _LangCard({required this.bg, required this.big, required this.name, required this.sub, required this.on});
  final Color bg;
  final String big, name, sub;
  final bool on;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(64),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(64),
      border: Border.all(color: on ? S.violet : Colors.transparent, width: 8),
      boxShadow: on ? S.shadow : null,
    ),
    child: Row(children: [
      Container(
        width: 260, height: 260,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(big, style: hd(130, l: big == 'ಅ' ? Lang.kn : Lang.en).copyWith(height: 1.2)),
      ),
      const SizedBox(width: 64),
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: hd(120, l: name == 'English' ? Lang.en : Lang.kn)),
          const SizedBox(height: 16),
          Text(sub, style: tx(38, c: S.cardText)),
        ]),
      ),
      on
          ? Container(width: 110, height: 110, decoration: const BoxDecoration(color: S.violet, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 76, color: Colors.white))
          : const ArrowChip(size: 110),
    ]),
  );
}

/// 02 · Who's teaching today: tap your own photo; no PIN unless the school turns it on.
class WhoTodayScreen extends StatelessWidget {
  const WhoTodayScreen({super.key});

  static const _bgs = [S.sky, S.mint, S.lavender, S.butter, S.peach];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Padding(
      padding: const EdgeInsets.fromLTRB(_pad, 70, _pad, 80),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Brand(),
          const SizedBox(width: 40),
          Text('Govt. PU College, Malleshwaram · Wednesday 4 November', style: tx(34, c: S.muted)),
          const Spacer(),
          Tag('English', icon: Icons.translate_rounded, bg: S.mist, size: 32),
        ]),
        const SizedBox(height: 90),
        Text('Good morning!', style: tx(44, c: S.eyebrow, w: FontWeight.w600)),
        const SizedBox(height: 16),
        Text('Who’s teaching today?', style: hd(140)),
        const SizedBox(height: 22),
        Text('Tap your photo. Your class for now opens with you.', style: tx(46)),
        const SizedBox(height: 72),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            const gap = 48.0;
            final w = (box.maxWidth - gap * 2) / 3, h = (box.maxHeight - gap) / 2;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final (i, t) in teachers.indexed)
                SizedBox(
                  width: w, height: h,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(52, 44, 44, 44),
                    decoration: BoxDecoration(color: _bgs[i], borderRadius: BorderRadius.circular(56)),
                    child: Stack(children: [
                      Row(children: [
                        Face(t.initials, t.color, size: 210, ring: Colors.white),
                        const SizedBox(width: 40),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(padding: const EdgeInsets.only(right: 70), child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(66))),
                            const SizedBox(height: 14),
                            Text(t.now.split(' · ').take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(36, c: S.cardText)),
                            const SizedBox(height: 18),
                            t.now.endsWith('now')
                                ? Tag('Class now', icon: Icons.circle, size: 28, fg: S.green)
                                : Tag('Class at ${t.now.split(' · ').last}', icon: Icons.schedule_rounded, size: 28),
                          ]),
                        ),
                      ]),
                      const Positioned(top: 0, right: 0, child: ArrowChip(size: 76)),
                    ]),
                  ),
                ),
              SizedBox(
                width: w, height: h,
                child: CustomPaint(
                  painter: _Dashed(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(52, 44, 44, 44),
                    child: Row(children: [
                      Container(
                        width: 220, height: 220,
                        decoration: const BoxDecoration(color: S.mist, shape: BoxShape.circle),
                        child: const Icon(Icons.person_add_alt_1_rounded, size: 110, color: S.violet),
                      ),
                      const SizedBox(width: 44),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Not you?', style: tx(36, c: S.muted, w: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('Add yourself', style: hd(72, c: S.violet)),
                          const SizedBox(height: 14),
                          Text('Your name and class. Under a minute.', style: tx(32, c: S.cardText)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ]);
          }),
        ),
        const SizedBox(height: 56),
        Row(children: [
          const SafeLine('No password to remember. Your school can add a PIN later if it wants one.', size: 36, c: S.body),
          const Spacer(),
          const StepProgress(step: 2, of: 3, dark: false, width: 400),
        ]),
      ]),
    ),
  );
}

class _Dashed extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(56));
    final p = Paint()..color = const Color(0xFFB9B2EE)..style = PaintingStyle.stroke..strokeWidth = 6;
    for (final m in (Path()..addRRect(r.deflate(3))).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 40) {
        canvas.drawPath(m.extractPath(d, d + 22), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => false;
}

/// 03 · Home. Simple by default: your class now and one big button, four big cards below.
/// [showAll] is the confident teacher's view (11); [tour] lays the voice guide over it (04).
class SimpleHome extends StatefulWidget {
  const SimpleHome({super.key, this.showAll = false, this.tour = false});
  final bool showAll, tour;
  @override
  State<SimpleHome> createState() => _SimpleHomeState();
}

class _SimpleHomeState extends State<SimpleHome> {
  final _start = GlobalKey();

  @override
  Widget build(BuildContext context) => LangOf(builder: (context, l) {
    final phone = MediaQuery.sizeOf(context).width < 1200;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        Positioned.fill(child: phone ? _phone(l) : (widget.showAll ? _all(l) : _board(l))),
        if (widget.tour) Positioned.fill(child: _Tour(target: _start)),
      ]),
    );
  });

  Widget _top(Lang l, {bool phone = false}) => Row(children: [
    Brand(size: phone ? 60 : 72),
    if (!phone) ...[
      const SizedBox(width: 40),
      Text(tr(l, 'Govt. PU College, Malleshwaram · Wed 4 Nov', 'ಸರ್ಕಾರಿ ಪಿಯು ಕಾಲೇಜು, ಮಲ್ಲೇಶ್ವರಂ · ಬುಧ 4 ನವೆಂಬರ್'), style: tx(32, c: S.muted)),
      const Spacer(),
      Tag(tr(l, 'Works without internet', 'ಇಂಟರ್ನೆಟ್ ಇಲ್ಲದೆಯೂ ಕೆಲಸ ಮಾಡುತ್ತದೆ'), icon: Icons.cloud_done_outlined, bg: S.greenSoft, fg: S.green, size: 30),
      const SizedBox(width: 20),
      Tag(l == Lang.kn ? 'English' : 'ಕನ್ನಡ', icon: Icons.translate_rounded, bg: S.mist, size: 30),
      const SizedBox(width: 20),
    ] else
      const Spacer(),
    Container(
      padding: EdgeInsets.fromLTRB(10, 10, phone ? 10 : 34, 10),
      decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Face(teachers.first.initials, teachers.first.color, size: phone ? 64 : 80),
        if (!phone) ...[const SizedBox(width: 18), Text(tr(l, 'Meera', 'ಮೀರಾ'), style: tx(34, c: S.ink, w: FontWeight.w600))],
      ]),
    ),
  ]);

  Widget _hello(Lang l, double size) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(tr(l, 'Good morning, Meera', 'ಶುಭೋದಯ, ಮೀರಾ'), style: tx(size * .36, c: S.eyebrow, w: FontWeight.w600)),
    SizedBox(height: size * .08),
    Text(tr(l, 'What are you teaching today?', 'ಇಂದು ಏನು ಕಲಿಸುತ್ತಿದ್ದೀರಿ?'), style: hd(size, l: l)),
  ]);

  Widget _startButton(Lang l, {double h = 200, double size = 64}) => KeyedSubtree(
    key: _start,
    child: BigButton(tr(l, 'Start my class', 'ನನ್ನ ತರಗತಿ ಪ್ರಾರಂಭಿಸಿ'), icon: Icons.play_arrow_rounded, height: h, size: size),
  );

  Widget _nowTag(Lang l, double size) =>
      Tag(tr(l, 'Your class now · 9:45 – 10:40', 'ಈಗ ನಿಮ್ಮ ತರಗತಿ · 9:45 – 10:40'), icon: Icons.circle, fg: S.green, bg: Colors.white, size: size);

  List<(Color, IconData, String, String, List<String>)> _four(Lang l) => [
    (S.lavender, Icons.slideshow_rounded, tr(l, 'Teach a lesson', 'ಪಾಠ ಮಾಡಿ'), tr(l, 'Any chapter, step by step', 'ಯಾವುದೇ ಅಧ್ಯಾಯ, ಹಂತ ಹಂತವಾಗಿ'), [tr(l, 'Step by step', 'ಹಂತ ಹಂತವಾಗಿ'), tr(l, 'With voice', 'ಧ್ವನಿಯೊಂದಿಗೆ')]),
    (S.peach, Icons.edit_rounded, tr(l, 'Write on the board', 'ಬೋರ್ಡ್‌ನಲ್ಲಿ ಬರೆಯಿರಿ'), tr(l, 'A clean board and a pen', 'ಖಾಲಿ ಬೋರ್ಡ್ ಮತ್ತು ಪೆನ್'), [tr(l, '4 colours', '4 ಬಣ್ಣಗಳು'), tr(l, 'Undo', 'ಹಿಂದಕ್ಕೆ')]),
    (S.mint, Icons.quiz_rounded, tr(l, 'Quiz the class', 'ತರಗತಿಗೆ ಪ್ರಶ್ನೆ ಕೇಳಿ'), tr(l, 'Ask, then tap who is right', 'ಕೇಳಿ, ಸರಿ ಉತ್ತರಕ್ಕೆ ಒತ್ತಿ'), [tr(l, 'Roll numbers', 'ರೋಲ್ ನಂಬರ್'), tr(l, '5 questions', '5 ಪ್ರಶ್ನೆಗಳು')]),
    (S.butter, Icons.view_in_ar_rounded, tr(l, 'Find a 3D model or lab', '3D ಮಾದರಿ, ಲ್ಯಾಬ್'), tr(l, 'Solar system, pendulum…', 'ಸೌರವ್ಯೂಹ, ಲೋಲಕ…'), [tr(l, '3D models', '3D ಮಾದರಿ'), tr(l, 'Labs', 'ಲ್ಯಾಬ್')]),
  ];

  Widget _bottom(Lang l, {required bool on, bool phone = false}) => Row(children: [
    BigSwitch(on: on, w: phone ? 100 : 132),
    SizedBox(width: phone ? 18 : 28),
    Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(l, 'Show all tools', 'ಎಲ್ಲಾ ಸಾಧನಗಳನ್ನು ತೋರಿಸಿ'), style: tx(phone ? 26 : 38, c: S.ink, w: FontWeight.w700, h: 1.15)),
        if (!phone) Text(tr(l, on ? 'On · everything is on this page' : 'For confident teachers. You can switch back any time.', on ? 'ಆನ್ · ಎಲ್ಲವೂ ಈ ಪುಟದಲ್ಲಿದೆ' : 'ಅನುಭವಿ ಶಿಕ್ಷಕರಿಗೆ. ಯಾವಾಗ ಬೇಕಾದರೂ ಹಿಂತಿರುಗಿಸಬಹುದು.'), style: tx(30, c: S.muted, h: 1.3)),
      ]),
    ),
    SizedBox(width: phone ? 16 : 40),
    HelpButton(lang: l, size: phone ? 28 : 40),
  ]);

  Widget _board(Lang l) => Padding(
    padding: const EdgeInsets.fromLTRB(_pad, 50, _pad, 44),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _top(l),
      const SizedBox(height: 44),
      _hello(l, 112),
      const SizedBox(height: 40),
      SizedBox(
        height: 500,
        child: Container(
          padding: const EdgeInsets.fromLTRB(72, 40, 72, 40),
          decoration: BoxDecoration(color: S.sky, borderRadius: BorderRadius.circular(64)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                _nowTag(l, 32),
                const SizedBox(height: 24),
                Text(tr(l, '1st PUC A · Physics', 'ಪ್ರಥಮ ಪಿಯುಸಿ A · ಭೌತಶಾಸ್ತ್ರ'), style: hd(104, l: l)),
                const SizedBox(height: 14),
                Text(tr(l, 'Gravitation · How g changes with height', 'ಗುರುತ್ವಾಕರ್ಷಣೆ · ಎತ್ತರದೊಂದಿಗೆ g ಹೇಗೆ ಬದಲಾಗುತ್ತದೆ'), style: tx(46, c: S.cardText)),
                const SizedBox(height: 24),
                Wrap(spacing: 14, children: [
                  Tag(tr(l, 'Topic 3 of 5', 'ವಿಷಯ 3 / 5'), size: 30),
                  Tag(tr(l, '35 minutes left', 'ಇನ್ನೂ 35 ನಿಮಿಷ'), icon: Icons.schedule_rounded, size: 30),
                  Tag(tr(l, 'Last time: up to step 2', 'ಕಳೆದ ಬಾರಿ: ಹಂತ 2 ರವರೆಗೆ'), icon: Icons.history_rounded, size: 30),
                ]),
              ]),
            ),
            const ArtView(Art.earth, color: S.ink, size: 300, opacity: .55),
            const SizedBox(width: 48),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              _startButton(l),
              const SizedBox(height: 22),
              Text(tr(l, 'Opens the lesson where you left off', 'ನೀವು ನಿಲ್ಲಿಸಿದಲ್ಲಿಂದ ಪಾಠ ತೆರೆಯುತ್ತದೆ'), style: tx(32, c: S.cardText)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 40),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, (bg, ic, t, s, _)) in _four(l).indexed) ...[
            if (i > 0) const SizedBox(width: 40),
            Expanded(child: PastelCard(bg: bg, icon: ic, title: t, sub: s, lang: l, titleSize: 60, iconSize: 104, subLines: 1, pad: 44)),
          ],
        ]),
      ),
      const SizedBox(height: 36),
      _bottom(l, on: false),
    ]),
  );

  Widget _all(Lang l) {
    final cards = [
      (S.sky, Icons.today_rounded, tr(l, 'Today', 'ಇಂದು'), 'Your timetable and what comes next', ['5 classes', 'Next at 10:55']),
      (S.lavender, Icons.slideshow_rounded, tr(l, 'Teach', 'ಪಾಠ'), 'Every chapter, step by step, with voice', ['Lessons', 'Videos', 'Explainers']),
      (S.peach, Icons.draw_rounded, tr(l, 'Smartboard', 'ಸ್ಮಾರ್ಟ್‌ಬೋರ್ಡ್'), 'Write, draw shapes, add a 3D model', ['Pen', 'Shapes', 'Pages']),
      (S.mint, Icons.groups_rounded, tr(l, 'Class tools', 'ತರಗತಿ ಸಾಧನಗಳು'), 'Quiz, timer, groups and attendance', ['Quiz', 'Timer', 'Groups', 'Attendance']),
      (S.butter, Icons.view_in_ar_rounded, tr(l, 'Library', 'ಗ್ರಂಥಾಲಯ'), '3D models, virtual labs and simulations', ['3D models', 'Labs', 'Simulations']),
      (S.pink, Icons.insights_rounded, tr(l, 'Reports', 'ವರದಿಗಳು'), 'How far each class has got, quiz results', ['Syllabus covered', 'Quiz results']),
      (S.mist, Icons.settings_rounded, tr(l, 'Settings', 'ಸೆಟ್ಟಿಂಗ್ಸ್'), 'Language, board size, voice, school PIN', ['Language', 'Text size', 'PIN']),
      (S.greenSoft, Icons.school_rounded, tr(l, 'Practice class', 'ಅಭ್ಯಾಸ ತರಗತಿ'), 'A 3-minute pretend class. Nothing is saved.', ['3 minutes', 'Safe to try']),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(_pad, 60, _pad, 60),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _top(l),
        const SizedBox(height: 48),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(l, 'Good morning, Meera', 'ಶುಭೋದಯ, ಮೀರಾ'), style: tx(40, c: S.eyebrow, w: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(tr(l, 'What do you need today?', 'ಇಂದು ನಿಮಗೆ ಏನು ಬೇಕು?'), style: hd(112, l: l)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(48, 24, 24, 24),
            decoration: BoxDecoration(color: S.sky, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(l, 'Your class now · 9:45', 'ಈಗ ನಿಮ್ಮ ತರಗತಿ · 9:45'), style: tx(28, c: S.green, w: FontWeight.w600)),
                Text(tr(l, '1st PUC A · Physics · Gravitation', 'ಪ್ರಥಮ ಪಿಯುಸಿ A · ಭೌತಶಾಸ್ತ್ರ'), style: tx(38, c: S.ink, w: FontWeight.w700, h: 1.2)),
              ]),
              const SizedBox(width: 36),
              _startButton(l, h: 130, size: 42),
            ]),
          ),
        ]),
        const SizedBox(height: 48),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            const gap = 36.0;
            final w = (box.maxWidth - gap * 3) / 4, h = (box.maxHeight - gap) / 2;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final (bg, ic, t, s, tags) in cards)
                SizedBox(width: w, height: h, child: PastelCard(bg: bg, icon: ic, title: t, sub: s, tags: tags, lang: l, titleSize: 58, compact: true)),
            ]);
          }),
        ),
        const SizedBox(height: 40),
        _bottom(l, on: true),
      ]),
    );
  }

  Widget _phone(Lang l) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _top(l, phone: true),
        const SizedBox(height: 44),
        _hello(l, 78),
        const SizedBox(height: 36),
        Container(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
          decoration: BoxDecoration(color: S.sky, borderRadius: BorderRadius.circular(48)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _nowTag(l, 24),
            const SizedBox(height: 24),
            Text(tr(l, '1st PUC A · Physics', 'ಪ್ರಥಮ ಪಿಯುಸಿ A · ಭೌತಶಾಸ್ತ್ರ'), style: hd(60, l: l)),
            const SizedBox(height: 10),
            Text(tr(l, 'Gravitation · How g changes with height', 'ಗುರುತ್ವಾಕರ್ಷಣೆ · ಎತ್ತರದೊಂದಿಗೆ g ಹೇಗೆ ಬದಲಾಗುತ್ತದೆ'), style: tx(30, c: S.cardText)),
            const SizedBox(height: 20),
            Wrap(spacing: 10, runSpacing: 10, children: [
              Tag(tr(l, 'Topic 3 of 5', 'ವಿಷಯ 3 / 5'), size: 24),
              Tag(tr(l, '35 minutes left', 'ಇನ್ನೂ 35 ನಿಮಿಷ'), icon: Icons.schedule_rounded, size: 24),
            ]),
            const SizedBox(height: 36),
            SizedBox(width: double.infinity, child: _startButton(l, h: 136, size: 42)),
          ]),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            const gap = 24.0;
            final w = (box.maxWidth - gap) / 2, h = (box.maxHeight - gap) / 2;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final (bg, ic, t, _, _) in _four(l))
                SizedBox(
                  width: w, height: h,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(40)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 84, height: 84,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                          child: Icon(ic, size: 48, color: S.ink),
                        ),
                        const Spacer(),
                        const ArrowChip(size: 56),
                      ]),
                      const Spacer(),
                      Text(t, maxLines: 2, overflow: TextOverflow.ellipsis, style: hd(40, l: l)),
                    ]),
                  ),
                ),
            ]);
          }),
        ),
        const SizedBox(height: 28),
        _bottom(l, on: false, phone: true),
      ]),
    ),
  );
}

/// 04 · The voice guide's first step: the screen dims, a spotlight and a pointing hand on the
/// one thing to tap, a big caption, the voice playing, Step 1 of 4, Skip and mute.
class _Tour extends StatefulWidget {
  const _Tour({required this.target});
  final GlobalKey target;
  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  Rect? _r;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final t = widget.target.currentContext?.findRenderObject() as RenderBox?;
      final me = context.findRenderObject() as RenderBox?;
      if (t == null || me == null || !mounted) return;
      setState(() => _r = me.globalToLocal(t.localToGlobal(Offset.zero)) & t.size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    if (r == null) return const SizedBox.shrink();
    final hole = r.inflate(28);
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _Spot(hole))),
      // Header over the dim.
      Positioned(
        left: 0, right: 0, top: 44,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(28, 16, 36, 16),
            decoration: BoxDecoration(color: const Color(0xFFFFC857), borderRadius: BorderRadius.circular(999)),
            child: Row(children: [
              const Icon(Icons.record_voice_over_rounded, size: 44, color: S.ink),
              const SizedBox(width: 16),
              Text('Your first class, with a guide', style: tx(36, c: S.ink, w: FontWeight.w700, h: 1.1)),
            ]),
          ),
        ]),
      ),
      // The pointing hand, its fingertip on the button.
      Positioned(
        left: r.center.dx - 40, top: r.bottom - 36,
        child: Transform.rotate(
          angle: -.35,
          child: const Icon(Icons.pan_tool_alt_rounded, size: 240, color: Colors.white, shadows: [Shadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10))]),
        ),
      ),
      // The caption bubble.
      Positioned(
        left: _pad, top: hole.bottom + 70, width: 1640,
        child: Container(
          padding: const EdgeInsets.fromLTRB(60, 52, 60, 52),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(56), boxShadow: S.shadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Step 1 of 4', style: tx(36, c: S.violet, w: FontWeight.w700, h: 1.1)),
              const SizedBox(width: 24),
              for (var i = 0; i < 4; i++)
                Container(margin: const EdgeInsets.only(right: 12), width: i == 0 ? 64 : 22, height: 22, decoration: BoxDecoration(color: i == 0 ? S.violet : S.line, borderRadius: BorderRadius.circular(99))),
              const Spacer(),
              const _Speaking(),
            ]),
            const SizedBox(height: 30),
            Text('Tap the big blue button to start your class.', style: hd(84)),
            const SizedBox(height: 18),
            Text('ನಿಮ್ಮ ತರಗತಿ ಪ್ರಾರಂಭಿಸಲು ದೊಡ್ಡ ನೀಲಿ ಬಟನ್ ಒತ್ತಿ.', style: tx(38, c: S.muted)),
            const SizedBox(height: 40),
            Row(children: [
              const BigButton('Mute voice', icon: Icons.volume_off_rounded, bg: S.mist, fg: S.ink, height: 120, size: 36, shadow: false),
              const SizedBox(width: 20),
              Container(
                height: 120,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(999)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: S.ink, borderRadius: BorderRadius.circular(999)),
                    child: Text('English', style: tx(34, c: Colors.white, w: FontWeight.w700, h: 1)),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text('ಕನ್ನಡ', style: tx(34, c: S.ink, w: FontWeight.w600, h: 1))),
                ]),
              ),
              const Spacer(),
              Text('Skip guide', style: tx(38, c: S.violet, w: FontWeight.w700).copyWith(decoration: TextDecoration.underline, decorationColor: S.violet)),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

class _Speaking extends StatelessWidget {
  const _Speaking();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 12, 30, 12),
    decoration: BoxDecoration(color: S.soft, borderRadius: BorderRadius.circular(999)),
    child: Row(children: [
      Container(width: 72, height: 72, decoration: const BoxDecoration(color: S.violet, shape: BoxShape.circle), child: const Icon(Icons.volume_up_rounded, size: 44, color: Colors.white)),
      const SizedBox(width: 18),
      for (final h in const <double>[18, 36, 52, 30, 44, 22, 40, 16])
        Container(margin: const EdgeInsets.only(right: 8), width: 9, height: h, decoration: BoxDecoration(color: S.violet, borderRadius: BorderRadius.circular(9))),
      const SizedBox(width: 10),
      Text('Voice is speaking', style: tx(30, c: S.violet, w: FontWeight.w600, h: 1)),
    ]),
  );
}

class _Spot extends CustomPainter {
  _Spot(this.hole);
  final Rect hole;
  @override
  void paint(Canvas canvas, Size s) {
    final rr = RRect.fromRectAndRadius(hole, Radius.circular(hole.height / 2));
    final dim = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & s), Path()..addRRect(rr));
    canvas.drawPath(dim, Paint()..color = const Color(0xE60B0D33));
    canvas.drawRRect(rr.inflate(8), Paint()..color = const Color(0x66FFC857)..style = PaintingStyle.stroke..strokeWidth = 28..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFC857)..style = PaintingStyle.stroke..strokeWidth = 10);
  }

  @override
  bool shouldRepaint(_Spot old) => old.hole != hole;
}
