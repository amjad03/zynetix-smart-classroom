import 'package:flutter/material.dart';
import 'package:kinetix_ui/kinetix_ui.dart' show KxFonts;

import '../../blocks/math_text.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import '../classroom/class_data.dart';
import 'data.dart';
import 'kit.dart';

/// 06 · Library: 3D models, virtual labs, simulations, explainers and concept videos.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context) => Shell(
    place: Place.library,
    crumb: 'Everything on this board, offline · by subject and chapter',
    title: 'Library',
    actions: [
      Container(
        width: 640, height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: P.shadow),
        child: Row(children: [const Icon(Icons.search, size: 44, color: P.muted), const SizedBox(width: 16), Text('Search “pendulum”, “VSEPR”…', style: bx(28, P.muted, FontWeight.w400))]),
      ),
    ],
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (final (i, t) in ['All', '3D models', 'Virtual labs', 'Simulations', 'Explainers', 'Concept videos'].indexed)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 22),
            decoration: BoxDecoration(color: i == 0 ? P.ink : Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: i == 0 ? P.shadow : null, border: i == 0 ? null : Border.all(color: const Color(0xFFDDE1DA), width: 2)),
            child: Text(t, style: bx(28, i == 0 ? Colors.white : P.ink, FontWeight.w600)),
          ),
        const Spacer(),
        for (final s in [Subj.physics, Subj.chemistry, Subj.maths, Subj.biology])
          Container(
            margin: const EdgeInsets.only(left: 14),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
            decoration: BoxDecoration(color: s == Subj.physics || s == Subj.chemistry ? s.tint : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: s == Subj.physics || s == Subj.chemistry ? s.a : const Color(0xFFDDE1DA), width: 2)),
            child: Row(children: [Icon(s.icon, size: 32, color: s.a), const SizedBox(width: 10), Text(s.name, style: bx(26, s.a, FontWeight.w600))]),
          ),
      ]),
      const SizedBox(height: 36),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          const cols = 4, rows = 3, gap = 36.0;
          final w = (box.maxWidth - gap * (cols - 1)) / cols, h = (box.maxHeight - gap * (rows - 1)) / rows;
          return Wrap(spacing: gap, runSpacing: gap, children: [for (final it in library) SizedBox(width: w, height: h, child: _LibCard(it))]);
        }),
      ),
    ]),
  );
}

