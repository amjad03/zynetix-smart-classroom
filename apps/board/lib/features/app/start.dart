import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../engine/model.dart';
import 'help.dart';
import 'home.dart';
import 'kit.dart';
import 'now.dart';
import 'school.dart';

const _pad = 140.0;

/// The app's first screen: first open (the language) → who's teaching → Home.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});
  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      if (!school.setUp) return const FirstOpenScreen();
      if (school.current == null) return const WhoTodayScreen();
      return const HomeScreen();
    },
  );
}

/// 01 · First open: one question, the language, in two huge cards.
class FirstOpenScreen extends StatelessWidget {
  const FirstOpenScreen({super.key});

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final s = ServicesScope.of(context);
      final phone = usePhoneLayout(context);
      void pick(Lang v) => s.config.setLang(v);
      final cards = [
        Press(key: const ValueKey('lang-en'), radius: 64, onTap: () => pick(Lang.en), child: _LangCard(bg: S.lavender, big: 'Aa', name: 'English', sub: 'Buttons, voice and help in English', on: l == Lang.en, phone: phone)),
        if (s.config.kannadaOffered)
          Press(key: const ValueKey('lang-kn'), radius: 64, onTap: () => pick(Lang.kn), child: _LangCard(bg: S.peach, big: 'ಅ', name: 'ಕನ್ನಡ', sub: 'ಬಟನ್‌ಗಳು, ಧ್ವನಿ ಮತ್ತು ಸಹಾಯ ಕನ್ನಡದಲ್ಲಿ', on: l == Lang.kn, phone: phone)),
      ];
      final go = ZxButton(
        tr(l, 'Continue in English', 'ಕನ್ನಡದಲ್ಲಿ ಮುಂದುವರಿಸಿ'),
        key: const ValueKey('continue'),
        trailing: Icons.arrow_forward_rounded,
        height: phone ? 130 : 170,
        size: phone ? 40 : 54,
        shadow: true,
        onTap: school.finishSetUp,
      );
      final help = HelpInfo(next: const L10n('Tap your language, then tap Continue.', 'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಒತ್ತಿ, ನಂತರ ಮುಂದುವರಿಸಿ ಒತ್ತಿ.'));
      if (phone) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(40, 36, 40, 36), children: [
              Row(children: [const Brand(size: 60), const Spacer(), HelpChip(info: () => help)]),
              const SizedBox(height: 60),
              Text('Namaskara! ನಮಸ್ಕಾರ!', style: tx(34, c: S.eyebrow, w: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(tr(l, 'Let’s get your class ready.', 'ನಿಮ್ಮ ತರಗತಿಯನ್ನು ಸಿದ್ಧಮಾಡೋಣ.'), style: hd(84, l: l)),
              const SizedBox(height: 20),
              Text(tr(l, 'First, which language would you like? You can change it any time.', 'ಮೊದಲು, ನಿಮಗೆ ಯಾವ ಭಾಷೆ ಬೇಕು? ಯಾವಾಗ ಬೇಕಾದರೂ ಬದಲಾಯಿಸಬಹುದು.'), style: tx(34)),
              const SizedBox(height: 48),
              for (final c in cards) ...[SizedBox(height: 300, child: c), const SizedBox(height: 28)],
              const SizedBox(height: 20),
              go,
            ]),
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.white,
        body: DesignCanvas(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_pad, 70, _pad, 80),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Brand(),
                const Spacer(),
                Tag(tr(l, 'Takes 1 minute', '1 ನಿಮಿಷ ಸಾಕು'), icon: Icons.timer_outlined, bg: S.mist, size: 32),
              ]),
              const SizedBox(height: 110),
              Text('Namaskara! ನಮಸ್ಕಾರ!', style: tx(44, c: S.eyebrow, w: FontWeight.w600)),
              const SizedBox(height: 20),
              Text(tr(l, 'Let’s get your class ready.', 'ನಿಮ್ಮ ತರಗತಿಯನ್ನು ಸಿದ್ಧಮಾಡೋಣ.'), maxLines: 1, style: hd(150, l: l)),
              const SizedBox(height: 28),
              Text(tr(l, 'First, which language would you like? You can change it any time.', 'ಮೊದಲು, ನಿಮಗೆ ಯಾವ ಭಾಷೆ ಬೇಕು? ಯಾವಾಗ ಬೇಕಾದರೂ ಬದಲಾಯಿಸಬಹುದು.'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(46, c: S.body)),
              const SizedBox(height: 90),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(width: 56), Expanded(child: c)],
                ]),
              ),
              const SizedBox(height: 72),
              Row(children: [
                StepProgress(step: 1, of: 3, dark: false, width: 460, lang: l),
                const SizedBox(width: 60),
                Expanded(child: Text(tr(l, 'Next: tap your name. No password needed.', 'ಮುಂದೆ: ನಿಮ್ಮ ಹೆಸರನ್ನು ಒತ್ತಿ. ಪಾಸ್‌ವರ್ಡ್ ಬೇಡ.'), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(36, c: S.muted))),
                go,
              ]),
            ]),
          ),
        ),
      );
    },
  );
}

