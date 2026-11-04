import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/mastery.dart';
import '../../engine/model.dart';
import 'game_store.dart';

/// How points are earned (the same rules on every board, so the league is fair).
abstract final class GamePoints {
  static const answer = 10, star = 15, boss = 50;

  /// For every right answer after the second in a row.
  static const streak = 5;
}

/// A badge: a key into the game strings (`b.<id>`) and an icon.
enum GameBadge {
  first(Icons.flag_outlined),
  streak3(Icons.local_fire_department_outlined),
  streak5(Icons.local_fire_department),
  streak10(Icons.whatshot),
  sharp10(Icons.gps_fixed),
  sharp50(Icons.school_outlined),
  hundred(Icons.military_tech_outlined),
  master(Icons.workspace_premium_outlined),
  comeback(Icons.trending_up),
  ace(Icons.star),
  days3(Icons.event_available_outlined),
  week(Icons.calendar_month_outlined),
  boss(Icons.shield_outlined),
  stars30(Icons.auto_awesome),
  everyone(Icons.groups_outlined);

  const GameBadge(this.icon);
  final IconData icon;
  String get key => 'b.$name';

  /// Badges a roll number can earn, in display order.
  static const forRoll = [first, streak3, streak5, streak10, sharp10, sharp50, hundred, master, comeback, ace, days3];

  /// Badges the whole section earns together.
  static const forSection = [boss, stars30, everyone, days3, week, streak5, streak10, hundred, ace];
}

class RollStats {
  RollStats(this.roll);
  final int roll;
  int answered = 0, correct = 0, stars = 0, currentStreak = 0, bestStreak = 0, streakBonus = 0, dayStreak = 0;
  final badges = <GameBadge>{};
  int get points => correct * GamePoints.answer + stars * GamePoints.star + streakBonus;
}

class SectionStats {
  SectionStats({required this.rolls});

  /// Every roll number with a named answer or challenge, most points first.
  final List<RollStats> rolls;
  int answered = 0, correct = 0, stars = 0, bossWins = 0, streakBonus = 0, dayStreak = 0, bestStreak = 0;
  final badges = <GameBadge>{};
  int get points => correct * GamePoints.answer + stars * GamePoints.star + bossWins * GamePoints.boss + streakBonus;
}

/// The bonus of a run of answers: [GamePoints.streak] for each right answer after the second in
/// a row. Also returns the run still going at the end and the best run.
({int bonus, int current, int best}) streakOf(Iterable<bool> answers) {
  var bonus = 0, run = 0, best = 0;
  for (final ok in answers) {
    run = ok ? run + 1 : 0;
    if (run > 2) bonus += GamePoints.streak;
    best = max(best, run);
  }
  return (bonus: bonus, current: run, best: best);
}

/// Days in a row with any activity, ending today (or yesterday, so the streak is not lost before
/// today's class).
int dayStreak(Iterable<DateTime> when, DateTime now) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final days = {for (final d in when) day(d.toLocal())};
  var d = day(now.toLocal());
  if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (days.contains(d)) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

/// True when, on one topic, a wrong answer was followed by 3 right ones in a row.
bool comeback(List<Response> rs) {
  final byTopic = <String, List<bool>>{};
  for (final r in rs) {
    (byTopic[r.topicId] ??= []).add(r.correct);
  }
  for (final seq in byTopic.values) {
    var missed = false, run = 0;
    for (final ok in seq) {
      if (!ok) {
        missed = true;
        run = 0;
      } else if (missed && ++run >= 3) {
        return true;
      }
    }
  }
  return false;
}

