import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/mastery.dart';

Response r(int? roll, String t, bool ok) => Response(roll: roll, questionId: 'q', topicId: t, chapterId: 'c', correct: ok, source: 'roll_call', at: DateTime(2026));

void main() {
  test('estimates per roll and per topic, stuck and strong lists, buddies, and persistence', () {
    final f = File('${Directory.systemTemp.createTempSync('m').path}/m.jsonl');
    addTearDown(() => f.parent.deleteSync(recursive: true));
    final m = MasteryStore(file: f);
    m.recordAll([r(1, 'a', false), r(1, 'a', false), r(2, 'a', true), r(2, 'a', true), r(3, 'a', true), r(null, 'b', false), r(null, 'b', false)]);
    expect(m.rollTopic(1, 'a')!.level, Level.stuck);
    expect(m.rollTopic(2, 'a')!.level, Level.mastered);
    expect(m.rollTopic(3, 'a')!.level, Level.unknown); // one answer is not enough to judge
    expect(m.stuck('a'), [1]);
    expect(m.strong('a'), [2]);
    expect(m.buddies('a'), [(1, 2)]);
    expect(m.weakTopics(), ['b']); // the class missed b twice; a is mixed but above 0.5
    final again = MasteryStore(file: f);
    expect(again.responses.length, 7);
    expect(again.rollTopic(2, 'a')!.p, closeTo(m.rollTopic(2, 'a')!.p, 1e-9));
  });
}