class _LibCard extends StatelessWidget {
  const _LibCard(this.it);
  final LibItem it;
  @override
  Widget build(BuildContext context) => PCard(
    pad: EdgeInsets.zero,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(P.r),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 170,
          decoration: BoxDecoration(gradient: it.kind == Res.video ? const LinearGradient(colors: [Color(0xFFE07A2E), Color(0xFF7A2E06)], begin: Alignment.topLeft, end: Alignment.bottomRight) : it.subj.grad),
          child: Stack(alignment: Alignment.center, children: [
            const Positioned.fill(child: Glow()),
            Positioned(left: 24, top: 20, child: Pill(it.kind.en, icon: it.kind.icon, color: Colors.white, bg: Colors.white.withValues(alpha: .18), size: 21)),
            Positioned(right: 30, child: ArtView(it.art, size: 150)),
            if (it.kind == Res.video) Positioned(right: 74, child: Container(width: 76, height: 76, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, size: 56, color: Color(0xFF7A2E06)))),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 22, 26, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.title, style: tt(31), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(it.sub, style: bx(24, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(children: [
                Icon(it.offline ? Icons.offline_pin_outlined : Icons.download_outlined, size: 30, color: it.offline ? const Color(0xFF00875A) : P.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(it.offline ? it.id : 'Downloads with the chapter', style: bx(22, P.ink2), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: Z.tagBg, borderRadius: BorderRadius.circular(999)),
                  child: Text('Put on board', style: bx(22, P.primary, FontWeight.w700)),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    ),
  );
}

/// 07 · Class tools (from Zynetix School), redesigned: a strip of class stats, then rich cards.
class ToolsHubScreen extends StatelessWidget {
  const ToolsHubScreen({super.key, required this.samples});
  final ClassSamples samples;
  @override
  Widget build(BuildContext context) {
    final s = samples, l = Lang.en;
    final m = s.mastery.bySkill.expand((r) => r).toList();
    final avg = m.reduce((a, b) => a + b) / m.length;
    final lead = [...s.teams.teams]..sort((a, b) => b.xp.compareTo(a.xp));
    final weeksLeft = s.plan.examDate.difference(s.plan.today).inDays ~/ 7;
    final tools = [
      (Icons.auto_stories_outlined, 'Explainers', s.explainers.first.title.t(l), '${s.explainers.length} ready · watch · it’s like · mission', const [Color(0xFFD883B4), Color(0xFF8E3B6C)], Art.pendulum),
      (Icons.how_to_reg_outlined, 'Class quiz', '${s.questions.length} questions · ${s.questions.first.exams.join(' · ')}', 'Mark by roll number, no phones', const [Color(0xFF3D6DF2), Color(0xFF1A3FB0)], Art.graph),
      (Icons.timer_outlined, 'Mock tests', s.mocks.map((x) => x.exam).join(' · '), 'Real patterns, timers, +/− marking', const [Color(0xFF253238), Color(0xFF0F1619)], Art.wave),
      (Icons.functions, 'Formula drill', s.formulas.map((f) => f.chapter.t(l)).join(' · '), '${s.formulas.fold<int>(0, (a, f) => a + f.items.length)} formulas, cover and recall', const [Color(0xFF8A5FE6), Color(0xFF4A2C9E)], Art.graph),
      (Icons.groups_2_outlined, 'Teams', '${lead.first.name.t(l)} leads · ${lead.first.xp} XP', '${s.teams.streakDays}-day class streak', const [Color(0xFFE88A2E), Color(0xFFB24A0E)], Art.orbit),
      (Icons.event_note_outlined, 'Class plan', s.plan.exam.t(l), '$weeksLeft weeks to the exam', const [Color(0xFF00A07A), Color(0xFF0A5C50)], Art.earth),
      (Icons.grid_view_outlined, 'Mastery heatmap', '${s.mastery.chapters.length} chapters × ${s.mastery.skills.length} skills', 'Class average ${avg.round()}%', const [Color(0xFF0072B2), Color(0xFF023E66)], Art.atom),
      (Icons.terminal, 'Coding lab', s.code.title.t(l), s.code.chapter.t(l), const [Color(0xFF3A4A52), Color(0xFF141A1D)], Art.circuit),
      (Icons.print_outlined, 'Worksheets', '${s.questions.length} questions + answer key', 'Print or share as PDF', const [Color(0xFF9AA6AC), Color(0xFF4A5257)], Art.flask),
    ];
    return Shell(
      place: Place.tools,
      crumb: '1st PUC A · Physics · Zynetix School class tools',
      title: 'Class tools',
      actions: const [Pill('Works offline', icon: Icons.cloud_off_outlined, color: P.ink2, size: 26)],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 220,
          child: Row(children: [
            _Stat('Class streak', '${s.teams.streakDays} days', Icons.local_fire_department, const Color(0xFFE8613C), extra: Row(children: [for (final w in s.teams.week) Container(margin: const EdgeInsets.only(right: 8), width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: w ? const Color(0xFFE8613C) : const Color(0xFFE6E9E4)))])),
            const SizedBox(width: 36),
            _Stat('This period', '${s.teams.periodXp} / ${s.teams.goalXp} XP', Icons.bolt, const Color(0xFFE69F00), extra: Bar(value: s.teams.periodXp / s.teams.goalXp, color: const Color(0xFFE69F00))),
            const SizedBox(width: 36),
            _Stat('Class mastery', '${avg.round()}%', Icons.insights, P.primary, extra: Text('Weakest: ${s.mastery.revise.first.$1.t(l)}', style: bx(24, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 36),
            _Stat('Exam in', '$weeksLeft weeks', Icons.flag_outlined, const Color(0xFF00876A), extra: Text(s.plan.exam.t(l), style: bx(24, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        const SizedBox(height: 40),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            const cols = 3, gap = 36.0;
            final w = (box.maxWidth - gap * (cols - 1)) / cols, h = (box.maxHeight - gap * 2) / 3;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final (i, t) in tools.indexed)
                SizedBox(
                  width: w, height: h,
                  child: PCard(
                    pad: EdgeInsets.zero,
                    high: i == 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(P.r),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Container(
                          width: 220,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: t.$5, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                          child: Stack(children: [
                            const Positioned.fill(child: Glow()),
                            Positioned(right: -30, bottom: -30, child: ArtView(t.$6, size: 190, opacity: .35)),
                            Center(child: Icon(t.$1, size: 96, color: Colors.white)),
                          ]),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(34, 28, 30, 26),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.$2, style: tt(38)),
                              const SizedBox(height: 8),
                              Text(t.$3, style: bx(26, P.ink2, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 18),
                              Expanded(child: Align(alignment: Alignment.centerLeft, child: _preview(i, s))),
                              const SizedBox(height: 14),
                              Row(children: [
                                Expanded(child: Text(t.$4, style: bx(24, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                const Icon(Icons.arrow_forward, size: 36, color: P.primary),
                              ]),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]);
          }),
        ),
      ]),
    );
  }
}

/// A small live picture of what each tool holds.
Widget _preview(int i, ClassSamples s) {
  Widget chip(String t, Color c) => Container(
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
    child: Text(t, style: bx(22, c, FontWeight.w700)),
  );
  switch (i) {
    case 0:
      return Row(children: [for (final (k, t) in ['Watch', 'It’s like', 'Mission'].indexed) chip(t, k == 0 ? const Color(0xFF8E3B6C) : P.muted)]);
    case 1:
      return Wrap(spacing: 6, runSpacing: 6, children: [
        for (var r = 1; r <= 20; r++) Container(width: 30, height: 30, decoration: BoxDecoration(color: quizWrong.contains(r) ? const Color(0xFFC44D0B) : quizUnmarked.contains(r) ? const Color(0xFFE3E6E1) : const Color(0xFF00875A), borderRadius: BorderRadius.circular(8))),
      ]);
    case 2:
      return Row(children: [for (final m in s.mocks.take(2)) chip('${m.exam} · ${m.minutes} min', P.ink2)]);
    case 3:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF0EAFB), borderRadius: BorderRadius.circular(18)),
        child: MathText('\$${s.formulas.first.items[1].tex}\$', style: bx(30, const Color(0xFF4A2C9E))),
      );
    case 4:
      final max = s.teams.teams.map((t) => t.xp).reduce((a, b) => a > b ? a : b);
      return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (k, t) in s.teams.teams.indexed)
          Container(margin: const EdgeInsets.only(right: 12), width: 44, height: 70.0 * t.xp / max, decoration: BoxDecoration(color: Z.teamColors[k], borderRadius: BorderRadius.circular(10))),
      ]);
    case 5:
      return SizedBox(width: 380, child: Bar(value: s.plan.chapters.fold<double>(0, (a, c) => a + c.weeks * c.done) / s.plan.chapters.fold<int>(0, (a, c) => a + c.weeks), color: const Color(0xFF00876A), height: 20));
    case 6:
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final row in s.mastery.bySkill.take(3))
          Row(mainAxisSize: MainAxisSize.min, children: [for (final v in row) Container(margin: const EdgeInsets.all(3), width: 52, height: 22, decoration: BoxDecoration(color: (v < 50 ? const Color(0xFFE8613C) : v < 70 ? const Color(0xFFF2C14E) : const Color(0xFF3CC08E)).withValues(alpha: .35 + v / 200), borderRadius: BorderRadius.circular(6)))]),
      ]);
    case 7:
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: Z.stage, borderRadius: BorderRadius.circular(16)),
        child: Text(s.code.output.first, style: TextStyle(fontFamily: KxFonts.code, fontSize: 22, color: Z.green)),
      );
    default:
      return Row(children: [chip('Questions', P.ink2), chip('Answer key', P.ink2), chip('PDF', P.ink2)]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, this.color, {required this.extra});
  final String label, value;
  final IconData icon;
  final Color color;
  final Widget extra;
  @override
  Widget build(BuildContext context) => Expanded(
    child: PCard(
      pad: const EdgeInsets.fromLTRB(40, 32, 40, 32),
      child: Row(children: [
        Container(width: 104, height: 104, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(32)), child: Icon(icon, size: 56, color: color)),
        const SizedBox(width: 30),
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: bx(26, P.muted, FontWeight.w600)),
            Text(value, style: tt(46, P.ink, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            extra,
          ]),
        ),
      ]),
    ),
  );
}

