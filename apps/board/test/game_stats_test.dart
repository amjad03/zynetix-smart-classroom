import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/mastery.dart';
import 'package:zynetix_board/features/game/boss_battle.dart';
import 'package:zynetix_board/features/game/game_stats.dart';
import 'package:zynetix_board/features/game/game_store.dart';

import 'helpers.dart';

final day = DateTime(2026, 11, 4, 10);
Response r(int? roll, bool ok, {String t = 'c.t1', DateTime? at, String s = 'roll_call'}) => Response(roll: roll, questionId: 'q', topicId: t, chapterId: 'c', correct: ok, source: s, at: at ?? day);
ChallengeResult ch(int stars, {int? roll, String t = 'c.t1', DateTime? at}) =>
    ChallengeResult(blockId: 'ch', lessonId: 'l', topicId: t, chapterId: 'c', stars: stars, tries: 1, solved: stars > 0, mode: 'roll_call', roll: roll, at: at ?? day);

void main() {
  test('streaks: a bonus for every right answer after the second in a row', () {
    expect(streakOf([true, true, true, true, false, true]), (bonus: 10, current: 1, best: 4));
    expect(streakOf([]), (bonus: 0, current: 0, best: 0));
  });

  test('day streaks run back from today, or from yesterday', () {
    final days = [for (var i = 0; i < 4; i++) day.subtract(Duration(days: i + 1))];
    expect(dayStreak(days, day), 4); // nothing yet today: still a 4-day streak
    expect(dayStreak([...days, day], day), 5);
    expect(dayStreak([day.subtract(const Duration(days: 3))], day), 0);
  });

  test('roll numbers earn points, streaks and badges; the section adds them up', () {
    final m = MasteryStore(), g = GameStore();
    m.recordAll([r(5, false), for (var i = 0; i < 5; i++) r(5, true), r(9, true), r(null, true, s: 'monitor')]);
    g.recordChallenge(ch(3, roll: 5));
    g.recordBoss(BossResult(chapterId: 'c', won: true, correct: 7, asked: 10, at: day));
    final st = computeStats(mastery: m, game: g, rollCount: 2, now: day);
    final five = st.rolls.first;
    expect(five.roll, 5);
    expect(five.correct, 5);
    expect(five.bestStreak, 5);
    expect(five.points, 5 * GamePoints.answer + 3 * GamePoints.star + 3 * GamePoints.streak);
    expect(five.badges, containsAll([GameBadge.first, GameBadge.streak3, GameBadge.streak5, GameBadge.comeback, GameBadge.ace, GameBadge.master]));
    expect(five.badges, isNot(contains(GameBadge.streak10)));
    expect(st.rolls[1].badges, {GameBadge.first});
    expect(st.correct, 7);
    expect(st.points, 7 * GamePoints.answer + 3 * GamePoints.star + GamePoints.boss + 3 * GamePoints.streak);
    expect(st.badges, containsAll([GameBadge.boss, GameBadge.everyone, GameBadge.ace, GameBadge.streak5]));
    expect(st.dayStreak, 1);
  });

  test('topic and chapter stars: the best of challenge stars and how well the class knows it', () {
    final m = MasteryStore(), g = GameStore();
    expect(topicStars(m, g, 'c.t1'), 0);
    m.record(r(null, false));
    expect(topicStars(m, g, 'c.t1'), 1);
    g.recordChallenge(ch(2));
    expect(topicStars(m, g, 'c.t1'), 2);
    m.recordAll([for (var i = 0; i < 6; i++) r(null, true, t: 'c.t2')]);
    expect(topicStars(m, g, 'c.t2'), 3);
  });

  test('the game store is kept on the board beside the mastery store', () {
    final dir = tmpDir('game');
    final m = MasteryStore(file: File('${dir.path}/mastery.jsonl'));
    final g = GameStore.of(m);
    expect(identical(GameStore.of(m), g), isTrue);
    g.recordChallenge(ch(2, roll: 3));
    g.recordBoss(BossResult(chapterId: 'c', won: true, correct: 7, asked: 10, at: day));
    File('${dir.path}/game.jsonl').writeAsStringSync('{"k":"chall', mode: FileMode.append); // torn line
    final again = GameStore(file: File('${dir.path}/game.jsonl'));
    expect(again.challenges.single.roll, 3);
    expect(again.bestStars('l', 'ch'), 2);
    expect(again.bossBeaten('c'), isTrue);
  });

  test('league: parsed from config, this section always listed', () {
    expect(parseLeague(null), isNull);
    expect(parseLeague('not json'), isNull);
    final rows = parseLeague('[{"sectionId":"a","label":"1st PUC A","points":120},{"sectionId":"b","label":"1st PUC B","points":300}]')!;
    final t = leagueTable(rows, sectionId: 'me', label: 'Me', localPoints: 200);
    expect([for (final x in t) x.sectionId], ['b', 'me', 'a']);
    expect(leagueTable(rows, sectionId: 'a', label: 'A', localPoints: 999).length, 2); // the server's points win
  });

  test('a boss needs 70% of the questions right', () {
    expect(bossHealth(10), 7);
    expect(bossHealth(4), 3);
    expect(bossHealth(1), 1);
  });
}
