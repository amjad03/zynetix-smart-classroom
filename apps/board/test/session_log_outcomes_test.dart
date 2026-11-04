import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/session_log.dart';

void main() {
  test('each logged answer carries its topic, chapter and source (the API stores them for Outcomes)', () {
    final dir = Directory.systemTemp.createTempSync('zb-');
    final rec = SessionRecorder.raw(outbox: Outbox(File('${dir.path}/outbox.jsonl')), sectionId: 's', mode: 'teacher', chapterId: 'ch-a', topicId: 'ch-a.t1', lessonId: 'ch-a.t1.lesson', packVersion: '1.0.0');
    rec.answer(questionId: 'q1', mode: QuizMode.rollCall, roll: 7, chosen: 1, correct: true);
    rec.answer(questionId: 'q2', mode: QuizMode.monitor, chosen: null, correct: false, topicId: 'ch-b.t2', chapterId: 'ch-b', source: 'challenge');
    final a = rec.log['answers'] as List;
    expect(a[0], allOf(containsPair('topicId', 'ch-a.t1'), containsPair('chapterId', 'ch-a'), containsPair('source', 'roll_call'), containsPair('roll', 7)));
    expect(a[1], allOf(containsPair('topicId', 'ch-b.t2'), containsPair('chapterId', 'ch-b'), containsPair('source', 'challenge'), containsPair('mode', 'monitor')));
    expect((a[1] as Map).containsKey('roll'), isFalse);
  });
}