/// Sample marks for question 1: wrong and unmarked roll numbers.
const quizWrong = [3, 8, 12, 17, 21, 26, 29, 34, 38], quizUnmarked = [15, 31];
const absent = [9, 22, 35];

/// 08 · Class quiz: the question, and marking the class by roll number.
class QuizMarkScreen extends StatelessWidget {
  const QuizMarkScreen({super.key, required this.samples});
  final ClassSamples samples;
  @override
  Widget build(BuildContext context) {
    final q = samples.questions.first;
    final phone = MediaQuery.sizeOf(context).width < 1200;
    final right = 40 - absent.length - quizWrong.length - quizUnmarked.length;
    final grid = _RollGrid(cols: phone ? 6 : 8);
    final tally = Row(children: [
      _Tally('Right', right, const Color(0xFF00875A)),
      SizedBox(width: phone ? 16 : 24),
      _Tally('Wrong', quizWrong.length, const Color(0xFFC44D0B)),
      SizedBox(width: phone ? 16 : 24),
      _Tally('Not marked', quizUnmarked.length, P.muted),
    ]);
    final question = PCard(
      pad: EdgeInsets.all(phone ? 36 : 52),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          const Pill('Question 1 of 9', color: P.ink2, size: 24),
          for (final e in q.exams) Pill(e, color: const Color(0xFFB07A00), size: 24),
        ]),
        SizedBox(height: phone ? 24 : 36),
        MathText(q.stem.en, style: tt(phone ? 36 : 50, P.ink, FontWeight.w600)),
        SizedBox(height: phone ? 24 : 40),
        for (final (i, o) in q.options.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: EdgeInsets.symmetric(horizontal: 30, vertical: phone ? 18 : 36),
            decoration: BoxDecoration(color: P.soft, borderRadius: BorderRadius.circular(26)),
            child: Row(children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: P.line, width: 3)), alignment: Alignment.center, child: Text('ABCD'[i], style: tt(30))),
              const SizedBox(width: 24),
              Expanded(child: MathText(o.en, style: bx(phone ? 30 : 42, P.ink, FontWeight.w500))),
            ]),
          ),
        if (!phone) ...[
          const Spacer(),
          Row(children: [
            const Icon(Icons.timer_outlined, size: 40, color: P.muted),
            const SizedBox(width: 12),
            Text('Ideal time ${q.idealTime} s · answer hidden until you reveal', style: bx(28, P.muted)),
          ]),
        ],
      ]),
    );
    final marking = PCard(
      pad: EdgeInsets.all(phone ? 32 : 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SecHead('Mark by roll number', icon: Icons.how_to_reg_outlined, trailing: phone ? null : Text('Tap once right · twice wrong', style: bx(26, P.muted))),
        SizedBox(height: phone ? 20 : 32),
        Expanded(child: grid),
        SizedBox(height: phone ? 20 : 32),
        tally,
        SizedBox(height: phone ? 20 : 32),
        Row(children: [
          Expanded(child: PButton(phone ? 'Rest right' : 'Mark the rest right', icon: Icons.done_all, filled: false)),
          SizedBox(width: phone ? 16 : 24),
          Expanded(child: PButton(phone ? 'Reveal' : 'Reveal answer', icon: Icons.visibility_outlined)),
        ]),
      ]),
    );
    return Shell(
      place: Place.tools,
      crumb: phone ? 'Class quiz · 1st PUC A' : 'Class tools  ›  Class quiz  ›  1st PUC A · warm-up from Motion in a Straight Line',
      title: phone ? 'Free fall' : 'Class quiz · free fall',
      actions: const [Pill('37 present · 3 absent', icon: Icons.groups_outlined, color: P.ink2, size: 26)],
      body: phone
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PCard(
                pad: const EdgeInsets.all(32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Pill('Q1 · NEET · JEE · KCET', color: Color(0xFFB07A00), size: 22),
                  const SizedBox(height: 18),
                  MathText(q.stem.en, style: tt(32, P.ink, FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 24),
              Expanded(child: marking),
              const SizedBox(height: 24),
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: question),
              const SizedBox(width: 44),
              SizedBox(width: 1180, child: marking),
            ]),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally(this.label, this.n, this.color);
  final String label;
  final int n;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$n', style: tt(48, color, FontWeight.w700)),
        Text(label, style: bx(24, color, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

class _RollGrid extends StatelessWidget {
  const _RollGrid({required this.cols});
  final int cols;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    const gap = 14.0;
    final rows = (40 / cols).ceil();
    final w = (box.maxWidth - gap * (cols - 1)) / cols, h = (box.maxHeight - gap * (rows - 1)) / rows;
    return Wrap(spacing: gap, runSpacing: gap, children: [
      for (var r = 1; r <= 40; r++)
        Builder(builder: (context) {
          final ab = absent.contains(r), wr = quizWrong.contains(r), un = quizUnmarked.contains(r);
          final c = ab ? const Color(0xFFF1F3EF) : wr ? const Color(0xFFC44D0B) : un ? Colors.white : const Color(0xFF00875A);
          final fg = ab ? Z.ghost : (wr || !un ? Colors.white : P.ink);
          return Container(
            width: w, height: h,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(22),
              border: un && !ab ? Border.all(color: P.line, width: 3) : null,
              boxShadow: !ab && !un ? [BoxShadow(color: c.withValues(alpha: .3), blurRadius: 12, offset: const Offset(0, 5))] : null,
            ),
            alignment: Alignment.center,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$r', style: tt(h > 100 ? 40 : 32, fg)),
              if (!un && !ab) ...[const SizedBox(width: 6), Icon(wr ? Icons.close : Icons.check, size: 28, color: Colors.white)],
              if (ab) ...[const SizedBox(width: 6), Text('ab', style: bx(20, Z.ghost, FontWeight.w600))],
            ]),
          );
        }),
    ]);
  });
}

