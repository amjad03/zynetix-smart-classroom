import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/services.dart';
import '../../engine/model.dart';
import '../app/kit.dart' show showZxDialog, ZxButton, S, tr, toast;
import 'class_data.dart';
import 'class_quiz_screen.dart';
import 'class_kit.dart';
import 'strings.dart';

/// Teams by bench rows or houses: the leaderboard for this period, the class streak and the
/// period's XP goal. Teams are named after rivers and listed by roll-number range; points are
/// given to roll numbers, never to names.
class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key, required this.samples});
  final ClassSamples samples;

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final d = samples.teams;
      final ranked = [...d.teams.indexed]..sort((a, b) => b.$2.xp.compareTo(a.$2.xp));
      final top = ranked.first.$2.xp;
      final narrow = context.narrow;
      final board = ZPanel(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(ct('thisPeriod', l), style: zTitle(44))),
                Text('XP', style: zText(30, FontWeight.w600).copyWith(color: Z.muted)),
              ],
            ),
            const SizedBox(height: 24),
            for (final (rank, (i, t)) in ranked.indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
                    decoration: BoxDecoration(color: rank == 0 ? Z.highlight : Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
                    child: Row(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: rank == 0 ? Z.star : Z.panel, border: Border.all(color: rank == 0 ? Z.star : Z.line, width: 3)),
                          child: rank == 0 ? const Icon(Icons.emoji_events, size: 56, color: Colors.white) : Text('${rank + 1}', style: zText(44, FontWeight.w700).copyWith(color: Z.ink2)),
                        ),
                        const SizedBox(width: 32),
                        Container(width: 16, height: 112, decoration: BoxDecoration(color: Z.teamColors[i % 4], borderRadius: BorderRadius.circular(8))),
                        const SizedBox(width: 28),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(t.name.t(l), style: zTitle(52)),
                                  const SizedBox(width: 24),
                                  Text(ct('rolls', l, {'a': t.rolls.first, 'b': t.rolls.last}), style: zText(30, FontWeight.w500).copyWith(color: Z.muted)),
                                  const Spacer(),
                                  Text(ct('accuracy', l, {'p': (100 * t.right / math.max(1, t.asked)).round()}), style: zText(30, FontWeight.w600).copyWith(color: Z.correctLabel)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ZProgress(value: t.xp / top, height: 24, color: Z.teamColors[i % 4], track: Z.panel),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                        SizedBox(width: 220, child: Text('${t.xp}', textAlign: TextAlign.right, style: zTitle(72, FontWeight.w700).copyWith(color: Z.ink))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
      const days = ['M', 'T', 'W', 'T', 'F', 'S'];
      final streak = ZPanel(
        padding: const EdgeInsets.all(44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker(ct('classStreak', l), size: 30),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department, size: 104, color: Z.vermillion),
                const SizedBox(width: 16),
                Text(ct('days', l, {'n': d.streakDays}), style: zTitle(88, FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                for (final (i, ok) in d.week.indexed) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? Z.correct : Z.panel, border: Border.all(color: ok ? Z.correct : (i == 4 ? Z.primary : Z.line), width: i == 4 ? 6 : 3)),
                        child: ok ? const Icon(Icons.check, size: 44, color: Colors.white) : null,
                      ),
                      const SizedBox(height: 8),
                      Text(days[i], style: zText(28, FontWeight.w600).copyWith(color: i == 4 ? Z.primary : Z.muted)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );
      final goal = ZPanel(
        padding: const EdgeInsets.all(44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Kicker(ct('periodGoal', l), size: 30)),
                Text('${d.periodXp}', style: zTitle(60, FontWeight.w700).copyWith(color: Z.primary)),
                Text(' / ${d.goalXp} XP', style: zText(32, FontWeight.w500).copyWith(color: Z.muted)),
              ],
            ),
            const SizedBox(height: 20),
            ZProgress(value: d.periodXp / d.goalXp, height: 28),
          ],
        ),
      );
      final feed = ZPanel(
        padding: const EdgeInsets.all(44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Kicker(ct('recentXp', l), size: 30),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final (roll, xp, why) in d.feed.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            RollChip(roll, size: 34, color: Z.primary, background: Z.tagBg),
                            const SizedBox(width: 20),
                            Expanded(child: Text(why.t(l), style: zText(32, FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('+$xp', style: zText(36, FontWeight.w700).copyWith(color: Z.correct)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      return ClassScaffold(
        crumbs: [samples.year.t(l), ct('hubTitle', l)],
        title: ct('teams', l),
        trailing: [if (!narrow) BarChip(ct('privacy', l), icon: Icons.shield_outlined, color: Z.correctLabel, background: Z.correctBg)],
        bottomLeft: [BigButton(key: const ValueKey('awardXp'), icon: Icons.add_circle_outline, label: ct('award', l), filled: false, onPressed: () => awardXp(context))],
        bottomRight: [BigButton(icon: Icons.how_to_reg_outlined, label: ct('classQuiz', l), onPressed: samples.questions.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClassQuizScreen(samples: samples))))],
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 13, child: board),
            const SizedBox(width: 32),
            Expanded(flex: 8, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [streak, const SizedBox(height: 32), goal, const SizedBox(height: 32), Expanded(child: feed)])),
          ],
        ),
      );
    },
  );
}

/// Gives a house XP (for a good answer, homework, tidy benches); it can be undone.
Future<void> awardXp(BuildContext context) async {
  final s = ServicesScope.of(context);
  final l = s.config.lang;
  final houses = s.school.houses;
  var house = 0;
  final xp = await showZxDialog<int>(
    context,
    title: tr(l, 'Give XP to a house', 'ಮನೆಗೆ XP ನೀಡಿ'),
    body: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          for (final (i, h) in houses.indexed)
            ZxButton('${h.name.t(l)} · ${h.from}–${h.to}', key: ValueKey('house-$i'), bg: i == house ? S.ink : S.mist, fg: i == house ? Colors.white : S.ink, height: 110, size: 32, onTap: () => set(() => house = i)),
        ]),
        const SizedBox(height: 36),
        Wrap(spacing: 16, runSpacing: 16, children: [
          for (final v in const [10, 20, 50]) ZxButton('+$v XP', key: ValueKey('xp-$v'), icon: Icons.bolt_rounded, bg: S.violet, height: 120, size: 36, onTap: () => Navigator.pop(ctx, v)),
        ]),
      ]),
    ),
  );
  if (xp == null) return;
  s.school.addXp(house, xp);
  s.school.pushUndo(L10n('$xp XP to ${houses[house].name.en}', '${houses[house].name.t(Lang.kn)}ಗೆ $xp XP'), () {
    final hs = s.school.houses;
    hs[house] = hs[house].copyWith(xp: (hs[house].xp - xp).clamp(0, 1 << 30));
    s.school.setHouses(hs);
  });
  if (context.mounted) toast(context, tr(l, '+$xp XP to ${houses[house].name.en}', '${houses[house].name.t(l)}ಗೆ +$xp XP'));
}
