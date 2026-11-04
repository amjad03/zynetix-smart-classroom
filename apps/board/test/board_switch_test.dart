import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/core/strings.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/exam_practice.dart';
import 'package:zynetix_board/features/insight/analysis.dart' show Exam;
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

  test('ISC: board parsing, Class XI/XII labels, its own board exam and readiness tag', () {
    expect(normalizeBoard('ISC'), 'isc');
    expect(normalizeBoard(null), 'kar_pu');
    expect(normalizeBoard('icse'), 'kar_pu');
    final ch = Chapter.fromJson({'id': 'puc2-commerce-01-x', 'subject': 'commerce', 'year': 'puc2', 'number': 1, 'title': {'en': 'X'}, 'boards': ['isc'], 'topics': [{'id': 'puc2-commerce-01-x.t1', 'title': {'en': 'T'}}]});
    expect(ch.forBoard('isc'), isTrue);
    expect(ch.forBoard('cbse'), isFalse);
    expect(ch.topicsFor('isc').length, 1);
    expect(yearLabel('puc1', 'isc', Lang.en), 'Class XI');
    expect(yearLabel('puc2', 'isc', Lang.kn), 'Class XII');
    expect(examsFor(['accountancy', 'commerce', 'economics', 'english'], 'isc'), ['ISC']);
    expect(examsFor(['physics', 'chemistry', 'maths'], 'isc'), containsAllInOrder(['JEE', 'ISC']));
    expect(examsFor(['physics'], 'isc'), isNot(contains('PUC')));
    expect(examNames['ISC'], 'ISC Board');
    expect(Exam.board.tagFor('isc'), 'ISC');
    expect(Exam.board.labelFor('isc'), 'ISC board');
    expect(subjectName('commerce', Lang.en), 'Commerce');
    expect(subjectIcon('commerce'), isNot(subjectIcon('nope')));
  });

  testWidgets('an ISC section: English only (no Kannada switch), "Class XI", Commerce with its icon', (t) async {
    final s = await testServices(prefs: {'board': 'isc', 'lang': 'kn', 'subjects': ['accountancy', 'commerce', 'economics', 'english']});
    expect(s.config.lang, Lang.en, reason: 'ISC is taught in English only');
    expect(s.config.kannadaOffered, isFalse);
    // Until the ISC Commerce syllabus is in the seed, give the board one chapter of it.
    s.syllabus['commerce'] ??= {'puc1': [Chapter(id: 'puc1-commerce-01-x', subject: 'commerce', year: 'puc1', number: 1, title: const L10n('Trade'), topics: const [], boards: const ['isc'])]};
    await pumpBoard(t, s);
    expect(find.byKey(const ValueKey('lang-kn')), findsNothing);
    await pumpBoard(t, s, home: const TeacherModeScreen());
    expect(find.text('Class XI'), findsOneWidget);
    expect(find.text('Commerce'), findsOneWidget);
    expect(find.byIcon(subjectIcon('commerce')), findsOneWidget);
    expect(find.text('1st PUC'), findsNothing);
  });

  testWidgets('a case-based question shows its passage above the stem', (t) async {
    final s = await testServices();
    final q = Question(id: 'q', topicId: 't', stem: const L10n('Which is correct?'), options: const [L10n('a'), L10n('b'), L10n('c'), L10n('d')], answer: 1, exams: const ['CBSE'], difficulty: 'easy', format: 'case_based', passage: const L10n('A shopkeeper buys 20 pens at ₹10 each.'));
    final pack = s.store.packs.first;
    final rec = SessionRecorder(outbox: Outbox(File('${tmpDir('o').path}/o')), sectionId: 's', mode: 'teacher', pack: pack, lesson: pack.lessons.values.first);
    await pumpBoard(t, s, home: Scaffold(body: Padding(padding: const EdgeInsets.all(40), child: QuizRunner(questions: [q], mode: QuizMode.monitor, lang: Lang.en, recorder: rec, room: ClassRoom(rollCount: 40)))));
    expect(find.byKey(const ValueKey('passage')), findsOneWidget);
    expect(find.text('A shopkeeper buys 20 pens at ₹10 each.'), findsOneWidget);
  });
}