/// 09 · End class: planned vs real time, what was covered, homework, attendance and the quiz.
class EndClassScreen extends StatelessWidget {
  const EndClassScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const steps = [('Recap', 3, 4), ('Nandi Hills?', 3, 3), ('g at surface', 6, 7), ('Height & depth', 8, 11), ('Pendulum sim', 5, 6), ('3D earth', 4, 3), ('Examples', 6, 5), ('Class quiz', 5, 6)];
    return Shell(
      place: Place.teach,
      crumb: '1st PUC A · Physics · Gravitation · Topic 3 · Wed 4 Nov, Period 2',
      title: 'Class summary',
      actions: const [
        PButton('Share board', icon: Icons.ios_share, filled: false),
        PButton('Save to class record', icon: Icons.check),
      ],
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              flex: 5,
              child: PCard(
                pad: const EdgeInsets.all(48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SecHead('Planned vs real time', icon: Icons.timer_outlined, trailing: Row(children: [
                    _Key('Planned', const Color(0xFFCBD3DC)),
                    const SizedBox(width: 24),
                    _Key('Real', P.primary),
                    const SizedBox(width: 32),
                    Text('40 → 45 min', style: tt(34, const Color(0xFFB45309))),
                  ])),
                  const SizedBox(height: 28),
                  Expanded(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final (t, p, r) in steps)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Text('$r′', style: bx(26, r > p + 1 ? const Color(0xFFB45309) : P.ink, FontWeight.w700)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: LayoutBuilder(builder: (context, c) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Expanded(child: Container(height: c.maxHeight * p / 12, decoration: BoxDecoration(color: const Color(0xFFCBD3DC), borderRadius: BorderRadius.circular(12)))),
                                  const SizedBox(width: 8),
                                  Expanded(child: Container(height: c.maxHeight * r / 12, decoration: BoxDecoration(gradient: LinearGradient(colors: r > p + 1 ? [const Color(0xFFF2A93B), const Color(0xFFD97706)] : [const Color(0xFF5B85F0), P.primary], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(12)))),
                                ])),
                              ),
                              const SizedBox(height: 14),
                              Text(t, style: bx(22, P.ink2, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              flex: 4,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: PCard(
                    pad: const EdgeInsets.all(48),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SecHead('Covered', icon: Icons.task_alt),
                      const SizedBox(height: 24),
                      for (final (on, t) in [(true, 'g = GM/R² ≈ 9.8 m/s², independent of the mass of the body.'), (true, 'Above the surface: g(1 − 2h/R); below: g(1 − d/R).'), (false, 'g is greatest at the surface and zero at the centre.')])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(on ? Icons.check_box : Icons.check_box_outline_blank, size: 44, color: on ? const Color(0xFF00875A) : P.muted),
                            const SizedBox(width: 18),
                            Expanded(child: Text(t, style: bx(28, on ? P.ink : P.muted), maxLines: 2)),
                          ]),
                        ),
                      const Spacer(),
                      Row(children: [
                        Text('Chapter finished', style: bx(28, P.ink, FontWeight.w600)),
                        const Spacer(),
                        Container(width: 104, height: 58, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: const Color(0xFFDDE1DA), borderRadius: BorderRadius.circular(29)), alignment: Alignment.centerLeft, child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: PCard(
                    pad: const EdgeInsets.all(48),
                    color: const Color(0xFFFFF8EC),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SecHead('Homework', icon: Icons.assignment_outlined),
                      const SizedBox(height: 24),
                      Text('A body weighs 72 N on the surface. Find its weight at a height of R_E/2.', style: bx(32, P.ink, FontWeight.w500)),
                      const SizedBox(height: 16),
                      Text('Answer: 32 N · from the lesson', style: bx(26, P.muted)),
                      const Spacer(),
                      const Row(children: [Pill('Worksheet + key', icon: Icons.print_outlined, color: Color(0xFFB07A00), size: 24), SizedBox(width: 12), Pill('Next: Topic 4', icon: Icons.arrow_forward, color: P.primary, size: 24)]),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(width: 44),
        SizedBox(
          width: 820,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: PCard(
                pad: const EdgeInsets.all(48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SecHead('Attendance', icon: Icons.how_to_reg_outlined, trailing: Pill('37 / 40', solid: true, color: Color(0xFF00875A), size: 26)),
                  const SizedBox(height: 12),
                  Text('Taken in one tap at the start · absent: ${absent.join(', ')}', style: bx(26, P.muted)),
                  const SizedBox(height: 28),
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      const cols = 10, gap = 10.0;
                      final w = (box.maxWidth - gap * (cols - 1)) / cols, h = (box.maxHeight - gap * 3) / 4;
                      return Wrap(spacing: gap, runSpacing: gap, children: [
                        for (var r = 1; r <= 40; r++)
                          Container(
                            width: w, height: h,
                            decoration: BoxDecoration(color: absent.contains(r) ? const Color(0xFFFDF0E8) : const Color(0xFFE7F4EE), borderRadius: BorderRadius.circular(16), border: absent.contains(r) ? Border.all(color: const Color(0xFFC44D0B), width: 3) : null),
                            alignment: Alignment.center,
                            child: Text('$r', style: bx(26, absent.contains(r) ? const Color(0xFFA0430C) : const Color(0xFF1D6E4F), FontWeight.w700)),
                          ),
                      ]);
                    }),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: PCard(
                pad: const EdgeInsets.all(48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SecHead('Class quiz', icon: Icons.quiz_outlined),
                  const SizedBox(height: 24),
                  Row(children: [
                    Ring(value: 26 / 37, size: 200, stroke: 24, color: const Color(0xFF00875A), track: const Color(0xFFE6E9E4), center: Column(mainAxisSize: MainAxisSize.min, children: [Text('70%', style: tt(48, P.ink, FontWeight.w700)), Text('right', style: bx(24, P.muted))])),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('26 of 37 right', style: tt(38)),
                        const SizedBox(height: 8),
                        Text('Trap “4.5 s” (h/g, no root): 7 rolls', style: bx(26, const Color(0xFFA0430C)), maxLines: 2),
                      ]),
                    ),
                  ]),
                  const Spacer(),
                  Text('Help next time', style: bx(24, P.muted, FontWeight.w700)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 12, runSpacing: 12, children: [for (final r in quizWrong) Pill('Roll $r', color: const Color(0xFFC44D0B), size: 24)]),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.t, this.c);
  final String t;
  final Color c;
  @override
  Widget build(BuildContext context) => Row(children: [Container(width: 28, height: 28, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8))), const SizedBox(width: 10), Text(t, style: bx(26, P.ink2))]);
}

/// 10 · Reports: year plan and pacing, then class mastery.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, required this.samples});
  final ClassSamples samples;
  @override
  Widget build(BuildContext context) {
    final plan = samples.plan, m = samples.mastery;
    final totalW = plan.chapters.fold<int>(0, (a, c) => a + c.weeks) + plan.revisionWeeks;
    final elapsed = plan.today.difference(plan.start).inDays / 7;
    final span = plan.examDate.difference(plan.start).inDays / 7;
    final done = plan.chapters.fold<double>(0, (a, c) => a + c.weeks * c.done);
    final expected = totalW * elapsed / span;
    return Shell(
      place: Place.reports,
      crumb: '1st PUC A · Physics · ${plan.exam.en}',
      title: 'Reports',
      actions: [
        for (final (i, t) in ['Year plan & pacing', 'Class mastery', 'Class history'].indexed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
            decoration: BoxDecoration(color: i < 2 ? P.ink : Colors.white, borderRadius: BorderRadius.circular(999), border: i < 2 ? null : Border.all(color: const Color(0xFFDDE1DA), width: 2)),
            child: Text(t, style: bx(26, i < 2 ? Colors.white : P.ink, FontWeight.w600)),
          ),
      ],
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 640,
          child: PCard(
            pad: const EdgeInsets.all(48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SecHead('Year plan & pacing', icon: Icons.timeline, trailing: Row(children: [
                _Big('${done.toStringAsFixed(1)} wk', 'taught'),
                const SizedBox(width: 48),
                _Big('${expected.toStringAsFixed(1)} wk', 'planned by today'),
                const SizedBox(width: 48),
                _Big('${(expected - done).toStringAsFixed(1)} wk', 'behind', color: const Color(0xFFB45309)),
              ])),
              const SizedBox(height: 36),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final unit = c.maxWidth / totalW;
                  final now = plan.chapters.indexWhere((ch) => ch.done < 1);
                  final mx = c.maxWidth * expected / totalW;
                  return Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                      left: 0, right: 0, top: 30, height: 150,
                      child: Row(children: [
                        for (final (i, ch) in plan.chapters.indexed)
                          Container(
                            width: ch.weeks * unit - 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(color: ch.done >= 1 ? const Color(0xFFD6EFE3) : P.soft, borderRadius: BorderRadius.circular(18), border: i == now ? Border.all(color: P.primary, width: 5) : null),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(children: [
                              if (ch.done > 0 && ch.done < 1) FractionallySizedBox(widthFactor: ch.done, child: Container(color: Z.tagBg)),
                              Center(child: Text('${i + 1}', style: tt(34, ch.done >= 1 ? const Color(0xFF1D6E4F) : (i == now ? P.primary : P.muted), FontWeight.w700))),
                            ]),
                          ),
                        Expanded(child: Container(decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Text('Rev.', style: bx(24, const Color(0xFF8A5A00), FontWeight.w700)))),
                      ]),
                    ),
                    Positioned(left: mx - 3, top: 0, height: 210, child: Container(width: 6, decoration: BoxDecoration(color: P.ink, borderRadius: BorderRadius.circular(3)))),
                    Positioned(left: (mx - 160).clamp(0, c.maxWidth - 320), top: 214, child: SizedBox(width: 320, child: Text('Planned by today', textAlign: TextAlign.center, style: bx(24, P.ink, FontWeight.w700)))),
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Row(children: [
                        _Callout('Taught', '${plan.chapters.where((ch) => ch.done >= 1).length} chapters', const Color(0xFF00875A), Icons.check_circle),
                        _Callout('Now', '${now + 1} · ${plan.chapters[now].title.en} · ${(plan.chapters[now].done * 100).round()}%', P.primary, Icons.play_circle),
                        _Callout('Next', '${now + 2} · ${plan.chapters[now + 1].title.en}', P.ink2, Icons.arrow_circle_right),
                        _Callout('Exam', '22 Feb 2027 · ${plan.revisionWeeks} weeks revision', const Color(0xFFB45309), Icons.flag_circle),
                      ]),
                    ),
                  ]);
                }),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 40),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              flex: 3,
              child: PCard(
                pad: const EdgeInsets.all(48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SecHead('Class mastery · chapters × skills', icon: Icons.grid_view, trailing: Row(children: [for (final (t, c) in [('< 50', const Color(0xFFE8613C)), ('50–69', const Color(0xFFF2C14E)), ('70+', const Color(0xFF3CC08E))]) ...[const SizedBox(width: 18), _Key(t, c)]])),
                  const SizedBox(height: 24),
                  Row(children: [const SizedBox(width: 300), for (final s in m.skills) Expanded(child: Text(s.en, textAlign: TextAlign.center, style: bx(24, P.muted, FontWeight.w600)))]),
                  const SizedBox(height: 10),
                  for (final (i, row) in m.bySkill.indexed)
                    Expanded(
                      child: Row(children: [
                        SizedBox(width: 300, child: Text(m.chapters[i].en, style: bx(26, P.ink, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        for (final v in row)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: (v < 50 ? const Color(0xFFE8613C) : v < 70 ? const Color(0xFFF2C14E) : const Color(0xFF3CC08E)).withValues(alpha: .25 + v / 160), borderRadius: BorderRadius.circular(16)),
                              alignment: Alignment.center,
                              child: Text('$v', style: bx(26, P.ink, FontWeight.w700)),
                            ),
                          ),
                      ]),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              flex: 2,
              child: PCard(
                pad: const EdgeInsets.all(48),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SecHead('Revise next', icon: Icons.flag_outlined),
                  const SizedBox(height: 24),
                  for (final (t, ch, v) in m.revise.take(4))
                    Expanded(
                      child: Row(children: [
                        Ring(value: v / 100, size: 96, stroke: 12, color: v < 50 ? const Color(0xFFE8613C) : const Color(0xFFE69F00), track: const Color(0xFFE6E9E4), center: Text('$v', style: tt(28))),
                        const SizedBox(width: 26),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.en, style: bx(28, P.ink, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(m.chapters[ch].en, style: bx(24, P.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                        const Pill('Formula drill', size: 22),
                      ]),
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

class _Callout extends StatelessWidget {
  const _Callout(this.k, this.v, this.c, this.i);
  final String k, v;
  final Color c;
  final IconData i;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(children: [
      Icon(i, size: 44, color: c),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: bx(22, P.muted, FontWeight.w600)),
          Text(v, style: bx(27, P.ink, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
      const SizedBox(width: 20),
    ]),
  );
}

class _Big extends StatelessWidget {
  const _Big(this.v, this.l, {this.color = P.ink});
  final String v, l;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(v, style: tt(40, color, FontWeight.w700)), Text(l, style: bx(24, P.muted))]);
}