class _LangCard extends StatelessWidget {
  const _LangCard({required this.bg, required this.big, required this.name, required this.sub, required this.on, this.phone = false});
  final Color bg;
  final String big, name, sub;
  final bool on, phone;
  @override
  Widget build(BuildContext context) {
    final k = phone ? .55 : 1.0;
    return Container(
      padding: EdgeInsets.all(64 * k),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(64),
        border: Border.all(color: on ? S.violet : Colors.transparent, width: 8),
        boxShadow: on ? S.shadow : null,
      ),
      child: Row(children: [
        Container(
          width: 260 * k, height: 260 * k,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(big, style: hd(130 * k, l: big == 'ಅ' ? Lang.kn : Lang.en).copyWith(height: 1.2)),
        ),
        SizedBox(width: 64 * k),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(120 * k, l: name == 'English' ? Lang.en : Lang.kn))),
            SizedBox(height: 16 * k),
            Flexible(child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(38 * k, c: S.cardText))),
          ]),
        ),
        on
            ? Container(width: 110 * k, height: 110 * k, decoration: const BoxDecoration(color: S.violet, shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 76 * k, color: Colors.white))
            : ArrowChip(size: 110 * k),
      ]),
    );
  }
}

/// 02 · Who's teaching today: tap your own card; no PIN unless the school turns it on.
class WhoTodayScreen extends StatelessWidget {
  const WhoTodayScreen({super.key});

  static const _bgs = [S.sky, S.mint, S.lavender, S.butter, S.peach, S.pink];

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final s = ServicesScope.of(context);
      final phone = usePhoneLayout(context);
      final now = s.clock();
      final teachers = school.teachers;

