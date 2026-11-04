// Every challenge block in content/packs: solvable with the board's own expression engine, and
// drawn without overflow on a phone (both ways up) and on the board.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/challenge_view.dart';
import 'package:zynetix_board/core/theme.dart';
import 'package:zynetix_board/core/ui_scale.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/game/game_store.dart';
import 'package:zynetix_board/features/participation.dart';

List<(String, Block)> contentChallenges() => [
  for (final f in Directory('../../content/packs').listSync(recursive: true).whereType<File>().where((f) => f.path.contains('/lessons/') && f.path.endsWith('.json')))
    for (final b in (jsonDecode(f.readAsStringSync())['blocks'] as List).cast<Map<String, dynamic>>())
      if (b['type'] == 'challenge') (f.path.split('/packs/').last, Block.fromJson(b)!),
];

void main() {
  final all = contentChallenges();

  test('there are at least 60 challenges and each is solvable on the board', () {
    expect(all.length, greaterThanOrEqualTo(60));
    for (final (where, b) in all) {
      final s = ChallengeSpec.of(b);
      expect(s.goal, isNotNull, reason: where);
      expect(s.hits(s.value(s.solution)), isTrue, reason: '$where: ${s.value(s.solution)}');
      final start = {for (final sl in (b.raw['sliders'] as List).cast<Map<String, dynamic>>()) sl['name'] as String: (sl['value'] as num).toDouble()};
      expect(s.hits(s.value(start)), isFalse, reason: '$where starts solved');
    }
  });

  for (final (size, scale) in const [(Size(390, 844), 0.5), (Size(844, 390), 0.5), (Size(1920, 1080), 1.0)]) {
    testWidgets('every content challenge fits $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final problems = <String>[];
      var where = '';
      final old = FlutterError.onError;
      FlutterError.onError = (e) => problems.add('$where: ${e.exceptionAsString().split('\n').first}');
      for (final (w, b) in all) {
        where = w;
        await t.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: zynetixTheme(),
            builder: (context, child) => UiScale(scale: scale, child: child!),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: ChallengeView(block: b, lang: Lang.en, room: ClassRoom(rollCount: 40), game: GameStore()),
              ),
            ),
          ),
        );
        await t.pump();
        // The finished state too: result, solution and explanation.
        t.state<ChallengeViewState>(find.byType(ChallengeView)).giveUp();
        await t.pump();
        await t.pump();
      }
      await t.pumpWidget(const SizedBox());
      FlutterError.onError = old;
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}
