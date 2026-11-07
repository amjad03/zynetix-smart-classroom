import 'package:flutter/material.dart';

import '../../engine/model.dart';
import 'data.dart';
import 'kit.dart';

/// 01 · Who's teaching? Every teacher's card with the class they have now, and the PIN pad.
class WhoTeachingScreen extends StatelessWidget {
  const WhoTeachingScreen({super.key, this.selected = 0, this.digits = 2});
  final int selected, digits;

  @override
  Widget build(BuildContext context) {
    final t = teachers[selected];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFF4F6F2), Color(0xFFE6EAE4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        padding: const EdgeInsets.fromLTRB(120, 96, 120, 96),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                avatarLogo(),
                const SizedBox(width: 28),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Govt. PU College, Malleshwaram', style: bx(30, P.muted)),
                  Text('Wednesday, 4 November · 10:05', style: bx(30, P.ink, FontWeight.w600)),
                ]),
              ]),
              const SizedBox(height: 88),
              Text('Who’s teaching?', style: tt(96, P.ink, FontWeight.w700)),
              const SizedBox(height: 16),
              Text('Tap your card. Your classes, plans and boards open with you.', style: bx(36, P.muted, FontWeight.w400)),
              const SizedBox(height: 72),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  const gap = 40.0;
                  final w = (box.maxWidth - gap * 2) / 3, h = (box.maxHeight - gap) / 2;
                  return Wrap(spacing: gap, runSpacing: gap, children: [
                    for (final (i, x) in teachers.indexed) SizedBox(width: w, height: h, child: _TeacherCard(x, on: i == selected)),
                    SizedBox(width: w, height: h, child: const _AdminCard()),
                  ]);
                }),
              ),
            ]),
          ),
          const SizedBox(width: 96),
          SizedBox(
            width: 880,
            child: PCard(
              high: true,
              radius: 64,
              pad: const EdgeInsets.fromLTRB(72, 72, 72, 64),
              child: Column(children: [
                avatar(t.initials, t.color, size: 168),
                const SizedBox(height: 28),
                Text(t.name, style: tt(56)),
                const SizedBox(height: 10),
                Pill(t.now, color: t.subj.a, icon: Icons.schedule, size: 26),
                const SizedBox(height: 56),
                Text('Enter your 4-digit PIN', style: bx(32, P.muted)),
                const SizedBox(height: 28),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i < digits ? P.primary : Colors.transparent, border: Border.all(color: i < digits ? P.primary : P.line, width: 4)),
                    ),
                ]),
                const SizedBox(height: 48),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final h = (box.maxHeight - 3 * 22) / 4;
                    Widget key(String k, {IconData? icon}) => Expanded(
                      child: Container(
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 11),
                        decoration: BoxDecoration(color: k.isEmpty && icon == null ? null : P.soft, borderRadius: BorderRadius.circular(32)),
                        alignment: Alignment.center,
                        child: icon != null ? Icon(icon, size: 52, color: P.ink2) : Text(k, style: tt(56, P.ink, FontWeight.w500)),
                      ),
                    );
                    return Column(children: [
                      for (final row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']]) ...[
                        Row(children: [for (final k in row) key(k)]),
                        const SizedBox(height: 22),
                      ],
                      Row(children: [key(''), key('0'), key('', icon: Icons.backspace_outlined)]),
                    ]);
                  }),
                ),
                const SizedBox(height: 36),
                Text('Signs out by itself after 5 idle minutes', style: bx(26, P.muted, FontWeight.w400)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

Widget avatarLogo() => Container(
  width: 96, height: 96,
  decoration: BoxDecoration(
    gradient: const LinearGradient(colors: [Color(0xFF4F7BFF), Color(0xFF1A3FB0)]),
    borderRadius: BorderRadius.circular(30),
    boxShadow: [BoxShadow(color: const Color(0xFF2457E6).withValues(alpha: .4), blurRadius: 30, offset: const Offset(0, 12))],
  ),
  alignment: Alignment.center,
  child: Text('Z', style: tt(54, Colors.white, FontWeight.w700)),
);

class _TeacherCard extends StatelessWidget {
  const _TeacherCard(this.t, {this.on = false});
  final Teacher t;
  final bool on;
  @override
  Widget build(BuildContext context) => PCard(
    high: on,
    border: on ? P.primary : null,
    pad: const EdgeInsets.all(44),
    child: Stack(children: [
      Positioned(right: -20, top: -20, child: Icon(t.subj.icon, size: 200, color: t.subj.a.withValues(alpha: .07))),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        avatar(t.initials, t.color, size: 128),
        const Spacer(),
        Text(t.name, style: tt(44), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text(t.subj.name, style: bx(30, t.subj.a, FontWeight.w600)),
        const SizedBox(height: 16),
        Row(children: [
          Icon(t.now.endsWith('now') ? Icons.circle : Icons.schedule, size: 24, color: t.now.endsWith('now') ? const Color(0xFF00A86B) : P.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(t.now, style: bx(26, P.ink2), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ]),
    ]),
  );
}

class _AdminCard extends StatelessWidget {
  const _AdminCard();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(P.r), border: Border.all(color: P.line, width: 3)),
    padding: const EdgeInsets.all(44),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 128, height: 128, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), shape: BoxShape.circle), child: const Icon(Icons.admin_panel_settings_outlined, size: 64, color: P.ink2)),
      const Spacer(),
      Text('Admin', style: tt(44)),
      const SizedBox(height: 8),
      Text('Teachers, classes, timetable', style: bx(28, P.muted)),
      const SizedBox(height: 16),
      Text('Practice board · Guided tour', style: bx(26, P.primary, FontWeight.w600)),
    ]),
  );
}

