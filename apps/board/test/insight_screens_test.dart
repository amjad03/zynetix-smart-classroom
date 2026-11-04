import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/core/strings.dart';
import 'package:zynetix_board/engine/mastery.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/insight/analysis.dart';
import 'package:zynetix_board/features/insight/mastery_map.dart';
import 'package:zynetix_board/features/insight/readiness.dart';
import 'package:zynetix_board/features/insight/reteach.dart';
import 'package:zynetix_board/features/insight/today_plan.dart';
import 'package:zynetix_board/features/insight/worksheet.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/features/self_learning.dart';
import 'package:zynetix_board/main.dart';

import 'fixtures.dart';
import 'helpers.dart';

const motion = 'puc1-physics-02-motion-in-a-straight-line';
final day = DateTime(2026, 11, 4, 9);

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

/// A class with history: rolls 1–10 answered on the motion chapter, some stuck, some strong.
void seed(MasteryStore m) {
  final rs = <Response>[];
  for (var roll = 1; roll <= 10; roll++) {
    for (var t = 1; t <= 4; t++) {
      for (var k = 0; k < 3; k++) {
        final ok = (roll + t + k) % (roll <= 3 ? 4 : 2) != 0 && !(roll <= 3 && t == 1);
        rs.add(Response(roll: roll, questionId: 'q$k', topicId: '$motion.t$t', chapterId: motion, correct: ok, source: 'roll_call', at: day.subtract(Duration(days: 7 * k))));
      }
    }
  }
  m.recordAll(rs);
}

({InstalledPack pack, Lesson lesson, Block quiz, Block sim}) quizLesson(Services s, {int? seconds}) {
  final p = s.store.byChapter(motion)!;
  final t1 = p.lessons['$motion.t1']!;
  final quiz = t1.blocks.firstWhere((b) => b.type == BlockType.classQuiz);
  final sim = t1.blocks.firstWhere((b) => b.type == BlockType.simulation);
  final q = seconds == null ? quiz : Block(BlockType.classQuiz, {...quiz.raw, 'mode': 'monitor', 'secondsPerQuestion': seconds});
  return (pack: p, lesson: lessonWith(p, [q, sim]), quiz: q, sim: sim);
}

Future<void> answerAll(WidgetTester t, int n, {required bool right, required List<int> answers}) async {
  for (var i = 0; i < n; i++) {
    final pick = right ? answers[i] : (answers[i] + 1) % 4;
    await t.tap(find.byKey(ValueKey('option-$pick')));
    await t.pump();
    await t.tap(find.text(tr('nextQuestion', Lang.en)));
    await settle(t);
  }
}