      Widget card(int i, Teacher t, {double k = 1}) {
        final p = school.classNow(teacherId: t.id, at: now);
        final mins = now.hour * 60 + now.minute;
        final on = p != null && p.startMin <= mins;
        return Press(
          key: ValueKey('teacher-${t.id}'),
          radius: 56,
          onTap: () => signInAs(context, t),
          child: Container(
            padding: EdgeInsets.fromLTRB(52 * k, 44 * k, 44 * k, 44 * k),
            decoration: BoxDecoration(color: _bgs[i % _bgs.length], borderRadius: BorderRadius.circular(56)),
            child: Stack(children: [
              Row(children: [
                teacherFace(t, size: 210 * k, ring: Colors.white),
                SizedBox(width: 40 * k),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Flexible(child: Padding(padding: EdgeInsets.only(right: 70 * k), child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(66 * k)))),
                    if (p != null) ...[
                      SizedBox(height: 14 * k),
                      Flexible(child: Text(classLine(s, p.subject, l, period: p), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(36 * k, c: S.cardText))),
                      SizedBox(height: 18 * k),
                      on
                          ? Tag(tr(l, 'Class now', 'ಈಗ ತರಗತಿ'), icon: Icons.circle, size: 28 * k, fg: S.green)
                          : Tag(tr(l, 'Class at ${Period.clock(p.start)}', '${Period.clock(p.start)}ಕ್ಕೆ ತರಗತಿ'), icon: Icons.schedule_rounded, size: 28 * k),
                    ],
                  ]),
                ),
              ]),
              Positioned(top: 0, right: 0, child: ArrowChip(size: 76 * k)),
            ]),
          ),
        );
      }

      Widget add({double k = 1}) => Press(
        key: const ValueKey('addTeacher'),
        radius: 56,
        onTap: () => addTeacherDialog(context),
        child: CustomPaint(
          painter: _Dashed(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(52 * k, 44 * k, 44 * k, 44 * k),
            child: Row(children: [
              Container(
                width: 220 * k, height: 220 * k,
                decoration: const BoxDecoration(color: S.mist, shape: BoxShape.circle),
                child: Icon(Icons.person_add_alt_1_rounded, size: 110 * k, color: S.violet),
              ),
              SizedBox(width: 44 * k),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Flexible(child: Text(teachers.isEmpty ? tr(l, 'First time here?', 'ಮೊದಲ ಬಾರಿಯೇ?') : tr(l, 'Not you?', 'ನೀವಲ್ಲವೇ?'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(36 * k, c: S.muted, w: FontWeight.w600))),
                  SizedBox(height: 6 * k),
                  Flexible(child: Text(tr(l, 'Add yourself', 'ನಿಮ್ಮನ್ನು ಸೇರಿಸಿ'), maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(72 * k, c: S.violet, l: l))),
                  SizedBox(height: 14 * k),
                  Flexible(child: Text(tr(l, 'Your name and initials. Under a minute.', 'ನಿಮ್ಮ ಹೆಸರು ಮತ್ತು ಮೊದಲಕ್ಷರಗಳು. ಒಂದು ನಿಮಿಷದೊಳಗೆ.'), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(32 * k, c: S.cardText))),
                ]),
              ),
            ]),
          ),
        ),
      );

      final help = HelpInfo(
        next: teachers.isEmpty ? const L10n('Tap “Add yourself” and type your name.', '“ನಿಮ್ಮನ್ನು ಸೇರಿಸಿ” ಒತ್ತಿ, ನಿಮ್ಮ ಹೆಸರು ಬರೆಯಿರಿ.') : const L10n('Tap your own card to start.', 'ಪ್ರಾರಂಭಿಸಲು ನಿಮ್ಮ ಕಾರ್ಡ್ ಒತ್ತಿ.'),
      );
      final safe = tr(l, 'No password to remember. Your school can add a PIN later if it wants one.', 'ನೆನಪಿಡಲು ಪಾಸ್‌ವರ್ಡ್ ಇಲ್ಲ. ಶಾಲೆ ಬೇಕಿದ್ದರೆ ನಂತರ PIN ಸೇರಿಸಬಹುದು.');
      final hello = '${greeting(l, now)}!';
      final date = '${s.config.collegeName} · ${shortDate(l, now)}';

      if (phone) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(40, 36, 40, 36), children: [
              Row(children: [const Brand(size: 60), const Spacer(), HelpChip(info: () => help)]),
              const SizedBox(height: 48),
              Text(hello, style: tx(34, c: S.eyebrow, w: FontWeight.w600)),
              Text(tr(l, 'Who’s teaching today?', 'ಇಂದು ಯಾರು ಕಲಿಸುತ್ತಿದ್ದೀರಿ?'), style: hd(80, l: l)),
              const SizedBox(height: 12),
              Text(tr(l, 'Tap your name. Your class for now opens with you.', 'ನಿಮ್ಮ ಹೆಸರನ್ನು ಒತ್ತಿ. ಈಗಿನ ನಿಮ್ಮ ತರಗತಿ ತೆರೆಯುತ್ತದೆ.'), style: tx(32)),
              const SizedBox(height: 40),
              for (final (i, t) in teachers.indexed) ...[SizedBox(height: 230, child: card(i, t, k: .6)), const SizedBox(height: 24)],
              SizedBox(height: 230, child: add(k: .6)),
              const SizedBox(height: 40),
              SafeLine(safe, size: 28, c: S.body),
            ]),
          ),
        );
      }
      return Scaffold(
        backgroundColor: Colors.white,
        body: DesignCanvas(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_pad, 70, _pad, 80),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Brand(),
                const SizedBox(width: 40),
                Expanded(child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(34, c: S.muted))),
                Press(
                  key: const ValueKey('whoLang'),
                  onTap: s.config.kannadaOffered ? () => s.config.setLang(l == Lang.en ? Lang.kn : Lang.en) : null,
                  child: Tag(l == Lang.en ? 'English' : 'ಕನ್ನಡ', icon: Icons.translate_rounded, bg: S.mist, size: 32),
                ),
              ]),
              const SizedBox(height: 90),
              Text(hello, style: tx(44, c: S.eyebrow, w: FontWeight.w600)),
              const SizedBox(height: 16),
              Text(tr(l, 'Who’s teaching today?', 'ಇಂದು ಯಾರು ಕಲಿಸುತ್ತಿದ್ದೀರಿ?'), maxLines: 1, style: hd(140, l: l)),
              const SizedBox(height: 22),
              Text(tr(l, 'Tap your name. Your class for now opens with you.', 'ನಿಮ್ಮ ಹೆಸರನ್ನು ಒತ್ತಿ. ಈಗಿನ ನಿಮ್ಮ ತರಗತಿ ತೆರೆಯುತ್ತದೆ.'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(46)),
              const SizedBox(height: 72),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  const gap = 48.0;
                  final w = (box.maxWidth - gap * 2) / 3, h = (box.maxHeight - gap) / 2;
                  return SingleChildScrollView(
                    child: Wrap(spacing: gap, runSpacing: gap, children: [
                      for (final (i, t) in teachers.indexed) SizedBox(width: w, height: h, child: card(i, t)),
                      SizedBox(width: w, height: h, child: add()),
                    ]),
                  );
                }),
              ),
              const SizedBox(height: 56),
              Row(children: [
                Expanded(child: SafeLine(maxLines: 1, school.pinsOn ? tr(l, 'Your school has turned on PINs for teacher cards.', 'ಶಾಲೆ ಶಿಕ್ಷಕರ ಕಾರ್ಡ್‌ಗಳಿಗೆ PIN ಆನ್ ಮಾಡಿದೆ.') : safe, size: 36, c: S.body)),
                const SizedBox(width: 40),
                if (!school.tourDone) ...[StepProgress(step: 2, of: 3, dark: false, width: 400, lang: l), const SizedBox(width: 40)],
                HelpFab(info: () => help, size: 32),
              ]),
            ]),
          ),
        ),
      );
    },
  );
}

