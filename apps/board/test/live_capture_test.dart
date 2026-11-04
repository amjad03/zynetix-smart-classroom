// Capturing every student's answer without a camera: the hands-up grid in QuizRunner, the phone
// quiz screen and paper test marks, plus their layouts at phone and board sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/mastery.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/features/live/hands_up.dart';
import 'package:zynetix_board/features/live/live_quiz_screen.dart';
import 'package:zynetix_board/features/live/live_server.dart';
import 'package:zynetix_board/features/live/paper_marks.dart';
import 'package:zynetix_board/features/participation.dart';
import 'package:zynetix_board/main.dart';

import 'helpers.dart';
import 'live_server_test.dart' show mcq, numeric;

List<Response> bySource(Services s, String source) => [
  for (final r in s.mastery.responses)
    if (r.source == source) r,
];

void main() {
  group('hands-up logic', () {
    test('per roll: tapped rolls flip the baseline; absent and skipped rolls are left out', () {
      final m = handsPerRoll(rollCount: 6, absent: {2}, tapped: {3, 5}, skip: {6});
      expect(m, {1: true, 3: false, 4: true, 5: false});
      final inverted = handsPerRoll(rollCount: 4, absent: {}, tapped: {1}, baseline: false);
      expect(inverted, {1: true, 2: false, 3: false, 4: false});
    });

    test('per option: one answer per hand, right and wrong interleaved', () {
      final list = handsPerOption([2, 5, 1, 0], {1});
      expect(list, hasLength(8));
      expect(list.where((e) => e.$2).length, 5);
      expect(list.where((e) => e.$2).every((e) => e.$1 == 1), isTrue);
      // The class estimate (a fast moving average) ends near the share right (5/8), not at 0 or 1.
      final store = MasteryStore();
      store.recordAll([for (final (_, ok) in list) Response(questionId: 'q', topicId: 't', chapterId: 'c', correct: ok, source: 'hands', at: DateTime(2026))]);
      expect(store.classTopic('t')!.p, closeTo(5 / 8, 0.2));
    });
  });

  group('hands-up in QuizRunner', () {
    Future<(Services, ClassRoom)> pumpRunner(WidgetTester t, QuizMode mode, {List<Question>? qs}) async {
      final s = await testServices();
      final rec = SessionRecorder.raw(outbox: s.outbox, sectionId: 's', mode: 'teacher', chapterId: 'c1', topicId: 't1', lessonId: 'l', packVersion: '1.0.0', mastery: s.mastery);
      final room = ClassRoom(rollCount: 60);
      await pumpBoard(t, s, home: Scaffold(body: Padding(padding: const EdgeInsets.all(40), child: QuizRunner(questions: qs ?? [mcq()], mode: mode, lang: Lang.en, recorder: rec, room: room))));
      return (s, room);
    }

    testWidgets('after the reveal, tap who got it wrong; everyone else is right', (t) async {
      final (s, room) = await pumpRunner(t, QuizMode.monitor);
      expect(find.byKey(const ValueKey('hands')), findsNothing, reason: 'only after the reveal');
      await t.tap(find.byKey(const ValueKey('option-1')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('hands')));
      await t.pumpAndSettle();
      // All 60 rolls are on screen at once.
      for (final r in [1, 30, 60]) {
        expect(find.byKey(ValueKey('roll-$r')).hitTestable(), findsOneWidget);
      }
      await t.tap(find.byKey(const ValueKey('roll-3')));
      await t.tap(find.byKey(const ValueKey('roll-7')));
      await t.tap(find.byKey(const ValueKey('tapAbsent')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('roll-60')));
      await t.pump();
      expect(find.text('57 right · 2 wrong · 1 absent'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('handsSave')));
      await t.pumpAndSettle();

      final hands = bySource(s, 'hands');
      expect(hands, hasLength(59));
      expect({for (final r in hands.where((r) => !r.correct)) r.roll}, {3, 7});
      expect(hands.every((r) => r.topicId == 't1' && r.chapterId == 'c1'), isTrue);
      expect(room.absent, {60});
      expect(find.byKey(const ValueKey('handsDone')), findsOneWidget);
      expect(find.byKey(const ValueKey('hands')), findsNothing, reason: 'one count per question');
      // The class answer the monitor tapped is still there.
      expect(bySource(s, 'monitor'), hasLength(1));
    });

    testWidgets('tap = right flips the default; per-option count records one answer per hand', (t) async {
      final (s, _) = await pumpRunner(t, QuizMode.monitor, qs: [mcq('a'), mcq('b')]);
      await t.tap(find.byKey(const ValueKey('option-1')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('hands')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('tapRight')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('roll-1')));
      await t.tap(find.byKey(const ValueKey('roll-2')));
      await t.pump();
      expect(find.text('2 right · 58 wrong · 0 absent'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('handsSave')));
      await t.pumpAndSettle();
      expect(bySource(s, 'hands').where((r) => r.correct).map((r) => r.roll), [1, 2]);

      await t.tap(find.text('Next question'));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('option-0')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('hands')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('handsByOption')));
      await t.pump();
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byKey(const ValueKey('count-1-1')));
      }
      await t.tap(find.byKey(const ValueKey('count-0-5')));
      await t.pump();
      expect(find.text('8 / 60'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('handsSave')));
      await t.pumpAndSettle();
      final b = bySource(s, 'hands').where((r) => r.questionId == 'b').toList();
      expect(b, hasLength(8));
      expect(b.where((r) => r.correct), hasLength(3));
      expect(b.every((r) => r.roll == null), isTrue);
    });

    testWidgets('roll call: the student who answered aloud is not counted twice', (t) async {
      final (s, _) = await pumpRunner(t, QuizMode.rollCall);
      await t.tap(find.text('Pick a roll number'));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('option-1')));
      await t.pump();
      final called = bySource(s, 'roll_call').single.roll!;
      await t.tap(find.byKey(const ValueKey('hands')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('handsSave')));
      await t.pumpAndSettle();
      final hands = bySource(s, 'hands');
      expect(hands, hasLength(59));
      expect(hands.any((r) => r.roll == called), isFalse);
    });

    testWidgets('cancel records nothing', (t) async {
      final (s, _) = await pumpRunner(t, QuizMode.team);
      await t.tap(find.byKey(const ValueKey('option-2')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('hands')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('handsCancel')));
      await t.pumpAndSettle();
      expect(bySource(s, 'hands'), isEmpty);
      expect(find.byKey(const ValueKey('hands')), findsOneWidget);
    });

    testWidgets('no hands-up in Self-Learning (auto)', (t) async {
      final s = await testServices();
      final rec = SessionRecorder.raw(outbox: s.outbox, sectionId: 's', mode: 'self_learning', chapterId: 'c1', topicId: 't1', lessonId: 'l', packVersion: '1.0.0');
      await pumpBoard(t, s, home: Scaffold(body: QuizRunner(questions: [mcq()], mode: QuizMode.monitor, lang: Lang.en, recorder: rec, room: ClassRoom(rollCount: 60), auto: true)));
      await t.tap(find.byKey(const ValueKey('option-1')));
      await t.pump();
      expect(find.byKey(const ValueKey('hands')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('phone quiz screen', () {
    testWidgets('live count and histogram, then reveal records each roll (source phone)', (t) async {
      final s = await testServices();
      final server = LiveServer(rollCount: 60, roomCode: '2468');
      await pumpBoard(t, s, home: LiveQuizScreen(questions: [mcq(), numeric()], server: server, listen: false));
      await t.pump();
      expect(find.text('2468'), findsOneWidget);
      expect(find.byKey(const ValueKey('qr')), findsOneWidget);
      expect(server.phase, LivePhase.open);
      server.submit(5, const LiveAnswer(choice: 1));
      server.submit(6, const LiveAnswer(choice: 0));
      server.submit(7, const LiveAnswer(choice: 1));
      await t.pump();
      expect(find.text('3 / 60 answered'), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const ValueKey('bar-1'))).data, '2');
      await t.tap(find.byKey(const ValueKey('liveReveal')));
      await t.pump();
      expect(find.text('Correct: 2 / 3'), findsOneWidget);
      final phone = bySource(s, 'phone');
      expect({for (final r in phone) r.roll: r.correct}, {5: true, 6: false, 7: true});
      expect(server.submit(8, const LiveAnswer(choice: 1)), isFalse, reason: 'closed after the reveal');

      await t.tap(find.byKey(const ValueKey('liveNext')));
      await t.pump();
      expect(server.answers, isEmpty);
      server.submit(5, const LiveAnswer(value: 9.8));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('liveReveal')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('liveNext')));
      await t.pump();
      expect(find.byKey(const ValueKey('liveScore')), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(bySource(s, 'phone'), hasLength(4));
      await t.tap(find.byKey(const ValueKey('liveDone')));
      await t.pumpAndSettle();
      expect(s.outbox.pending().single['answers'], hasLength(4));
    });
  });

  group('paper marks', () {
    test('cells cycle blank, right, wrong; all right fills (and clears) a row', () {
      final m = PaperMarks(rollCount: 5, questionCount: 3);
      m.cycle(2, 0);
      expect(m.at(2, 0), true);
      m.cycle(2, 0);
      expect(m.at(2, 0), false);
      m.cycle(2, 0);
      expect(m.at(2, 0), isNull);
      m.allRight(4);
      expect(m.row(4), [true, true, true]);
      expect(m.entered, [4]);
      m.allRight(4);
      expect(m.entered, isEmpty);
    });

    testWidgets('enter marks and save them into mastery (source paper)', (t) async {
      final s = await testServices();
      final pack = s.store.packs.firstWhere((p) => p.questions.length >= 3);
      final qs = pack.questions.values.take(3).toList();
      await pumpBoard(t, s, home: PaperMarksScreen(pack: pack, questions: qs));
      await t.tap(find.byKey(const ValueKey('cell-1-0')));
      await t.tap(find.byKey(const ValueKey('cell-1-1')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('cell-1-1')));
      await t.tap(find.byKey(const ValueKey('allRight-2')));
      await t.pump();
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      expect(find.text('2 / 60 rolls entered'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('saveMarks')));
      await t.pump();
      final paper = bySource(s, 'paper');
      expect(paper, hasLength(5));
      expect(paper.where((r) => r.roll == 1).map((r) => r.correct), [true, false]);
      expect(paper.every((r) => r.chapterId == pack.chapter.id), isTrue);
      final log = s.outbox.pending().single;
      expect(log['mode'], 'teacher');
      expect(log['present'], 2);
      expect(log['completed'], true);
      // Saved: the grid is read-only now, so nothing is recorded twice.
      await t.tap(find.byKey(const ValueKey('cell-3-0')));
      await t.pump();
      expect(find.text('2 / 60 rolls entered'), findsOneWidget);
    });

    testWidgets('pick a chapter test from the installed packs', (t) async {
      final s = await testServices();
      await pumpBoard(t, s, home: const PaperMarksScreen());
      await t.tap(find.byKey(const ValueKey('countMinus')));
      await t.pump();
      await t.tap(find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('chapter:')).first);
      await t.pump();
      expect(find.byKey(const ValueKey('cell-1-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('cell-1-5')), findsNothing);
    });
  });

  // Phone upright and sideways (normal size) and the 75" board (classroom size): no overflow.
  const devices = <String, (Size, String)>{
    'phone portrait': (Size(390, 844), 'normal'),
    'phone landscape': (Size(844, 390), 'normal'),
    'board classroom': (Size(1920, 1080), 'classroom'),
  };
  for (final d in devices.entries) {
    testWidgets('capture screens fit: ${d.key}', (t) async {
      final (size, display) = d.value;
      final problems = <String>[];
      var where = '';
      final old = FlutterError.onError;
      FlutterError.onError = (e) => problems.add('$where: ${e.exceptionAsString().split('\n').first}');
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = await testServices(prefs: {'displaySize': display});
      final pack = s.store.packs.firstWhere((p) => p.questions.length >= 10);
      final qs = pack.questions.values.take(10).toList();

      Future<void> show(String name, Widget home) async {
        where = name;
        await t.pumpWidget(ZynetixBoardApp(key: UniqueKey(), services: s, home: home));
        await t.pump(const Duration(milliseconds: 300));
      }

      await show('hands grid', HandsUpScreen(question: mcq(), rollCount: 60, absent: {}, lang: Lang.en));
      expect(find.byKey(const ValueKey('roll-60')).hitTestable(), findsOneWidget, reason: '60 rolls fit without scrolling (${d.key})');
      await t.tap(find.byKey(const ValueKey('handsByOption')));
      await t.pump();
      where = 'hands per option';
      await t.pump();
      await show('phone quiz picker', const LiveQuizScreen(listen: false));
      final server = LiveServer(rollCount: 60, roomCode: '1357');
      await show('phone quiz', LiveQuizScreen(questions: qs, pack: pack, server: server, listen: false));
      await t.pump();
      server.submit(1, const LiveAnswer(choice: 0));
      await t.pump();
      await show('phone quiz numeric', LiveQuizScreen(questions: [numeric()], server: LiveServer(rollCount: 60), listen: false));
      await t.pump();
      await show('paper picker', const PaperMarksScreen());
      await show('paper grid', PaperMarksScreen(pack: pack, questions: qs));
      await t.pumpWidget(const SizedBox());
      FlutterError.onError = old;
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}
