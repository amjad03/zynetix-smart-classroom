import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../blocks/challenge_view.dart' show StarRow;
import '../../core/services.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import '../home.dart' show openLesson;
import 'boss_battle.dart';
import 'game_stats.dart';
import 'game_store.dart';
import 'strings.dart';

/// The Game Zone: chapters as missions (stars per topic, a boss battle per chapter), badges and
/// streaks per roll number and for the section, and the section league.
class GameHubScreen extends StatefulWidget {
  const GameHubScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  String? _subject, _year;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), l = s.config.lang, text = Theme.of(context).textTheme;
    final game = GameStore.of(s.mastery);
    return ListenableBuilder(
      listenable: Listenable.merge([s.mastery, game]),
      builder: (context, _) {
        final stats = computeStats(mastery: s.mastery, game: game, rollCount: s.config.rollCount, now: s.clock());
        return DefaultTabController(
          length: 3,
          initialIndex: widget.initialTab,
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: Z.tap + 16,
              leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
              title: Text(gt('gameHub', l), style: context.narrow ? text.headlineMedium : text.headlineLarge),
              actions: [
                _Pill(key: const ValueKey('sectionPoints'), icon: Icons.bolt, label: '${stats.points}${context.narrow ? '' : ' ${gt('points', l)}'}'),
                const SizedBox(width: 12),
                if (stats.dayStreak > 0) ...[_Pill(icon: Icons.local_fire_department, label: '${stats.dayStreak}'), const SizedBox(width: 12)],
                SizedBox(width: context.narrow ? 4 : 16),
              ],
              bottom: TabBar(
                labelStyle: zText(context.narrow ? 28 : 34, FontWeight.w700),
                unselectedLabelStyle: zText(context.narrow ? 26 : 32, FontWeight.w500),
                tabs: [
                  Tab(height: Z.tap, text: gt('missions', l)),
                  Tab(height: Z.tap, text: gt('badges', l)),
                  Tab(height: Z.tap, text: gt('league', l)),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _missions(context, s, game, l),
                _BadgesTab(stats: stats, lang: l),
                _LeagueTab(sectionId: s.config.sectionId, label: s.config.sectionLabel, points: stats.points, lang: l),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _missions(BuildContext context, Services s, GameStore game, Lang l) {
    final subjects = s.subjects;
    final subject = _subject ?? subjects.firstOrNull;
    final year = _year ?? s.config.year;
    final chapters = subject == null ? const <Chapter>[] : [for (final c in s.chapters(subject, year)) if (s.store.byChapter(c.id) != null) c];
    final pad = context.narrow ? 16.0 : 32.0;
    return ListView(
      padding: EdgeInsets.all(pad),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(minimumSize: Size(context.narrow ? 110 : 180, Z.tap - 16), textStyle: zText(context.narrow ? 24 : 28)),
              segments: [for (final y in const ['puc1', 'puc2']) ButtonSegment(value: y, label: Text(yearLabel(y, s.config.board, l)))],
              selected: {year},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _year = v.first),
            ),
            for (final sub in subjects)
              ChoiceChip(
                key: ValueKey('subject:$sub'),
                label: Text(subjectName(sub, l), style: zText(28)),
                selected: sub == subject,
                onSelected: (_) => setState(() => _subject = sub),
              ),
          ],
        ),
        const SizedBox(height: Z.gap),
        if (chapters.isEmpty) Text(gt('noPacks', l), style: Theme.of(context).textTheme.bodyLarge),
        for (final (i, ch) in chapters.indexed) _MissionNode(index: i, last: i == chapters.length - 1, chapter: ch, game: game, lang: l),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    decoration: BoxDecoration(color: Z.accent.withValues(alpha: 0.18), border: Border.all(color: Z.accent, width: 3), borderRadius: BorderRadius.circular(Z.radius)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: Z.accent),
        const SizedBox(width: 6),
        Text(label, style: zText(30, FontWeight.w800)),
      ],
    ),
  );
}

/// One chapter on the mission path: zig-zags left and right on a wide screen, joined by a trail.
class _MissionNode extends StatelessWidget {
  const _MissionNode({required this.index, required this.last, required this.chapter, required this.game, required this.lang});
  final int index;
  final bool last;
  final Chapter chapter;
  final GameStore game;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), text = Theme.of(context).textTheme;
    final pack = s.store.byChapter(chapter.id)!;
    final topics = pack.chapter.topicsFor(s.config.board);
    final st = chapterStars(s.mastery, game, topics);
    final boss = game.bossBeaten(chapter.id);
    final done = st.of > 0 && st.got == st.of;
    final color = boss ? Z.correct : (st.got > 0 ? Z.accent : Colors.white38);
    final card = Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius), side: BorderSide(color: color, width: 4)),
      child: InkWell(
        key: ValueKey('mission:${chapter.id}'),
        borderRadius: BorderRadius.circular(Z.radius),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChapterMissionScreen(pack: pack))),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: color,
                child: boss ? const Icon(Icons.shield, size: 44, color: Colors.white) : Text('${chapter.number}', style: zText(34, FontWeight.w800).copyWith(color: Colors.black)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chapter.title.t(lang), style: text.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 36, color: Z.accent),
                        const SizedBox(width: 6),
                        Text('${st.got} / ${st.of}', style: zText(28, FontWeight.w700)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(value: st.of == 0 ? 0 : st.got / st.of, minHeight: 14, color: Z.accent, backgroundColor: Colors.white12),
                          ),
                        ),
                        if (done || boss) ...[const SizedBox(width: 12), Icon(boss ? Icons.emoji_events : Icons.check_circle, size: 40, color: boss ? Z.accent : Z.correct)],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide = !context.narrow && !context.portrait;
        final w = wide ? box.maxWidth * 0.62 : box.maxWidth;
        return Column(
          children: [
            Align(
              alignment: wide ? (index.isEven ? Alignment.centerLeft : Alignment.centerRight) : Alignment.center,
              child: SizedBox(width: w, child: card),
            ),
            if (!last)
              SizedBox(
                height: 48,
                width: box.maxWidth,
                child: CustomPaint(painter: _TrailPainter(fromLeft: wide ? index.isEven : null, w: w, color: color)),
              ),
          ],
        );
      },
    );
  }
}