/// 02 · Today: the class on now, the day, last time, and the five ways in.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) => LangOf(builder: (context, l) {
    final phone = MediaQuery.sizeOf(context).width < 1200;
    return Shell(
      place: Place.today,
      lang: l,
      crumb: tr(l, 'Wednesday, 4 November · Govt. PU College, Malleshwaram', 'ಬುಧವಾರ, 4 ನವೆಂಬರ್ · ಸರ್ಕಾರಿ ಪಿಯು ಕಾಲೇಜು, ಮಲ್ಲೇಶ್ವರಂ'),
      title: tr(l, 'Good morning, Meera', 'ಶುಭೋದಯ, ಮೀರಾ'),
      actions: [
        Pill(tr(l, 'Offline ready', 'ಆಫ್‌ಲೈನ್ ಸಿದ್ಧ'), icon: Icons.cloud_done_outlined, color: const Color(0xFF00875A), size: 26),
        Pill(tr(l, 'Projector on', 'ಪ್ರೊಜೆಕ್ಟರ್ ಆನ್'), icon: Icons.cast_connected, color: P.ink2, size: 26),
        Pill('ಕನ್ನಡ / English', icon: Icons.translate, color: P.primary, size: 26),
      ],
      body: phone ? _phonePage(l) : _boardPage(l),
    );
  });

  Widget _boardPage(Lang l) => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 560, child: _Hero(l)),
        const SizedBox(height: 32),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _LastTime(l)),
            const SizedBox(width: 40),
            Expanded(child: _Ready(l)),
          ]),
        ),
        const SizedBox(height: 32),
        SizedBox(height: 240, child: _Pillars(l)),
      ]),
    ),
    const SizedBox(width: 44),
    SizedBox(width: 720, child: _Timetable(l)),
  ]);

  Widget _phonePage(Lang l) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    SizedBox(height: 500, child: _Hero(l, compact: true)),
    const SizedBox(height: 28),
    SizedBox(height: 360, child: _Pillars(l, grid: true)),
    const SizedBox(height: 28),
    Expanded(child: _Timetable(l, compact: true)),
  ]);
}