/// Points, streaks and badges per roll number and for the section, from every answer on this
/// board (MasteryStore.responses) and every challenge and boss battle (GameStore). Pure.
SectionStats computeStats({required MasteryStore mastery, required GameStore game, required int rollCount, required DateTime now}) {
  final all = mastery.responses.toList()..sort((a, b) => a.at.compareTo(b.at));
  final byRoll = <int, List<Response>>{};
  for (final r in all) {
    if (r.roll != null) (byRoll[r.roll!] ??= []).add(r);
  }
  final chByRoll = <int, List<ChallengeResult>>{};
  for (final c in game.challenges) {
    if (c.roll != null) (chByRoll[c.roll!] ??= []).add(c);
  }
  final rolls = <RollStats>[];
  for (final roll in {...byRoll.keys, ...chByRoll.keys}) {
    final rs = byRoll[roll] ?? const <Response>[], cs = chByRoll[roll] ?? const <ChallengeResult>[];
    final st = RollStats(roll)
      ..answered = rs.length
      ..correct = rs.where((r) => r.correct).length
      ..stars = cs.fold(0, (a, c) => a + c.stars);
    final s = streakOf(rs.map((r) => r.correct));
    st
      ..streakBonus = s.bonus
      ..currentStreak = s.current
      ..bestStreak = s.best
      ..dayStreak = dayStreak([...rs.map((r) => r.at), ...cs.map((c) => c.at)], now);
    st.badges.addAll([
      if (st.correct >= 1) GameBadge.first,
      if (s.best >= 3) GameBadge.streak3,
      if (s.best >= 5) GameBadge.streak5,
      if (s.best >= 10) GameBadge.streak10,
      if (st.correct >= 10) GameBadge.sharp10,
      if (st.correct >= 50) GameBadge.sharp50,
      if (st.correct >= 100) GameBadge.hundred,
      if (mastery.rollTopics(roll).values.any((e) => e.level == Level.mastered)) GameBadge.master,
      if (comeback(rs)) GameBadge.comeback,
      if (cs.any((c) => c.stars == 3)) GameBadge.ace,
      if (st.dayStreak >= 3) GameBadge.days3,
    ]);
    rolls.add(st);
  }
  rolls.sort((a, b) => b.points != a.points ? b.points.compareTo(a.points) : a.roll.compareTo(b.roll));

  final sec = SectionStats(rolls: rolls)
    ..answered = all.length
    ..correct = all.where((r) => r.correct).length
    ..stars = game.challenges.fold(0, (a, c) => a + c.stars)
    ..bossWins = game.bosses.where((b) => b.won).length;
  // Streaks: each roll number's own, plus the whole class's answers given together.
  final together = streakOf(all.where((r) => r.roll == null && r.source != 'hands').map((r) => r.correct));
  sec
    ..streakBonus = rolls.fold(0, (a, r) => a + r.streakBonus) + together.bonus
    ..bestStreak = max(together.best, rolls.fold(0, (a, r) => max(a, r.bestStreak)))
    ..dayStreak = dayStreak([...all.map((r) => r.at), ...game.challenges.map((c) => c.at), ...game.bosses.map((b) => b.at)], now);
  sec.badges.addAll([
    if (sec.bossWins > 0) GameBadge.boss,
    if (sec.stars >= 30) GameBadge.stars30,
    if (rollCount > 0 && byRoll.length >= (rollCount * 0.8).ceil()) GameBadge.everyone,
    if (sec.dayStreak >= 3) GameBadge.days3,
    if (sec.dayStreak >= 7) GameBadge.week,
    if (sec.bestStreak >= 5) GameBadge.streak5,
    if (sec.bestStreak >= 10) GameBadge.streak10,
    if (sec.correct >= 100) GameBadge.hundred,
    if (game.challenges.any((c) => c.stars == 3)) GameBadge.ace,
  ]);
  return sec;
}

/// Stars (0–3) the class has on a topic: the best challenge result, or how well the class knows
/// it (1 once answered, 2 learning, 3 mastered), whichever is higher.
int topicStars(MasteryStore m, GameStore g, String topicId) {
  final e = m.classTopic(topicId);
  final known = e == null || e.n == 0
      ? 0
      : switch (e.level) {
          Level.mastered => 3,
          Level.learning => 2,
          _ => 1,
        };
  return max(known, g.topicStars[topicId] ?? 0);
}

/// Stars earned on a chapter's topics, out of 3 per topic.
({int got, int of}) chapterStars(MasteryStore m, GameStore g, List<Topic> topics) =>
    (got: topics.fold(0, (a, t) => a + topicStars(m, g, t.id)), of: topics.length * 3);

/// One row of the section league (from the server, through sync: config key `league`).
class LeagueRow {
  LeagueRow({required this.sectionId, required this.label, required this.points});
  final String sectionId, label;
  final int points;
}

/// The `league` config value: a JSON list of {sectionId, label, points}; null when absent or
/// unreadable (then the board shows this section only).
List<LeagueRow>? parseLeague(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final list = jsonDecode(raw) as List;
    final rows = [
      for (final e in list)
        if (e is Map && e['sectionId'] is String)
          LeagueRow(sectionId: e['sectionId'] as String, label: (e['label'] as String?) ?? e['sectionId'] as String, points: (e['points'] as num?)?.round() ?? 0),
    ];
    return rows.isEmpty ? null : rows;
  } catch (_) {
    return null;
  }
}

/// The table to show, most points first. This section is always in it: with the server's
/// points when it has them (they include every board in the section), else this board's.
List<LeagueRow> leagueTable(List<LeagueRow>? server, {required String sectionId, required String label, required int localPoints}) {
  final rows = [...?server];
  if (!rows.any((r) => r.sectionId == sectionId)) rows.add(LeagueRow(sectionId: sectionId, label: label, points: localPoints));
  rows.sort((a, b) => b.points.compareTo(a.points));
  return rows;
}
