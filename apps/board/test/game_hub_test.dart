import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/mastery.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/game/boss_battle.dart';
import 'package:zynetix_board/features/game/game_hub.dart';
import 'package:zynetix_board/features/game/game_store.dart';
import 'package:zynetix_board/main.dart';

import 'helpers.dart';

const chapterId = 'puc1-physics-02-motion-in-a-straight-line';
const league = '[{"sectionId":"demo-1puc-b","label":"1st PUC · B","points":40},{"sectionId":"demo-1puc-a","label":"1st PUC · A · PCMB","points":900}]';

void seed(Services services) {
  final now = DateTime.now();
  services.mastery.recordAll([
    for (var i = 0; i < 6; i++) Response(roll: 3 + i % 2, questionId: 'q$i', topicId: '$chapterId.t1', chapterId: chapterId, correct: i != 1, source: 'roll_call', at: now),
  ]);
  GameStore.of(services.mastery).recordChallenge(
    ChallengeResult(blockId: 'ch', lessonId: 'l', topicId: '$chapterId.t2', chapterId: chapterId, stars: 3, tries: 1, solved: true, mode: 'roll_call', roll: 3, at: now),
  );
}

void main() {
  testWidgets('hub: missions with stars, badges per roll number, offline league', (t) async {
    final s = await testServices();
    seed(s);
    await pumpBoard(t, s, home: const GameHubScreen());
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('mission:$chapterId')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mission:$chapterId')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('boss:team')), findsOneWidget);
    await t.tap(find.byIcon(Icons.arrow_back).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Badges'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('roll:3')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge:ace:on')), findsWidgets);
    await t.tap(find.byKey(const ValueKey('roll:3')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('badge:streak3:on')), findsOneWidget);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    await t.tap(find.text('League'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('leagueOffline')), findsOneWidget);
    expect(find.byKey(const ValueKey('league:demo-1puc-a')), findsOneWidget);
  });

  testWidgets('league from sync: every section, ranked', (t) async {
    final s = await testServices(prefs: {'league': league});
    await pumpBoard(t, s, home: const GameHubScreen(initialTab: 2));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('leagueOffline')), findsNothing);
    expect(find.byKey(const ValueKey('league:demo-1puc-b')), findsOneWidget);
    expect(t.getTopLeft(find.byKey(const ValueKey('league:demo-1puc-a'))).dy, lessThan(t.getTopLeft(find.byKey(const ValueKey('league:demo-1puc-b'))).dy));
  });

  testWidgets('boss battle: right answers drain the health bar; the class wins', (t) async {
    final s = await testServices();
    final pack = s.store.byChapter(chapterId)!;
    final qs = pack.questions.values.where((q) => q.format == 'mcq').take(4).toList();
    await pumpBoard(t, s, home: BossBattleScreen(pack: pack, questions: qs));
    final st = t.state<BossBattleScreenState>(find.byType(BossBattleScreen));
    expect(st.maxHp, 3);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(ValueKey('option-${qs[i].answer}')));
      await t.pump(const Duration(milliseconds: 500));
      expect(st.hp, 2 - i);
      if (i < 2) {
        await t.tap(find.text('Next question'));
        await t.pump(const Duration(milliseconds: 500));
      }
    }
    expect(st.won, isTrue);
    expect(find.byKey(const ValueKey('bossResult')), findsOneWidget);
    expect(GameStore.of(s.mastery).bossBeaten(chapterId), isTrue);
    expect(s.mastery.responses.length, 3);
    await t.pumpAndSettle();
  });

  for (final (size, display) in const [(Size(390, 844), 'normal'), (Size(844, 390), 'normal'), (Size(1920, 1080), 'classroom')]) {
    testWidgets('game screens fit $size $display', (t) async {
      final problems = <String>[];
      var where = '';
      final old = FlutterError.onError;
      FlutterError.onError = (e) => problems.add('$where: ${e.exceptionAsString().split('\n').first}');
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = await testServices(prefs: {'displaySize': display, 'league': league});
      seed(s);
      final pack = s.store.byChapter(chapterId)!;
      Future<void> show(String name, Widget home) async {
        where = name;
        await t.pumpWidget(ZynetixBoardApp(key: UniqueKey(), services: s, home: home));
        await t.pump(const Duration(milliseconds: 500));
      }

      for (var tab = 0; tab < 3; tab++) {
        await show('hub tab $tab', GameHubScreen(initialTab: tab));
        await t.pumpAndSettle();
      }
      await show('chapter mission', ChapterMissionScreen(pack: pack));
      for (var seed = 1; seed <= 4; seed++) {
        for (final m in [QuizMode.team, QuizMode.rollCall]) {
          await show('boss $m seed $seed', BossBattleScreen(pack: pack, mode: m, questions: bossQuestions(pack, s.config.board, random: Random(seed))));
        }
      }
      final st = t.state<BossBattleScreenState>(find.byType(BossBattleScreen));
      where = 'boss victory';
      for (var i = 0; i < st.maxHp; i++) {
        st.recorder.answer(questionId: 'q', mode: QuizMode.rollCall, chosen: 0, correct: true);
      }
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      FlutterError.onError = old;
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}