/// The dotted trail from one mission to the next.
class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.fromLeft, required this.w, required this.color});
  final bool? fromLeft;
  final double w;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final a = fromLeft == null ? size.width / 2 : (fromLeft! ? w / 2 : size.width - w / 2);
    final b = fromLeft == null ? size.width / 2 : (fromLeft! ? size.width - w / 2 : w / 2);
    final p = Paint()..color = color.withValues(alpha: 0.7);
    for (var t = 0.0; t <= 1.0001; t += 0.1) {
      canvas.drawCircle(Offset(a + (b - a) * t, size.height * t), 5, p);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.fromLeft != fromLeft || old.w != w || old.color != color;
}

/// One chapter's mission: its topics with the class's stars, a Play button for each, and the
/// chapter's boss battle (teams or roll call).
class ChapterMissionScreen extends StatelessWidget {
  const ChapterMissionScreen({super.key, required this.pack});
  final InstalledPack pack;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), l = s.config.lang, text = Theme.of(context).textTheme;
    final game = GameStore.of(s.mastery);
    return ListenableBuilder(
      listenable: Listenable.merge([s.mastery, game]),
      builder: (context, _) {
        final topics = pack.chapter.topicsFor(s.config.board);
        final st = chapterStars(s.mastery, game, topics);
        void boss(QuizMode m) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BossBattleScreen(pack: pack, mode: m)));
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: Z.tap + 16,
            leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
            title: Text(pack.chapter.title.t(l), style: context.narrow ? text.headlineMedium : text.headlineLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [_Pill(icon: Icons.star_rounded, label: '${st.got}/${st.of}'), SizedBox(width: context.narrow ? 12 : 24)],
          ),
          body: ListView(
            padding: EdgeInsets.all(context.narrow ? 16 : 32),
            children: [
              Card(
                color: const Color(0xFF4A148C),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Flex(
                    direction: context.portrait ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: context.portrait ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      Icon(game.bossBeaten(pack.chapter.id) ? Icons.emoji_events : Icons.shield_outlined, size: 72, color: Z.accent),
                      const SizedBox(width: 20, height: 12),
                      _flexIf(
                        !context.portrait,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(gt('bossBattle', l), style: text.headlineLarge),
                            Text(gt('bossBattleSub', l), style: text.bodyLarge),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20, height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          BigButton(key: const ValueKey('boss:team'), icon: Icons.groups_outlined, label: '${gt('fight', l)}: ${gt('teams', l)}', color: Z.wrong, onPressed: () => boss(QuizMode.team)),
                          BigButton(key: const ValueKey('boss:roll'), icon: Icons.casino_outlined, label: gt('rollCall', l), filled: false, onPressed: () => boss(QuizMode.rollCall)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Z.gap),
              for (final t in topics)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      StarRow(stars: topicStars(s.mastery, game, t.id), size: 40),
                      const SizedBox(width: 16),
                      Expanded(child: Text(t.title.t(l), style: text.bodyLarge)),
                      if (pack.lessons[t.id] case final lesson?)
                        BigButton(collapse: true, key: ValueKey('play:${t.id}'), icon: Icons.play_arrow, label: tr('start', l), onPressed: () => openLesson(context, pack, lesson)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// [child], made to fill the free width of a Row when [expand] (a Column in portrait cannot).
Widget _flexIf(bool expand, Widget child) => expand ? Expanded(child: child) : child;

class _BadgesTab extends StatelessWidget {
  const _BadgesTab({required this.stats, required this.lang});
  final SectionStats stats;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final l = lang, text = Theme.of(context).textTheme;
    Widget stat(IconData i, String v, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 40, color: Z.accent), const SizedBox(width: 8), Text(v, style: zText(44, FontWeight.w800))]),
        Text(label, style: text.bodyMedium),
      ],
    );
    return ListView(
      padding: EdgeInsets.all(context.narrow ? 16 : 32),
      children: [
        Text(gt('sectionBadges', l), style: text.headlineLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 40,
          runSpacing: 16,
          children: [
            stat(Icons.bolt, '${stats.points}', gt('points', l)),
            stat(Icons.star_rounded, '${stats.stars}', gt('stars', l)),
            stat(Icons.local_fire_department, '${stats.dayStreak}', gt('dayStreak', l)),
            stat(Icons.trending_up, '${stats.bestStreak}', gt('bestStreak', l)),
          ],
        ),
        const SizedBox(height: Z.gap),
        Wrap(spacing: 16, runSpacing: 16, children: [for (final b in GameBadge.forSection) BadgeTile(badge: b, earned: stats.badges.contains(b), lang: l)]),
        const SizedBox(height: Z.gap * 2),
        Text(gt('rollBadges', l), style: text.headlineLarge),
        const SizedBox(height: 12),
        if (stats.rolls.isEmpty) Text(gt('noRolls', l), style: text.bodyLarge),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [for (final r in stats.rolls) _RollCard(stats: r, lang: l)],
        ),
      ],
    );
  }
}

