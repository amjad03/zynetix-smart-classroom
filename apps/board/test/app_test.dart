import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/features/app/class_content.dart';
import 'package:zynetix_board/features/app/home.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/app/lesson.dart';
import 'package:zynetix_board/features/app/now.dart';
import 'package:zynetix_board/features/app/practice.dart';
import 'package:zynetix_board/features/app/quiz.dart';
import 'package:zynetix_board/features/app/school.dart';
import 'package:zynetix_board/features/app/shell.dart';
import 'package:zynetix_board/features/app/start.dart';

import 'helpers.dart';

const grav = 'puc1-physics-07-gravitation';

Future<void> tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(ValueKey(key)));
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  test('school records survive a restart, and undo reverts', () {
    final dir = Directory.systemTemp.createTempSync('school');
    final f = File('${dir.path}/school.json');
    final now = DateTime(2026, 11, 4, 10, 5);
    final a = SchoolStore(file: f, now: () => now);
    final t = a.addTeacher('K. Meera');
    expect(t.initials, 'KM');
    a.signIn(t.id);
    a.setPeriods([const Period(id: 'p', start: '09:45', end: '10:40', subject: 'physics')]);
    a.setStep('$grav.t3', 4);
    a.addQuiz(QuizResult(id: 'q', at: now, questionId: 'x', topicId: '$grav.t3', chapterId: grav, right: const [1, 2], wrong: const [3]));
    final b = SchoolStore(file: f, now: () => now);
    expect(b.current?.name, 'K. Meera');
    expect(b.classNow()?.subject, 'physics');
    expect(b.stepFor('$grav.t3'), 4);
    expect(b.quizzes.single.right, [1, 2]);
    // Signing in lasts for the day.
    expect(SchoolStore(file: f, now: () => DateTime(2026, 11, 5, 9)).current, isNull);
    var undone = false;
    b.pushUndo(const L10n('x'), () => undone = true);
    expect(b.undo(), isTrue);
    expect(undone, isTrue);
    expect(b.undo(), isFalse);
    dir.deleteSync(recursive: true);
  });

  testWidgets('first open → who is teaching → home, and the guide', (t) async {
    final s = await testServices(prefs: {'displaySize': 'classroom'});
    await pumpBoard(t, s);
    expect(find.byType(FirstOpenScreen), findsOneWidget);
    await tap(t, 'lang-kn');
    expect(s.config.lang.name, 'kn');
    await tap(t, 'lang-en');
    await tap(t, 'continue');
    expect(find.byType(WhoTodayScreen), findsOneWidget);
    await tap(t, 'addTeacher');
    await t.enterText(find.byKey(const ValueKey('teacherName')), 'K. Meera');
    await tap(t, 'teacherAdd');
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(s.school.current?.firstName, 'Meera');
    // The voice guide runs the first time: four steps, then it is done.
    expect(find.byKey(const ValueKey('tourCard')), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tap(t, 'tourNext');
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('tourCard')), findsNothing);
    expect(s.school.tourDone, isTrue);
  });

  testWidgets('a PIN is asked only when the school turns PINs on', (t) async {
    final s = await testServices(prefs: {'displaySize': 'classroom'});
    s.school.finishSetUp();
    final m = s.school.addTeacher('K. Meera', pin: '4321');
    await pumpBoard(t, s);
    await tap(t, 'teacher-${m.id}');
    expect(s.school.current?.id, m.id); // PINs off: a tap is enough
    s.school.signIn(null);
    s.school.setPinsOn(true);
    await t.pump(const Duration(milliseconds: 300));
    await tap(t, 'teacher-${m.id}');
    await t.enterText(find.byKey(const ValueKey('pinField')), '1111');
    await tap(t, 'pinOk');
    expect(s.school.current, isNull);
    await t.enterText(find.byKey(const ValueKey('pinField')), '4321');
    await tap(t, 'pinOk');
    expect(s.school.current?.id, m.id);
  });

  testWidgets('start my class opens where it was left; finish saves the class', (t) async {
    final s = await testServices(prefs: {'displaySize': 'classroom', 'taught': ['$grav.t1', '$grav.t2'], 'subjects': ['physics']}, now: DateTime(2026, 11, 4, 10, 5));
    final m = s.school.addTeacher('K. Meera');
    s.school
      ..finishSetUp()
      ..setTourDone(true)
      ..signIn(m.id)
      ..setPeriods([Period(id: 'p', start: '09:45', end: '10:40', subject: 'physics', days: const [3], teacherId: m.id)])
      ..setStep('$grav.t3', 2);
    final c = classNow(s);
    expect(c.lesson?.topicId, '$grav.t3');
    expect(c.isNow, isTrue);
    expect(c.minutesLeft, 35);
    await pumpBoard(t, s);
    await tap(t, 'startClass');
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(SimpleLessonScreen), findsOneWidget);
    expect(find.text('Step 3 of ${c.pack!.lessonFor(c.lesson!, s.config.board).blocks.length}'), findsOneWidget);
    // Help says what to do next, and Show me points at Next.
    await tap(t, 'lessonHelp');
    expect(find.byKey(const ValueKey('helpNext')), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('showMe')));
    await t.pump();
    await tap(t, 'showMe');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('spotlight')), findsOneWidget);
    await tap(t, 'spotlight');
    await tap(t, 'finishClass');
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(FinishClassScreen), findsOneWidget);
    final r = s.school.history.single;
    expect(r.topicId, '$grav.t3');
    expect(r.rollCount, s.config.rollCount);
    // Attendance by roll number, then undo it from "What do I do now?".
    await tap(t, 'changeAttendance');
    await tap(t, 'absent-7');
    await tap(t, 'absent-15');
    await tap(t, 'attendanceSave');
    expect(s.school.history.single.absent, [7, 15]);
    expect(s.school.undo(), isTrue);
    expect(s.school.history.single.absent, isEmpty);
    await tap(t, 'changeHomework');
    await t.enterText(find.byKey(const ValueKey('homeworkField')), 'Questions 8.3 and 8.5');
    await tap(t, 'homeworkSave');
    expect(s.school.history.single.homework, 'Questions 8.3 and 8.5');
  });

  testWidgets('the class quiz saves marks by roll number and gives house XP', (t) async {
    final s = await testServices(prefs: {'displaySize': 'classroom', 'rollCount': 40});
    final p = s.store.byChapter(grav)!;
    final qs = quizQuestions(p, topicId: '$grav.t3', n: 2);
    await pumpBoard(t, s, home: Builder(builder: (_) => SimpleQuizScreen(pack: p, questions: qs)));
    await tap(t, 'roll-1');
    await tap(t, 'roll-2');
    await tap(t, 'roll-3');
    expect(s.school.undo(), isTrue); // roll 3 unmarked again
    await tap(t, 'showAnswer');
    await tap(t, 'quizDone');
    final r = s.school.quizzes.single;
    expect(r.right, [1, 2]);
    expect(r.wrong.length, 38);
    expect(s.school.houses.first.xp, 20);
    expect(s.mastery.responses.where((x) => x.roll == 1 && x.correct), isNotEmpty);
  });

  testWidgets('practice class ticks itself and saves nothing', (t) async {
    final s = await testServices(prefs: {'displaySize': 'classroom'});
    await pumpBoard(t, s, home: const PracticeClassScreen());
    expect(find.text('1 of 5 done'), findsOneWidget);
    await tap(t, 'practiceNext');
    expect(find.text('2 of 5 done'), findsOneWidget);
    expect(s.school.history, isEmpty);
  });

  testWidgets('every place in all tools opens', (t) async {
    final s = await testServices(prefs: {'displaySize': 'classroom'});
    s.school.signIn(s.school.addTeacher('K. Meera').id);
    await pumpBoard(t, s, home: const ToolsShell(initial: Section.today));
    for (final sec in Section.values.where((x) => x != Section.board)) {
      await tap(t, 'rail-${sec.name}');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(ValueKey('section-${sec.name}')), findsOneWidget);
    }
    // The class tools are built from the installed packs.
    final data = buildSamples(s, ClassContent.empty, subject: 'physics');
    expect(data.questions, isNotEmpty);
    expect(data.formulas, isNotEmpty);
  });
}