/// Signs [t] in, asking for their PIN only when the school has turned PINs on and they set one.
Future<void> signInAs(BuildContext context, Teacher t) async {
  final s = ServicesScope.of(context);
  if (s.school.pinsOn && t.pinHash != null) {
    final ok = await askTeacherPin(context, t);
    if (!ok) return;
  }
  s.school.signIn(t.id);
}

Future<bool> askTeacherPin(BuildContext context, Teacher t) async {
  final l = ServicesScope.of(context).config.lang;
  final pin = TextEditingController();
  var wrong = false;
  final ok = await showZxDialog<bool>(
    context,
    width: 1000,
    title: tr(l, 'Your PIN, ${t.firstName}', 'ನಿಮ್ಮ PIN, ${t.firstName}'),
    body: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ZxField(fieldKey: const ValueKey('pinField'), controller: pin, label: 'PIN', obscure: true, number: true, maxLength: 6, autofocus: true),
        if (wrong) Padding(padding: const EdgeInsets.only(top: 20), child: Text(tr(l, 'That PIN is not right. Try again.', 'ಆ PIN ಸರಿಯಿಲ್ಲ. ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.'), style: tx(34, c: S.rust, w: FontWeight.w600))),
        const SizedBox(height: 40),
        Wrap(alignment: WrapAlignment.end, spacing: 24, runSpacing: 16, children: [
          ZxButton(tr(l, 'Cancel', 'ರದ್ದು'), bg: S.mist, fg: S.ink, onTap: () => Navigator.pop(ctx, false)),
          ZxButton(tr(l, 'Open', 'ತೆರೆಯಿರಿ'), key: const ValueKey('pinOk'), bg: S.violet, onTap: () {
            if (t.checkPin(pin.text)) {
              Navigator.pop(ctx, true);
            } else {
              set(() => wrong = true);
            }
          }),
        ]),
      ]),
    ),
  );
  return ok == true;
}