class _Hero extends StatelessWidget {
  const _Hero(this.l, {this.compact = false});
  final Lang l;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final s = Subj.physics;
    final c = compact;
    return PCard(
      high: true,
      radius: P.rBig,
      gradient: s.grad,
      pad: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(P.rBig),
        child: Stack(children: [
          const Positioned.fill(child: Glow()),
          Positioned(right: c ? -60 : 330, top: c ? -20 : -150, child: ArtView(Art.orbit, size: c ? 320 : 600, opacity: c ? .3 : .22)),
          Padding(
            padding: EdgeInsets.all(c ? 40 : 64),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Pill(tr(l, 'ON NOW · PERIOD 2', 'ಈಗ · ಅವಧಿ 2'), color: Colors.white, bg: Colors.white.withValues(alpha: .18), icon: Icons.circle, size: c ? 22 : 26),
                    const SizedBox(width: 16),
                    if (!c) Text('9:45 – 10:40 · ${tr(l, '1st PUC A · PCMB · 40 rolls', 'ಪ್ರಥಮ ಪಿಯುಸಿ A · PCMB · 40 ರೋಲ್')}', style: bx(28, Colors.white.withValues(alpha: .85))),
                  ]),
                  SizedBox(height: c ? 20 : 28),
                  Text(tr(l, 'Physics · Chapter 7', 'ಭೌತಶಾಸ್ತ್ರ · ಅಧ್ಯಾಯ 7'), style: bx(c ? 26 : 32, Colors.white.withValues(alpha: .8), FontWeight.w600)),
                  Text(tr(l, 'Gravitation', 'ಗುರುತ್ವಾಕರ್ಷಣೆ'), style: tt(c ? 64 : 88, Colors.white, FontWeight.w700), maxLines: 1),
                  SizedBox(height: c ? 6 : 10),
                  Text(tr(l, 'Topic 3 of 5 · Acceleration due to gravity and its variation', 'ವಿಷಯ 3/5 · ಗುರುತ್ವ ವೇಗೋತ್ಕರ್ಷ ಮತ್ತು ಅದರ ವ್ಯತ್ಯಾಸ'), style: bx(c ? 26 : 34, Colors.white, FontWeight.w500), maxLines: c ? 2 : 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Wrap(spacing: 20, runSpacing: 20, children: [
                    PButton(tr(l, 'Start class', 'ತರಗತಿ ಪ್ರಾರಂಭಿಸಿ'), icon: Icons.play_arrow_rounded, onDark: true, color: s.b, big: !c),
                    if (!c) PButton(tr(l, 'Smartboard', 'ಸ್ಮಾರ್ಟ್‌ಬೋರ್ಡ್'), icon: Icons.draw_outlined, filled: false, onDark: true, big: true),
                    if (!c) PButton(tr(l, 'Attendance', 'ಹಾಜರಾತಿ'), icon: Icons.how_to_reg_outlined, filled: false, onDark: true, big: true),
                  ]),
                ]),
              ),
              if (!c) ...[
                const SizedBox(width: 40),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Ring(
                    value: 35 / 55,
                    size: 260,
                    stroke: 22,
                    color: const Color(0xFFFFC56B),
                    center: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('35', style: tt(88, Colors.white, FontWeight.w700).copyWith(height: 1)),
                      Text(tr(l, 'min left', 'ನಿಮಿಷ ಉಳಿದಿದೆ'), style: bx(26, Colors.white.withValues(alpha: .85))),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  Text(tr(l, '2 periods on this chapter', 'ಈ ಅಧ್ಯಾಯಕ್ಕೆ 2 ಅವಧಿಗಳು'), style: bx(26, Colors.white.withValues(alpha: .85))),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _LastTime extends StatelessWidget {
  const _LastTime(this.l);
  final Lang l;
  @override
  Widget build(BuildContext context) => PCard(
    pad: const EdgeInsets.fromLTRB(44, 40, 44, 36),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SecHead(tr(l, 'Last time · Monday', 'ಕಳೆದ ಬಾರಿ · ಸೋಮವಾರ'), icon: Icons.history, trailing: Pill(tr(l, 'Topic 2 done', 'ವಿಷಯ 2 ಮುಗಿದಿದೆ'), icon: Icons.check, color: const Color(0xFF00875A), size: 24)),
      const SizedBox(height: 8),
      Text(tr(l, 'Universal law of gravitation', 'ಗುರುತ್ವಾಕರ್ಷಣೆಯ ಸಾರ್ವತ್ರಿಕ ನಿಯಮ'), style: bx(30, P.muted)),
      const SizedBox(height: 14),
      for (final p in [tr(l, 'F = Gm₁m₂/r², always attractive.', 'F = Gm₁m₂/r², ಯಾವಾಗಲೂ ಆಕರ್ಷಕ.'), tr(l, 'G = 6.67 × 10⁻¹¹ N m² kg⁻², first measured by Cavendish.', 'G = 6.67 × 10⁻¹¹ N m² kg⁻², ಮೊದಲು ಕ್ಯಾವೆಂಡಿಷ್ ಅಳೆದ.')])
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 8), child: Icon(Icons.check_circle, size: 30, color: Color(0xFF00875A))),
            const SizedBox(width: 16),
            Expanded(child: Text(p, style: bx(30), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(28)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.assignment_outlined, size: 40, color: Color(0xFFB07A00)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(l, 'Homework to check', 'ಪರಿಶೀಲಿಸಬೇಕಾದ ಮನೆಗೆಲಸ'), style: bx(26, const Color(0xFF8A5A00), FontWeight.w700)),
              Text(tr(l, 'Two 1 kg spheres touch, radius 5 cm each: the force between them?', 'ತಲಾ 5 cm ತ್ರಿಜ್ಯದ ಎರಡು 1 kg ಗೋಳಗಳು ಸ್ಪರ್ಶಿಸುತ್ತವೆ: ಅವುಗಳ ನಡುವಿನ ಬಲ?'), style: bx(28), maxLines: l == Lang.kn ? 1 : 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    ]),
  );
}

class _Ready extends StatelessWidget {
  const _Ready(this.l);
  final Lang l;
  @override
  Widget build(BuildContext context) {
    final rows = [
      (Res.lesson, tr(l, 'Lesson · 19 steps, voice, 40 min', 'ಪಾಠ · 19 ಹಂತ, ಧ್ವನಿ, 40 ನಿಮಿಷ')),
      (Res.sim, tr(l, 'Simple pendulum explorer', 'ಸರಳ ಲೋಲಕ')),
      (Res.model3d, tr(l, 'Layers of the Earth (3D)', 'ಭೂಮಿಯ ಪದರಗಳು (3D)')),
      (Res.explainer, tr(l, 'Gravity and falling: feather vs hammer', 'ಗುರುತ್ವ ಮತ್ತು ಬೀಳುವಿಕೆ: ಗರಿ ಮತ್ತು ಸುತ್ತಿಗೆ')),
      (Res.practice, tr(l, '5 exam questions · NEET · JEE · KCET', '5 ಪರೀಕ್ಷಾ ಪ್ರಶ್ನೆಗಳು · NEET · JEE · KCET')),
    ];
    return PCard(
      pad: const EdgeInsets.all(48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SecHead(tr(l, 'Ready for today', 'ಇಂದಿಗೆ ಸಿದ್ಧ'), icon: Icons.inventory_2_outlined, trailing: Text(tr(l, 'Downloaded', 'ಡೌನ್‌ಲೋಡ್ ಆಗಿದೆ'), style: bx(24, const Color(0xFF00875A), FontWeight.w600))),
        const SizedBox(height: 20),
        for (final (r, t) in rows)
          Expanded(
            child: Row(children: [
              ResBadge(r, compact: true),
              const SizedBox(width: 22),
              Expanded(child: Text(t, style: bx(30), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.chevron_right, size: 40, color: P.muted),
            ]),
          ),
      ]),
    );
  }
}

class _Pillars extends StatelessWidget {
  const _Pillars(this.l, {this.grid = false});
  final Lang l;
  final bool grid;
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.school_outlined, tr(l, 'Teach', 'ಬೋಧನೆ'), tr(l, 'Video-style lessons', 'ವೀಡಿಯೊ ಶೈಲಿ ಪಾಠಗಳು'), const [Color(0xFF3D6DF2), Color(0xFF1A3FB0)]),
      (Icons.draw_outlined, tr(l, 'Smartboard', 'ಸ್ಮಾರ್ಟ್‌ಬೋರ್ಡ್'), tr(l, 'Write, labs, 3D', 'ಬರೆಯಿರಿ, ಲ್ಯಾಬ್, 3D'), const [Color(0xFF253238), Color(0xFF0F1619)]),
      (Icons.dashboard_customize_outlined, tr(l, 'Class tools', 'ತರಗತಿ ಸಾಧನ'), tr(l, 'Quiz, mock, teams', 'ರಸಪ್ರಶ್ನೆ, ಮಾದರಿ'), const [Color(0xFF00A07A), Color(0xFF0A5C50)]),
      (Icons.collections_bookmark_outlined, tr(l, 'Library', 'ಗ್ರಂಥಾಲಯ'), tr(l, '3D, labs, videos', '3D, ಲ್ಯಾಬ್, ವೀಡಿಯೊ'), const [Color(0xFF8A5FE6), Color(0xFF4A2C9E)]),
      (Icons.insights_outlined, tr(l, 'Reports', 'ವರದಿಗಳು'), tr(l, 'Pacing, mastery', 'ಪ್ರಗತಿ, ಪಾಂಡಿತ್ಯ'), const [Color(0xFFE88A2E), Color(0xFFB24A0E)]),
    ];
    Widget tile((IconData, String, String, List<Color>) x) => PCard(
      pad: EdgeInsets.all(grid ? 28 : 32),
      child: Flex(direction: grid ? Axis.horizontal : Axis.vertical, crossAxisAlignment: grid ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
        Container(
          width: grid ? 84 : 70, height: grid ? 84 : 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: x.$4, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(grid ? 26 : 34),
            boxShadow: [BoxShadow(color: x.$4.first.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Icon(x.$1, size: grid ? 44 : 42, color: Colors.white),
        ),
        SizedBox(width: grid ? 20 : 0, height: grid ? 0 : 14),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.$2, style: tt(grid ? 30 : 34), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(x.$3, style: bx(grid ? 22 : 24, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
    if (grid) {
      return Column(children: [
        Expanded(child: Row(children: [Expanded(child: tile(items[0])), const SizedBox(width: 24), Expanded(child: tile(items[1]))])),
        const SizedBox(height: 24),
        Expanded(child: Row(children: [Expanded(child: tile(items[2])), const SizedBox(width: 24), Expanded(child: tile(items[3]))])),
      ]);
    }
    return Row(children: [
      for (final (i, x) in items.indexed) ...[if (i > 0) const SizedBox(width: 32), Expanded(child: tile(x))],
    ]);
  }
}

class _Timetable extends StatelessWidget {
  const _Timetable(this.l, {this.compact = false});
  final Lang l;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final kn = <String, String>{
      'Gravitation · Kepler’s laws': 'ಗುರುತ್ವಾಕರ್ಷಣೆ · ಕೆಪ್ಲರ್ ನಿಯಮಗಳು',
      'Gravitation · g and its variation': 'ಗುರುತ್ವಾಕರ್ಷಣೆ · g ಮತ್ತು ವ್ಯತ್ಯಾಸ',
      'Ray optics · Refraction of light': 'ಕಿರಣ ದೃಗ್ವಿಜ್ಞಾನ · ಬೆಳಕಿನ ವಕ್ರೀಭವನ',
      'Laws of motion · Friction': 'ಚಲನೆಯ ನಿಯಮಗಳು · ಘರ್ಷಣೆ',
      'Practical · Simple pendulum': 'ಪ್ರಾಯೋಗಿಕ · ಸರಳ ಲೋಲಕ',
    };
    final periods = compact ? today.sublist(1, 4) : today;
    return PCard(
      pad: EdgeInsets.all(compact ? 32 : 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SecHead(tr(l, 'Today’s timetable', 'ಇಂದಿನ ವೇಳಾಪಟ್ಟಿ'), icon: Icons.calendar_today_outlined, trailing: compact ? null : Text(tr(l, '5 periods', '5 ಅವಧಿ'), style: bx(26, P.muted))),
        SizedBox(height: compact ? 16 : 28),
        for (final p in periods)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                decoration: BoxDecoration(
                  color: p.state == 'now' ? p.subj.tint : (p.state == 'done' ? P.soft : Colors.white),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: p.state == 'now' ? p.subj.a : const Color(0xFFE3E6E1), width: p.state == 'now' ? 4 : 2),
                ),
                child: Row(children: [
                  SizedBox(
                    width: compact ? 96 : 116,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.time, style: tt(compact ? 30 : 34, p.state == 'done' ? P.muted : P.ink)),
                      Text('P${p.no}', style: bx(22, P.muted, FontWeight.w600)),
                    ]),
                  ),
                  Container(width: 6, height: 72, decoration: BoxDecoration(color: p.state == 'done' ? P.line : p.subj.a, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(l, p.cls, p.cls.replaceFirst('1st PUC', 'ಪ್ರಥಮ ಪಿಯುಸಿ').replaceFirst('2nd PUC', 'ದ್ವಿತೀಯ ಪಿಯುಸಿ')), style: bx(compact ? 26 : 30, P.ink, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(tr(l, p.what, kn[p.what] ?? p.what), style: bx(compact ? 22 : 26, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  if (p.state == 'done') Icon(Icons.check_circle, size: 40, color: const Color(0xFF00875A).withValues(alpha: .8)),
                  if (p.state == 'now') Pill(tr(l, 'Now', 'ಈಗ'), solid: true, color: p.subj.a, size: 22),
                  if (p.state == 'lab') const Icon(Icons.biotech_outlined, size: 40, color: Color(0xFF00876A)),
                ]),
              ),
            ),
          ),
        if (!compact) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: P.soft, borderRadius: BorderRadius.circular(28)),
            child: Row(children: [
              Ring(value: .56, size: 112, stroke: 14, color: P.primary, track: const Color(0xFFE0E4DE), center: Text('56%', style: tt(26))),
              const SizedBox(width: 26),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(l, 'Year plan · 1st PUC A Physics', 'ವಾರ್ಷಿಕ ಯೋಜನೆ · ಭೌತಶಾಸ್ತ್ರ'), style: bx(26, P.ink, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(tr(l, '6½ of 14 chapters · 1.8 weeks behind', '14ರಲ್ಲಿ 6½ ಅಧ್ಯಾಯ · 1.8 ವಾರ ಹಿಂದೆ'), style: bx(24, const Color(0xFFB45309)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// 03 · Teach → a chapter: every topic with the resources it carries, Start class, pacing.
class ChapterScreen extends StatelessWidget {
  const ChapterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const s = Subj.chemistry;
    return Shell(
      place: Place.teach,
      who: teachers[1],
      crumb: 'Teach  ›  1st PUC  ›  Chemistry (Karnataka PU · also CBSE, ISC)',
      title: 'Chapter 1 · Some Basic Concepts of Chemistry',
      actions: const [
        Pill('NEET · JEE · KCET · COMEDK', icon: Icons.emoji_events_outlined, color: Color(0xFFB07A00), size: 26),
        PButton('Self-learning period', icon: Icons.person_outline, filled: false),
      ],
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: PCard(
            pad: const EdgeInsets.fromLTRB(48, 40, 48, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text('5 topics', style: tt(38)),
                const SizedBox(width: 20),
                Text('3 taught · 1 in progress · 13 concept videos', style: bx(28, P.muted)),
                const Spacer(),
                for (final r in [Res.lesson, Res.video, Res.interactive, Res.sim, Res.lab, Res.model3d, Res.explainer, Res.practice]) ...[
                  const SizedBox(width: 10),
                  ResBadge(r, compact: true),
                ],
              ]),
              const SizedBox(height: 28),
              for (final t in chemChapter) Expanded(child: _TopicRow(t, s)),
            ]),
          ),
        ),
        const SizedBox(width: 44),
        SizedBox(
          width: 760,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PCard(
              high: true,
              radius: P.rBig,
              gradient: s.grad,
              pad: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(P.rBig),
                child: Stack(children: [
                  const Positioned.fill(child: Glow()),
                  const Positioned(right: -30, top: -10, child: ArtView(Art.flask, size: 320, opacity: .9)),
                  Padding(
                    padding: const EdgeInsets.all(52),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Pill('NEXT · TOPIC 4', color: Colors.white, bg: Colors.white.withValues(alpha: .18), size: 24),
                      const SizedBox(height: 28),
                      SizedBox(width: 440, child: Text('Atomic mass, mole concept and percentage composition', style: tt(46, Colors.white, FontWeight.w700), maxLines: 3)),
                      const SizedBox(height: 18),
                      Text('“Counting atoms by weighing” · 18 steps · 40 min', style: bx(28, Colors.white.withValues(alpha: .85))),
                      const SizedBox(height: 40),
                      const PButton('Start class', icon: Icons.play_arrow_rounded, onDark: true, color: Color(0xFF0A4B45), big: true),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: PCard(
                pad: const EdgeInsets.all(48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SecHead('Year plan · 1st PUC B', icon: Icons.timeline),
                  const SizedBox(height: 28),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Week 3', style: tt(56, P.ink, FontWeight.w700)),
                    const SizedBox(width: 14),
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('of 4 planned', style: bx(28, P.muted))),
                  ]),
                  const SizedBox(height: 22),
                  const Bar(value: .7, color: Color(0xFF00876A), height: 22, marker: .75),
                  const SizedBox(height: 14),
                  Text('70% taught · plan marker at 75%', style: bx(26, P.muted)),
                  const Spacer(),
                  Text('Before you start', style: bx(26, P.muted, FontWeight.w700)),
                  const SizedBox(height: 14),
                  for (final (i, t) in [
                    (Icons.download_done, 'Videos Ep 8–11 downloaded for offline'),
                    (Icons.print_outlined, 'Worksheet: exam questions + answer key'),
                    (Icons.how_to_reg_outlined, 'Class quiz marks by roll number'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(children: [Icon(i, size: 36, color: const Color(0xFF00876A)), const SizedBox(width: 16), Expanded(child: Text(t, style: bx(28), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow(this.t, this.s);
  final ChTopic t;
  final Subj s;
  @override
  Widget build(BuildContext context) {
    final now = t.state == 'now', done = t.state == 'done';
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        decoration: BoxDecoration(
          color: now ? s.tint : P.soft,
          borderRadius: BorderRadius.circular(32),
          border: now ? Border.all(color: s.a, width: 4) : null,
        ),
        child: Row(children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(shape: BoxShape.circle, color: done ? const Color(0xFF00875A) : (now ? s.a : Colors.white), border: done || now ? null : Border.all(color: P.line, width: 3)),
            alignment: Alignment.center,
            child: done ? const Icon(Icons.check, size: 48, color: Colors.white) : Text('${t.no}', style: tt(38, now ? Colors.white : P.ink)),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(t.title, style: tt(36), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (now) ...[const SizedBox(width: 16), Pill('Up next', solid: true, color: s.a, size: 22)],
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 8, children: [for (final r in t.res) ResBadge(r)]),
            ]),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 380,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                const Icon(Icons.play_circle_fill, size: 34, color: Color(0xFFD55E00)),
                const SizedBox(width: 10),
                Flexible(child: Text(t.video ?? '', style: bx(24, P.ink2, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 8),
              Text(done ? 'Taught · ${t.minutes} min' : '${t.minutes} min · ${t.items.isEmpty ? 'lesson ready' : t.items.first}', style: bx(24, done ? const Color(0xFF00875A) : P.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}
