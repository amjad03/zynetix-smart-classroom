// The whole app, end to end, as a new teacher meets it: first open → who is teaching → Home →
// Start my class → lesson → Smartboard on the step → back → quiz by roll numbers → Finish class;
// then Show all tools, Kannada, and the same day on a phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/features/app/home.dart';
import 'package:zynetix_board/features/app/lesson.dart';
import 'package:zynetix_board/features/app/quiz.dart';
import 'package:zynetix_board/features/app/school.dart';
import 'package:zynetix_board/features/app/shell.dart';
import 'package:zynetix_board/features/app/start.dart';
import 'package:zynetix_board/features/smartboard.dart';
import 'package:zynetix_board/main.dart';
import 'package:zynetix_board/whiteboard/board_store.dart';
import 'package:zynetix_board/whiteboard/recording.dart';

import 'helpers.dart';

const grav = 'puc1-physics-07-gravitation';
const board = Size(1920, 1080), phone = Size(390, 844);

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  await t.pump();
  await t.pump(Duration(milliseconds: ms));
}

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  if (f.evaluate().isEmpty && find.byType(Scrollable).evaluate().isNotEmpty) await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  expect(f, findsWidgets, reason: 'no "$key" on screen');
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first);
  await settle(t);
}

/// Runs the first day from a fresh board at [size]; [kannada] picks Kannada on first open.
Future<void> firstDay(WidgetTester t, {Size size = board, bool kannada = false}) async {
  final s = await testServices(prefs: {'displaySize': size == board ? 'classroom' : 'normal', 'rollCount': 40, 'taught': ['$grav.t1', '$grav.t2'], 'subjects': ['physics']}, now: DateTime(2026, 11, 4, 10, 5));
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ZynetixBoardApp(services: s));
  await settle(t);

  // 1 · First open: the language, then Continue.
  expect(find.byType(FirstOpenScreen), findsOneWidget);
  if (kannada) await tap(t, 'lang-kn');
  await tap(t, 'continue');
  expect(s.config.lang.name, kannada ? 'kn' : 'en');

  // 2 · Who is teaching: add yourself, no PIN.
  expect(find.byType(WhoTodayScreen), findsOneWidget);
  await tap(t, 'addTeacher');
  await t.enterText(find.byKey(const ValueKey('teacherName')), 'K. Meera');
  await tap(t, 'teacherAdd');
  expect(find.byType(HomeScreen), findsOneWidget);
  final me = s.school.current!;
  expect(me.firstName, 'Meera');
  // The office puts her Physics period in the timetable (Settings does this on the board).
  s.school.setPeriods([Period(id: 'p', start: '09:45', end: '10:40', subject: 'physics', days: const [3], teacherId: me.id)]);
  await settle(t);

  // 3 · The voice guide, the first time only.
  expect(find.byKey(const ValueKey('tourCard')), findsOneWidget);
  await tap(t, 'tourSkip');
  expect(find.byKey(const ValueKey('tourCard')), findsNothing);
  expect(s.school.tourDone, isTrue);
  await t.scrollUntilVisible(find.byKey(const ValueKey('showAll')), 300, scrollable: find.byType(Scrollable).first);
  expect(find.text(kannada ? 'ಎಲ್ಲಾ ಸಾಧನಗಳನ್ನು ತೋರಿಸಿ' : 'Show all tools'), findsOneWidget);
  await t.scrollUntilVisible(find.byKey(const ValueKey('startClass')), -300, scrollable: find.byType(Scrollable).first);

  // 4 · Start my class: the lesson after the ones taught, from the first step.
  await tap(t, 'startClass');
  expect(find.byType(SimpleLessonScreen), findsOneWidget);
  await tap(t, 'next');
  await tap(t, 'next');
  expect(s.school.stepFor('$grav.t3'), greaterThan(0));
  final step = s.school.stepFor('$grav.t3');

  // 5 · The Smartboard on this step (a page of its own); write, then back to the lesson.
  BoardStore.instance = BoardStore();
  RecordingStore.instance = RecordingStore();
  await tap(t, 'lessonBoard');
  expect(find.byType(SmartboardScreen), findsOneWidget);
  final sb = t.state<SmartboardScreenState>(find.byType(SmartboardScreen));
  expect(sb.stepAt, step);
  expect(find.text(kannada ? 'ಪಾಠಕ್ಕೆ ಹಿಂತಿರುಗಿ' : 'Back to the lesson'), findsOneWidget);
  await tap(t, 'closeSmartboard');
  expect(find.byType(SimpleLessonScreen), findsOneWidget);
  expect(find.byType(SmartboardScreen), findsNothing);

  // 6 · Home, then "Quiz the class": tap the roll numbers who are right; Done saves them.
  await tap(t, 'closeLesson');
  expect(find.byType(HomeScreen), findsOneWidget);
  await tap(t, 'cardQuiz');
  expect(find.byType(SimpleQuizScreen), findsOneWidget);
  for (final r in const [1, 2, 5, 9]) {
    await tap(t, 'roll-$r');
  }
  await tap(t, 'showAnswer');
  await tap(t, 'quizDone');
  expect(s.school.quizzes, isNotEmpty);
  expect(s.school.quizzes.first.right, [1, 2, 5, 9]);
  while (find.byType(SimpleQuizScreen).evaluate().isNotEmpty) {
    await tap(t, 'quizBack');
  }
  expect(find.byType(HomeScreen), findsOneWidget);

  // 7 · Start my class again: it opens where it was left; Finish class saves the class.
  await tap(t, 'startClass');
  expect(find.byType(SimpleLessonScreen), findsOneWidget);
  await tap(t, 'finishClass');
  expect(find.byType(FinishClassScreen), findsOneWidget);
  final rec = s.school.history.single;
  expect(rec.topicId, '$grav.t3');
  expect(rec.teacherId, me.id);
  expect(rec.stepsSeen, step + 1);
  await tap(t, 'changeAttendance');
  await tap(t, 'absent-7');
  await tap(t, 'attendanceSave');
  expect(s.school.history.single.absent, [7]);
  await tap(t, 'finishDone');
  expect(find.byType(HomeScreen), findsOneWidget);

  // 8 · Show all tools: every place opens, with the class's record in Reports.
  await tap(t, 'showAll');
  expect(s.school.showAll, isTrue);
  for (final sec in Section.values.where((x) => x != Section.board)) {
    await tap(t, 'all-${sec.name}');
    expect(find.byKey(ValueKey('section-${sec.name}')), findsOneWidget, reason: sec.name);
    if (sec == Section.reports) expect(find.byKey(ValueKey('history-${rec.id}')), findsOneWidget);
    await tap(t, 'rail-home');
  }
  expect(find.byType(HomeScreen), findsOneWidget);
  await tap(t, 'all-board');
  expect(find.byType(SmartboardScreen), findsOneWidget);
  await tap(t, 'closeSmartboard');
  expect(find.byType(HomeScreen), findsOneWidget);
}

void main() {
  setUp(() {
    BoardStore.instance = BoardStore();
    RecordingStore.instance = RecordingStore();
  });

  testWidgets('the first day on the board, end to end', (t) => firstDay(t));
  testWidgets('the first day in Kannada', (t) => firstDay(t, kannada: true));
  testWidgets('the first day on a phone', (t) => firstDay(t, size: phone));
  testWidgets('the first day on a phone in Kannada', (t) => firstDay(t, size: phone, kannada: true));
}