/// "Add yourself": a name, initials (filled in from the name) and, if the school uses them, a PIN.
Future<Teacher?> addTeacherDialog(BuildContext context, {bool signIn = true}) async {
  final s = ServicesScope.of(context);
  final l = s.config.lang;
  final name = TextEditingController(), initials = TextEditingController(), pin = TextEditingController();
  final t = await showZxDialog<Teacher>(
    context,
    width: 1300,
    title: tr(l, 'Add yourself', 'ನಿಮ್ಮನ್ನು ಸೇರಿಸಿ'),
    body: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ZxField(
          fieldKey: const ValueKey('teacherName'),
          controller: name,
          label: tr(l, 'Your name (as the class calls you)', 'ನಿಮ್ಮ ಹೆಸರು'),
          autofocus: true,
        ),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: ZxField(fieldKey: const ValueKey('teacherInitials'), controller: initials, label: tr(l, 'Initials (optional)', 'ಮೊದಲಕ್ಷರಗಳು (ಐಚ್ಛಿಕ)'), maxLength: 3)),
          if (s.school.pinsOn) ...[
            const SizedBox(width: 28),
            Expanded(child: ZxField(fieldKey: const ValueKey('teacherPin'), controller: pin, label: tr(l, 'PIN (optional)', 'PIN (ಐಚ್ಛಿಕ)'), obscure: true, number: true, maxLength: 6)),
          ],
        ]),
        const SizedBox(height: 24),
        SafeLine(tr(l, 'Only your name is kept, on this board. No photo, no phone number.', 'ನಿಮ್ಮ ಹೆಸರು ಮಾತ್ರ ಈ ಬೋರ್ಡ್‌ನಲ್ಲಿ ಉಳಿಯುತ್ತದೆ. ಫೋಟೋ, ಫೋನ್ ಸಂಖ್ಯೆ ಇಲ್ಲ.'), size: 30, c: S.muted),
        const SizedBox(height: 40),
        Wrap(alignment: WrapAlignment.end, spacing: 24, runSpacing: 16, children: [
          ZxButton(tr(l, 'Cancel', 'ರದ್ದು'), bg: S.mist, fg: S.ink, onTap: () => Navigator.pop(ctx)),
          ZxButton(tr(l, 'Add', 'ಸೇರಿಸಿ'), key: const ValueKey('teacherAdd'), icon: Icons.check_rounded, bg: S.violet, onTap: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(ctx, s.school.addTeacher(name.text, initials: initials.text, pin: pin.text));
          }),
        ]),
      ]),
    ),
  );
  if (t != null && signIn) s.school.signIn(t.id);
  return t;
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