/// A badge, lit when earned.
class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.badge, required this.earned, required this.lang, this.width = 300});
  final GameBadge badge;
  final bool earned;
  final Lang lang;
  final double width;
  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('badge:${badge.name}:${earned ? 'on' : 'off'}'),
    width: width,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: earned ? Z.accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: earned ? Z.accent : Colors.white24, width: 3),
      borderRadius: BorderRadius.circular(Z.radius),
    ),
    child: Row(
      children: [
        Icon(badge.icon, size: 48, color: earned ? Z.accent : Colors.white30),
        const SizedBox(width: 12),
        Expanded(
          child: Text(gt(badge.key, lang), style: zText(24, FontWeight.w600).copyWith(color: earned ? null : Colors.white38), maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

class _RollCard extends StatelessWidget {
  const _RollCard({required this.stats, required this.lang});
  final RollStats stats;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final l = lang, r = stats;
    return SizedBox(
      width: 360,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          key: ValueKey('roll:${r.roll}'),
          borderRadius: BorderRadius.circular(Z.radius),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('${tr('rollNo', l)} ${r.roll} · ${r.points} ${gt('points', l)}', style: zText(40, FontWeight.w700)),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Wrap(spacing: 12, runSpacing: 12, children: [for (final b in GameBadge.forRoll) BadgeTile(badge: b, earned: r.badges.contains(b), lang: l)]),
                ),
              ),
              actions: [BigButton(icon: Icons.close, label: tr('close', l), onPressed: () => Navigator.pop(context))],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${tr('rollNo', l)} ${r.roll}', style: zText(32, FontWeight.w800))),
                    Text('${r.points}', style: zText(32, FontWeight.w800).copyWith(color: Z.accent)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.local_fire_department, size: 32, color: r.currentStreak >= 3 ? Z.accent : Colors.white38),
                    Expanded(child: Text(' ${r.currentStreak} ${gt('inARow', l)}', style: zText(22), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.star_rounded, size: 30, color: Z.accent),
                    Text('${r.stars}', style: zText(22)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      for (final b in GameBadge.forRoll.where(r.badges.contains).take(7))
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(b.icon, size: 36, color: Z.accent),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeagueTab extends StatelessWidget {
  const _LeagueTab({required this.sectionId, required this.label, required this.points, required this.lang});
  final String sectionId, label;
  final int points;
  final Lang lang;

  @override
  Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(
    future: SharedPreferences.getInstance(),
    builder: (context, snap) {
      final l = lang, text = Theme.of(context).textTheme;
      final server = snap.hasData ? parseLeague(snap.data!.getString('league')) : null;
      final rows = leagueTable(server, sectionId: sectionId, label: label, localPoints: points);
      return ListView(
        padding: EdgeInsets.all(context.narrow ? 16 : 32),
        children: [
          if (server == null)
            Container(
              key: const ValueKey('leagueOffline'),
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: Z.gap),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(Z.radius)),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 44),
                  const SizedBox(width: 12),
                  Expanded(child: Text(gt('offlineLeague', l), style: text.bodyLarge)),
                ],
              ),
            ),
          for (final (i, r) in rows.indexed)
            Container(
              key: ValueKey('league:${r.sectionId}'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: r.sectionId == sectionId ? Z.accent.withValues(alpha: 0.22) : Theme.of(context).colorScheme.surfaceContainerHighest,
                border: r.sectionId == sectionId ? Border.all(color: Z.accent, width: 4) : null,
                borderRadius: BorderRadius.circular(Z.radius),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: i < 3 ? Icon(Icons.emoji_events, size: 48, color: [Z.accent, const Color(0xFFB0BEC5), const Color(0xFFBF8A5A)][i]) : Text('${i + 1}', style: zText(36, FontWeight.w800)),
                  ),
                  Expanded(
                    child: Text(r.sectionId == sectionId ? '${r.label} · ${gt('you', l)}' : r.label, style: text.headlineMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${r.points}', style: zText(40, FontWeight.w800).copyWith(color: Z.accent)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(gt('leagueNote', l), style: text.bodyMedium),
        ],
      );
    },
  );
}