void main() {
  group('re-teach', () {
    testWidgets('Teacher Mode: under 60% shows the card; Re-teach plays another approach and returns', (t) async {
      final s = await testServices();
      final q = quizLesson(s);
      await pumpBoard(t, s, home: LessonPlayerScreen(pack: q.pack, lesson: q.lesson));
      final ids = q.quiz.ids('questionIds');
      final answers = [for (final id in ids) q.pack.questions[id]!.answer];
      await answerAll(t, ids.length, right: false, answers: answers);
      expect(find.byType(ReteachCard), findsOneWidget);
      expect(find.text('0 / ${ids.length} right'), findsOneWidget);
      expect(find.text(q.pack.questions[ids.first]!.stem.en), findsWidgets, reason: 'the missed questions are listed');
      await t.tap(find.byKey(const ValueKey('pairUp')));
      await t.pump();
      expect(find.text('No roll numbers to pair yet: use Roll call in quizzes'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('reteach')));
      await settle(t);
      expect(find.byType(ReplayScreen), findsOneWidget);
      expect(find.byKey(ValueKey('block:${q.sim.id}')), findsOneWidget, reason: 'the simulation was not shown yet');
      await t.tap(find.byKey(const ValueKey('replayDone')));
      await settle(t);
      expect(find.byType(ReplayScreen), findsNothing);
      expect(find.byType(LessonPlayerScreen), findsOneWidget);
    });

    testWidgets('Teacher Mode: a good score keeps the usual flow', (t) async {
      final s = await testServices();
      final q = quizLesson(s);
      await pumpBoard(t, s, home: LessonPlayerScreen(pack: q.pack, lesson: q.lesson));
      final ids = q.quiz.ids('questionIds');
      await answerAll(t, ids.length, right: true, answers: [for (final id in ids) q.pack.questions[id]!.answer]);
      expect(find.byType(ReteachCard), findsNothing);
      expect(find.text(tr('done', Lang.en)), findsOneWidget);
    });

    testWidgets('Self-Learning: re-teaches once by itself, then the period carries on', (t) async {
      final s = await testServices();
      final q = quizLesson(s, seconds: 2);
      await pumpBoard(t, s, home: SelfLearningScreen(pack: q.pack, lesson: q.lesson, periodSeconds: 2400, autoTick: false));
      await settle(t);
      final st = t.state<SelfLearningScreenState>(find.byType(SelfLearningScreen));
      final runner = st.runner;
      // Through the simulation to the quiz.
      for (var i = 0; i < 400 && runner.current.block.type != BlockType.classQuiz; i++) {
        runner.tick();
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(runner.current.block.type, BlockType.classQuiz);
      // Nobody answers: each question times out wrong.
      for (var i = 0; i < 60 && find.byType(ReplayScreen).evaluate().isEmpty; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(find.byType(ReplayScreen), findsOneWidget);
      expect(find.byType(ReteachCard), findsOneWidget, reason: 'it first says what was missed');
      expect(runner.quizDone, isFalse, reason: 'the quiz step waits for the re-teach');
      for (var i = 0; i < 300 && find.byType(ReplayScreen).evaluate().isNotEmpty; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(find.byType(ReplayScreen), findsNothing);
      expect(runner.quizDone, isTrue);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    });
  });

  group('mastery map', () {
    testWidgets('filters, topic detail with Teach this now, and a roll report', (t) async {
      final s = await testServices();
      seed(s.mastery);
      await pumpBoard(t, s, home: const MasteryMapScreen());
      expect(find.byType(HeatGrid), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('onlyData')));
      await t.pump();
      expect(find.byKey(const ValueKey('row:$motion.t1')), findsOneWidget);
      expect(find.byKey(const ValueKey('row:$motion.t5')), findsNothing, reason: 'no answers on t5');
      await t.tap(find.byKey(const ValueKey('onlyWeak')));
      await t.pump();
      expect(find.byKey(const ValueKey('row:$motion.t1')), findsOneWidget, reason: 'rolls 1–3 are stuck on t1');

      await t.tap(find.byKey(const ValueKey('topic:$motion.t1')));
      await settle(t);
      expect(find.byType(TopicInsightScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('roll:1')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('teachNow')));
      await settle(t);
      expect(find.byType(LessonPlayerScreen), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('close')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('roll:1')));
      await settle(t);
      expect(find.byType(RollReportScreen), findsOneWidget);
      expect(find.byType(TrendBars), findsOneWidget);
      expect(find.text('Estimate', findRichText: true), findsNothing); // bands, never a rank
      expect(find.textContaining('not a rank prediction'), findsOneWidget);
    });

    testWidgets('a roll number header opens that roll\'s report', (t) async {
      final s = await testServices();
      seed(s.mastery);
      await pumpBoard(t, s, home: const MasteryMapScreen());
      final header = t.getRect(find.byKey(const ValueKey('rollHeader')));
      await t.tapAt(header.centerLeft + const Offset(10, 0));
      await settle(t);
      expect(find.text('Roll 1'), findsOneWidget);
    });

    test('scales to 60 rolls × every topic without building them all', () async {
      final s = await testServices();
      expect(sectionTopics(s).length, greaterThan(300));
      expect(sectionRolls(s), hasLength(60));
    });
  });

  testWidgets('today plan card starts the revision, then the next topic', (t) async {
    final s = await testServices(prefs: {'taught': ['$motion.t1', '$motion.t2']}, now: day);
    s.mastery.recordAll([for (var i = 0; i < 3; i++) Response(questionId: 'q', topicId: '$motion.t1', chapterId: motion, correct: false, source: 'monitor', at: day)]);
    await pumpBoard(t, s, home: const Scaffold(body: Center(child: TodayPlanCard())));
    expect(find.textContaining('5 min revise'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('startPlan')));
    await settle(t);
    expect(find.byType(ReplayScreen), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('replayDone')));
    await settle(t);
    expect(find.byType(LessonPlayerScreen), findsOneWidget);
    expect(find.text(s.lessonFor('$motion.t3')!.lesson.title.en), findsWidgets);
  });

  testWidgets('worksheet screen offers the class and stuck rolls', (t) async {
    final s = await testServices();
    seed(s.mastery);
    await pumpBoard(t, s, home: const WorksheetScreen());
    expect(find.byKey(const ValueKey('sheetClass')), findsOneWidget);
    expect(find.byKey(const ValueKey('sheetRoll:1')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sheetRoll:1')));
    await t.pump();
    expect(find.text('Practice sheet · Roll 1'), findsOneWidget);
  });

  // The screens at phone (both ways) and board size: no overflow, nothing thrown.
  const devices = <String, (Size, String)>{
    'phone portrait': (Size(390, 844), 'normal'),
    'phone landscape': (Size(844, 390), 'normal'),
    'board classroom': (Size(1920, 1080), 'classroom'),
  };
  for (final d in devices.entries) {
    testWidgets('insight screens fit: ${d.key}', (t) async {
      final (size, display) = d.value;
      final problems = <String>[];
      var where = '';
      final old = FlutterError.onError;
      FlutterError.onError = (e) => problems.add('$where: ${e.exceptionAsString().split('\n').first}');
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = await testServices(prefs: {'displaySize': display, 'taught': ['$motion.t1', '$motion.t2']}, now: day);
      seed(s.mastery);
      final q = quizLesson(s);
      final o = QuizOutcome.from([
        for (final id in q.quiz.ids('questionIds')) {'questionId': id, 'correct': false, 'roll': 1},
      ], q.quiz.ids('questionIds'));

      Future<void> show(String name, Widget home) async {
        where = name;
        await t.pumpWidget(ZynetixBoardApp(key: UniqueKey(), services: s, home: home));
        await t.pump(const Duration(milliseconds: 500));
      }

      await show('mastery map', const MasteryMapScreen());
      await show('roll report', const RollReportScreen(roll: 1));
      await show('roll report, no answers', const RollReportScreen(roll: 42));
      await show('topic', const TopicInsightScreen(topicId: '$motion.t1'));
      await show('exam readiness', const ExamReadinessScreen());
      await show('worksheet', const WorksheetScreen());
      await show('practice sheet', const WorksheetScreen(roll: 2));
      await show('today plan', const Scaffold(body: Center(child: TodayPlanCard())));
      await show(
        're-teach card',
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: ReteachCard(outcome: o, missed: q.pack.questionsFor(o.missed), pairs: const [(1, 4), (2, 5), (3, 6)], lang: Lang.en, onReteach: () {}, onCarryOn: () {}),
          ),
        ),
      );
      await show('replay', ReplayScreen(pack: q.pack, lesson: q.lesson, blocks: [q.sim, q.quiz]));
      await t.pumpWidget(const SizedBox());
      FlutterError.onError = old;
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}
