import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/interactive_view.dart';
import 'package:zynetix_board/blocks/whiteboard_view.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/narrator.dart';
import 'package:zynetix_board/engine/period.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/features/exam_practice.dart';
import 'package:zynetix_board/features/participation.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/features/self_learning.dart';
import 'package:zynetix_board/features/smartboard.dart';

import 'fixtures.dart';
import 'helpers.dart';

const motion = 'puc1-physics-02-motion-in-a-straight-line';

/// A pushed route's first frame is offstage: two frames show it.
Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

String stepText(WidgetTester t) => (t.widget(find.byKey(const ValueKey('wbStep'))) as Text).data!;
String readout(WidgetTester t, int i) => (t.widget(find.descendant(of: find.byKey(ValueKey('readout-$i')), matching: find.byType(Text)).last) as Text).data!;

void main() {
  group('whiteboard', () {
    testWidgets('Teacher Mode: Next step reveals steps one at a time, and reads them once Read aloud is on', (t) async {
      final s = await testServices();
      final p = s.store.byChapter(motion)!;
      await pumpBoard(t, s, home: LessonPlayerScreen(pack: p, lesson: lessonWith(p, [whiteboardBlock()])));
      await t.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('chalkboard')), findsOneWidget);
      expect(stepText(t), 'Step 1 / 4');
      expect(find.text('Plot the quadratic'), findsOneWidget);
      expect(find.text('Vertex at x = 1'), findsNothing);

      final spoken = (s.narrator as TimedNarrator).spoken;
      await t.tap(find.byKey(const ValueKey('read')));
      await t.pump(const Duration(milliseconds: 100));
      expect(spoken.last, startsWith('Take y equals'));

      for (final n in [2, 3, 4]) {
        await t.tap(find.byKey(const ValueKey('wbNext')));
        await t.pump(const Duration(seconds: 3));
        expect(stepText(t), 'Step $n / 4');
      }
      expect(spoken, contains('The vertex is at x equals one.'));
      expect(find.text('Vertex at x = 1'), findsOneWidget);
      expect(t.widget<FilledButton>(find.descendant(of: find.byKey(const ValueKey('wbNext')), matching: find.byType(FilledButton))).onPressed, isNull, reason: 'no step after the last');
    });

    testWidgets('Self-Learning: steps advance by themselves after their line is read', (t) async {
      final s = await testServices();
      final p = s.store.byChapter(motion)!;
      await pumpBoard(t, s, home: SelfLearningScreen(pack: p, lesson: lessonWith(p, [whiteboardBlock()]), periodSeconds: 2400, autoTick: false));
      await t.pump();
      expect(find.byKey(const ValueKey('wbNext')), findsNothing);
      expect(stepText(t), 'Step 1 / 4');
      await t.pump(WhiteboardViewState.afterLine + const Duration(milliseconds: 200));
      expect(stepText(t), 'Step 2 / 4');
      // Pausing the period holds the board on its step.
      await t.tap(find.byKey(const ValueKey('slPause')));
      await t.pump(const Duration(seconds: 10));
      expect(stepText(t), 'Step 2 / 4');
      await t.tap(find.byKey(const ValueKey('slPause')));
      await t.pump(const Duration(seconds: 1));
      expect(stepText(t), 'Step 3 / 4');
      await t.pump(const Duration(seconds: 30)); // let the remaining steps finish
    });

    test('period estimate: each step is its reading time (at least 3 s) + 3 s', () {
      final b = whiteboardBlock();
      final expected = b.boardSteps.map((st) => max(PeriodPlanner.readingSeconds(st.say), 3) + 3).reduce((a, c) => a + c);
      expect(PeriodPlanner.estimate(b), expected);
      expect(PeriodPlanner.phaseOf(b), Phase.lesson);
    });
  });

  group('interactive', () {
    testWidgets('dragging a slider changes the live read-out', (t) async {
      final s = await testServices();
      await pumpBoard(t, s, home: Scaffold(body: Padding(padding: const EdgeInsets.all(40), child: InteractiveView(block: interactiveBlock('function_plot'), lang: Lang.en))));
      expect(readout(t, 0), '6.00'); // a*4 + b with a = 1, b = 2
      final slider = find.byKey(const ValueKey('slider-a'));
      expect(t.getSize(slider).height, greaterThanOrEqualTo(48));
      await t.drag(slider, const Offset(250, 0));
      await t.pump();
      final a = t.state<InteractiveViewState>(find.byType(InteractiveView)).values['a']!;
      expect(a, greaterThan(1));
      expect(readout(t, 0), (a * 4 + 2).toStringAsFixed(2));
    });

    testWidgets('every kind draws', (t) async {
      final s = await testServices();
      for (final kind in ['function_plot', 'vectors', 'bar_chart', 'pie_chart', 'unit_circle', 'number_line', 'readouts']) {
        await pumpBoard(t, s, home: Scaffold(body: InteractiveView(key: ValueKey(kind), block: interactiveBlock(kind), lang: Lang.en)));
        expect(t.takeException(), isNull, reason: kind);
      }
      expect(find.text('sin θ'), findsNothing); // the last one is "readouts"
    });
  });

  group('question formats', () {
    test('multi_correct needs exactly the correct set; numeric accepts within tolerance', () {
      final m = multiQuestion(), n = numericQuestion();
      expect(multiCorrect(m, {0, 2}), isTrue);
      expect(multiCorrect(m, {2, 0}), isTrue);
      expect(multiCorrect(m, {0}), isFalse);
      expect(multiCorrect(m, {0, 1, 2}), isFalse);
      expect(numericCorrect(n, 2.5), isTrue);
      expect(numericCorrect(n, 2.54), isTrue);
      expect(numericCorrect(n, 2.6), isFalse);
      expect(numericCorrect(n, null), isFalse);
      final exact = Question.fromJson({'id': 'q', 'stem': {'en': 's'}, 'options': [], 'answer': 0, 'numericAnswer': 4, 'exams': ['JEE'], 'difficulty': 'easy', 'format': 'numeric'});
      expect(numericCorrect(exact, 4), isTrue);
      expect(numericCorrect(exact, 4.01), isFalse);
      expect(parseTyped('−2.5'), -2.5);
    });

    Future<SessionRecorder> runQuiz(WidgetTester t, List<Question> qs) async {
      final s = await testServices();
      final rec = SessionRecorder.raw(outbox: s.outbox, sectionId: 's', mode: 'teacher', chapterId: 'c', topicId: 't', lessonId: 'l', packVersion: '1.0.0');
      await pumpBoard(t, s, home: Scaffold(body: Padding(padding: const EdgeInsets.all(40), child: QuizRunner(questions: qs, mode: QuizMode.monitor, lang: Lang.en, recorder: rec, room: ClassRoom(rollCount: 40)))));
      return rec;
    }

    testWidgets('multi_correct: tap several options, then Check', (t) async {
      final rec = await runQuiz(t, [multiQuestion(), multiQuestion()]);
      await t.tap(find.byKey(const ValueKey('option-2')));
      await t.pump();
      expect(find.text('Next question'), findsNothing, reason: 'a tap only selects');
      await t.tap(find.byKey(const ValueKey('option-0')));
      await t.tap(find.byKey(const ValueKey('option-1')));
      await t.tap(find.byKey(const ValueKey('option-1'))); // untick
      await t.pump();
      await t.tap(find.byKey(const ValueKey('check')));
      await t.pump();
      expect(find.text('Next question'), findsOneWidget);
      await t.tap(find.text('Next question'));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('option-0')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('check')));
      await t.pump();
      final answers = rec.log['answers'] as List;
      expect(answers[0], containsPair('correct', true));
      expect(answers[0], containsPair('chosen', 2)); // the first option tapped
      expect(answers[1], containsPair('correct', false));
    });

    testWidgets('numeric: type on the keypad, then Check', (t) async {
      final rec = await runQuiz(t, [numericQuestion(), numericQuestion()]);
      expect(find.byKey(const ValueKey('option-0')), findsNothing);
      for (final k in ['2', '.', '5', '9', '⌫']) {
        await t.tap(find.byKey(ValueKey('key-$k')));
      }
      await t.pump();
      expect(t.state<QuizRunnerState>(find.byType(QuizRunner)).typed, '2.5');
      await t.tap(find.byKey(const ValueKey('check')));
      await t.pump();
      expect(find.byKey(const ValueKey('numericAnswer')), findsOneWidget);
      await t.tap(find.text('Next question'));
      await t.pump();
      for (final k in ['−', '2', '.', '5']) {
        await t.tap(find.byKey(ValueKey('key-$k')));
      }
      await t.pump();
      await t.tap(find.byKey(const ValueKey('check')));
      await t.pump();
      final answers = rec.log['answers'] as List;
      expect(answers[0], allOf(containsPair('correct', true), containsPair('chosen', null)));
      expect(answers[1], containsPair('correct', false));
    });
  });

  group('exam practice', () {
    test('exams fit the section\'s subjects', () {
      expect(examsFor(['physics', 'chemistry', 'maths'], 'kar_pu'), ['KCET', 'COMEDK', 'JEE', 'JEE_ADV', 'PUC']);
      expect(examsFor(['physics', 'chemistry', 'biology'], 'kar_pu'), ['KCET', 'NEET', 'PUC']);
      expect(examsFor(['accountancy', 'economics'], 'cbse'), ['CBSE']);
      expect(examSubjectsFor('NEET', ['physics', 'chemistry', 'maths', 'biology']), ['physics', 'chemistry', 'biology']);
    });

    test('pools hold only questions tagged with the exam, in its subjects', () async {
      final s = await testServices();
      final neet = examPool(s, 'NEET'), jee = examPool(s, 'JEE');
      expect(neet, isNotEmpty);
      expect(neet.every((i) => i.q.exams.contains('NEET') && i.subject != 'maths'), isTrue);
      expect(jee.every((i) => i.q.exams.contains('JEE') && i.subject != 'biology'), isTrue);
      final mock = mockTest(neet, Random(1));
      expect(mock.length, 30);
      expect(mock.map((i) => i.subject).toSet(), containsAll(['physics', 'chemistry', 'biology']));
      final ch = chapterTest(neet, neet.first.pack.chapter.id, Random(1));
      expect(ch.length, lessThanOrEqualTo(10));
      expect(ch.every((i) => i.pack.chapter.id == neet.first.pack.chapter.id), isTrue);
    });

    testWidgets('chapter test: pick exam → chapter test → chapter; questions are tagged; results are logged', (t) async {
      final s = await testServices();
      await pumpBoard(t, s);
      await t.tap(find.byKey(const ValueKey('examPractice')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('exam:PUC')), findsOneWidget);
      expect(find.byKey(const ValueKey('exam:CBSE')), findsNothing);
      await t.tap(find.byKey(const ValueKey('exam:NEET')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('chapterTest')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('chapter:$motion')));
      await t.pump();
      final runner = t.widget<QuizRunner>(find.byType(QuizRunner));
      expect(runner.questions, hasLength(10));
      expect(runner.questions.every((q) => q.exams.contains('NEET')), isTrue);
      expect(find.byKey(const ValueKey('examClock')), findsOneWidget);
      await t.tap(find.byKey(ValueKey('option-${runner.questions.first.answer}')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('endTest')));
      await t.pump();
      expect((t.widget(find.byKey(const ValueKey('examScore'))) as Text).data, '1 / 10');
      final log = s.outbox.pending().single;
      expect(log['mode'], 'teacher');
      expect(log['chapterId'], motion);
      expect((log['answers'] as List).single['correct'], isTrue);
    });

    testWidgets('mock test: 30 questions, minutes per question set with +/-', (t) async {
      final s = await testServices();
      await pumpBoard(t, s, home: const ExamPracticeScreen());
      await t.tap(find.byKey(const ValueKey('exam:JEE')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('plus')));
      await t.pump();
      expect((t.widget(find.byKey(const ValueKey('minutes'))) as Text).data, '2');
      await t.tap(find.byKey(const ValueKey('mockTest')));
      await t.pump();
      expect(t.widget<QuizRunner>(find.byType(QuizRunner)).questions, hasLength(30));
      expect(find.text('60:00'), findsOneWidget);
      await t.pump(const Duration(seconds: 60));
      expect(find.text('59:00'), findsOneWidget);
    });
  });

  group('smartboard', () {
    testWidgets('opens on the simple board; Insert, pages and Close work', (t) async {
      final s = await testServices();
      await pumpBoard(
        t,
        s,
        home: Scaffold(body: Builder(builder: (ctx) => TextButton(key: const ValueKey('teacherMode'), onPressed: () => openSmartboard(ctx), child: const Text('open')))),
      );
      await t.tap(find.byKey(const ValueKey('teacherMode')));
      await settle(t);
      expect(find.byType(SmartboardScreen), findsOneWidget);
      final st = t.state<SmartboardScreenState>(find.byType(SmartboardScreen));
      final board = st.board;
      expect(find.byKey(const ValueKey('tool-pen')), findsOneWidget, reason: 'simple mode is the default');
      await t.tap(find.byKey(const ValueKey('insert')));
      await settle(t);
      expect(find.byKey(const ValueKey('insert-picture')), findsOneWidget);
      expect(find.byKey(const ValueKey('openKinetix')), findsNothing);
      await t.tap(find.byKey(const ValueKey('closeInsert')));
      await settle(t);
      final before = board.elements.length;
      st.insertMath(r'v = u + at');
      await t.pump();
      expect(board.elements.length, before + 1);
      // A second page.
      await t.tap(find.byKey(const ValueKey('newPage')));
      await t.pump();
      expect(board.pageCount, greaterThanOrEqualTo(2));
      await t.tap(find.byKey(const ValueKey('closeSmartboard')));
      await settle(t);
      expect(find.byType(SmartboardScreen), findsNothing);
      expect(find.byKey(const ValueKey('teacherMode')), findsOneWidget);
    });

    testWidgets('the Kinetix board app button shows in Insert when the app is installed', (t) async {
      final calls = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('zynetix/apps'), (c) async {
        calls.add(c);
        return true;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('zynetix/apps'), null));
      final s = await testServices();
      await pumpBoard(t, s, home: const SmartboardScreen());
      await settle(t);
      await t.tap(find.byKey(const ValueKey('insert')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('openKinetix')));
      await t.pump();
      expect(calls.map((c) => c.method), ['isInstalled', 'launch']);
      expect(calls.last.arguments, {'package': 'in.kinetix.board'});
    });

    testWidgets('opens from the lesson player, pausing it; closing returns to the same block', (t) async {
      final s = await testServices();
      final p = s.store.byChapter(motion)!;
      await pumpBoard(t, s, home: LessonPlayerScreen(pack: p, lesson: p.lessons['$motion.t1']!));
      await t.tap(find.byKey(const ValueKey('next')));
      await t.pump();
      expect(find.text('Step 2 of ${p.lessons['$motion.t1']!.blocks.length}'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('smartboard')));
      await settle(t);
      expect(find.byType(SmartboardScreen), findsOneWidget);
      expect(find.text('Resume', skipOffstage: false), findsOneWidget, reason: 'the lesson is paused underneath');
      await t.tap(find.byKey(const ValueKey('closeSmartboard')));
      await settle(t);
      expect(find.text('Step 2 of ${p.lessons['$motion.t1']!.blocks.length}'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('is not offered inside a running Self-Learning period', (t) async {
      final s = await testServices();
      final p = s.store.byChapter(motion)!;
      await pumpBoard(t, s, home: SelfLearningScreen(pack: p, lesson: p.lessons.values.first, periodSeconds: 2400, autoTick: false));
      await t.pump();
      expect(find.byKey(const ValueKey('smartboard')), findsNothing);
      await t.pump(const Duration(seconds: 1)); // the silent narrator's timer
    });
  });

  test('fixtures parse as the board reads packs', () {
    expect(whiteboardBlock().boardSteps, hasLength(4));
    expect(Directory('assets/packs').existsSync(), isTrue);
  });
}
