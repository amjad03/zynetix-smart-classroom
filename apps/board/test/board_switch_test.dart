import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/features/participation.dart';
import 'package:zynetix_board/features/teacher_mode.dart';
import 'dart:io';

import 'helpers.dart';

Block _b(String id, [List<String>? boards]) => Block(BlockType.trick, {'id': id, 'type': 'trick', 'heading': {'en': 'h'}, 'body': {'en': 'b'}, 'boards': ?boards});

void main() {
  test('blocks and topics follow the board', () {
    final l = Lesson(id: 'l', chapterId: 'c', topicId: 't', title: const L10n('L'), minutes: 40, blocks: [_b('all'), _b('cbse', ['cbse']), _b('ka', ['kar_pu'])]);
    final p = InstalledPack(id: 'p', version: '1.0.0', chapter: Chapter(id: 'c', subject: 'physics', year: 'puc1', number: 1, title: const L10n('C'), topics: []), lessons: {}, questions: {}, mediaDir: '');
    expect(p.lessonFor(l, 'cbse').blocks.map((b) => b.id), ['all', 'cbse']);
    expect(p.lessonFor(l, 'kar_pu').blocks.map((b) => b.id), ['all', 'ka']);
    final ch = Chapter(id: 'c', subject: 's', year: 'puc1', number: 1, title: const L10n('C'), topics: [Topic('c.t1', const L10n('a'), null), Topic('c.t2', const L10n('b'), null, ['cbse'])], boards: const ['kar_pu', 'cbse']);
    expect(ch.topicsFor('kar_pu').map((t) => t.id), ['c.t1']);
    expect(ch.topicsFor('cbse').length, 2);
  });

  testWidgets('a CBSE section sees its subjects and "Class 11/12"; Karnataka-only subjects are hidden', (t) async {
    final s = await testServices(prefs: {'board': 'cbse', 'subjects': ['physics', 'statistics', 'english', 'accountancy']});
    expect(s.chapters('statistics', 'puc1'), isEmpty, reason: 'Statistics is a Karnataka PU subject');
    expect(s.chapters('english', 'puc2'), isNotEmpty);
    await pumpBoard(t, s, home: const TeacherModeScreen());
    expect(find.text('Class 11'), findsOneWidget);
    expect(find.text('Accountancy'), findsOneWidget);
    expect(find.text('1st PUC'), findsNothing);
  });

  testWidgets('a case-based question shows its passage above the stem', (t) async {
    final s = await testServices();
    final q = Question(id: 'q', topicId: 't', stem: const L10n('Which is correct?'), options: const [L10n('a'), L10n('b'), L10n('c'), L10n('d')], answer: 1, exams: const ['CBSE'], difficulty: 'easy', format: 'case_based', passage: const L10n('A shopkeeper buys 20 pens at ₹10 each.'));
    final pack = s.store.packs.first;
    final rec = SessionRecorder(outbox: Outbox(File('${Directory.systemTemp.createTempSync('o').path}/o')), sectionId: 's', mode: 'teacher', pack: pack, lesson: pack.lessons.values.first);
    await pumpBoard(t, s, home: Scaffold(body: Padding(padding: const EdgeInsets.all(40), child: QuizRunner(questions: [q], mode: QuizMode.monitor, lang: Lang.en, recorder: rec, room: ClassRoom(rollCount: 40)))));
    expect(find.byKey(const ValueKey('passage')), findsOneWidget);
    expect(find.text('A shopkeeper buys 20 pens at ₹10 each.'), findsOneWidget);
  });
}
