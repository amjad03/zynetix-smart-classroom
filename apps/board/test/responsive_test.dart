// Every main screen at phone, tablet and board sizes, in both orientations: no overflow and
// nothing thrown. Errors are collected per screen so one run lists everything to fix.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/features/exam_practice.dart';
import 'package:zynetix_board/features/app/home.dart';
import 'package:zynetix_board/features/app/lesson.dart';
import 'package:zynetix_board/features/app/practice.dart';
import 'package:zynetix_board/features/app/shell.dart';
import 'package:zynetix_board/features/app/start.dart';
import 'package:zynetix_board/features/pin.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/features/self_learning.dart';
import 'package:zynetix_board/features/smartboard.dart';
import 'package:zynetix_board/features/teacher_mode.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/features/participation.dart';
import 'package:zynetix_board/main.dart';

import 'fixtures.dart';
import 'helpers.dart';

const devices = <String, (Size, String)>{
  'phone portrait': (Size(390, 844), 'normal'),
  'phone landscape': (Size(844, 390), 'normal'),
  'tablet portrait': (Size(800, 1280), 'normal'),
  'tablet landscape': (Size(1280, 800), 'normal'),
  'board large': (Size(1920, 1080), 'large'),
  'board classroom': (Size(1920, 1080), 'classroom'),
};

/// Lessons that between them use every block type, in Physics, Accountancy and Economics.
const topics = [
  'puc1-physics-02-motion-in-a-straight-line.t1',
  'puc1-physics-02-motion-in-a-straight-line.t3',
  'puc1-physics-02-motion-in-a-straight-line.t4',
  'puc2-accountancy-09-accounting-ratios.t2',
  'puc2-economics-02-theory-of-consumer-behaviour.t3',
];

void main() {
  for (final d in devices.entries) {
    testWidgets('screens fit: ${d.key}', (t) async {
      final (size, display) = d.value;
      final problems = <String>[];
      var where = '';
      final old = FlutterError.onError;
      FlutterError.onError = (e) {
        final p = '$where: ${e.exceptionAsString().split('\n').first}';
        if (!problems.contains(p)) debugPrint('PROBLEM $p');
        problems.add(p);
      };
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = await testServices(prefs: {'displaySize': display, 'taught': ['puc1-physics-02-motion-in-a-straight-line.t1']});

      Future<void> show(String name, Widget home) async {
        where = name;
        await t.pumpWidget(ZynetixBoardApp(key: UniqueKey(), services: s, home: home));
        await t.pump(const Duration(milliseconds: 500));
      }

      await show('first open', const FirstOpenScreen());
      await show('who is teaching (empty)', const WhoTodayScreen());
      s.school.signIn(s.school.addTeacher('K. Meera').id);
      s.school.addTeacher('S. Prakash');
      await show('who is teaching', const WhoTodayScreen());
      await show('home', const HomeScreen(tour: false));
      await show('home with the guide', const HomeScreen(tour: true));
      s.school.setShowAll(true);
      await show('home, all tools', const HomeScreen(tour: false));
      s.school.setShowAll(false);
      for (final sec in Section.values.where((x) => x != Section.board)) {
        await show('all tools: ${sec.name}', ToolsShell(initial: sec));
      }
      await show('practice class', const PracticeClassScreen());
      final first = s.lessonFor(topics.first)!;
      await show('simple lesson', SimpleLessonScreen(pack: first.pack, lesson: first.lesson));
      await show('teacher mode', const TeacherModeScreen());
      await show('exam practice', const ExamPracticeScreen());
      await show('smartboard', SmartboardScreen(controller: SmartboardScreen.newBoard()));
      await show('pin', Scaffold(body: Center(child: PinDialog(config: s.config))));
      for (final topic in topics) {
        final hit = s.lessonFor(topic)!;
        await show('player $topic', LessonPlayerScreen(pack: hit.pack, lesson: hit.lesson));
        for (var i = 1; i < hit.lesson.blocks.length; i++) {
          where = 'player $topic block ${hit.lesson.blocks[i].id} (${hit.lesson.blocks[i].type.wire})';
          if (find.byKey(const ValueKey('next')).evaluate().isEmpty) break;
          await t.tap(find.byKey(const ValueKey('next')));
          await t.pump(const Duration(milliseconds: 400));
        }
      }
      // The quiz with a numeric keypad, and with the longest question stem in the packs.
      final longest = ([for (final p in s.store.packs) ...p.questions.values]..sort((a, b) => b.stem.en.length.compareTo(a.stem.en.length))).first;
      final rec = SessionRecorder.raw(outbox: s.outbox, sectionId: 's', mode: 'teacher', chapterId: 'c', topicId: 't', lessonId: 'l', packVersion: '1');
      for (final (name, q) in [('numeric', numericQuestion()), ('longest stem ${longest.id}', longest)]) {
        await show('quiz $name', Scaffold(body: Padding(padding: const EdgeInsets.all(20), child: QuizRunner(questions: [q], mode: QuizMode.rollCall, lang: Lang.en, recorder: rec, room: ClassRoom(rollCount: 60), showExams: true))));
      }
      final sl = s.lessonFor(topics.first)!;
      await show('self-learning', SelfLearningScreen(pack: sl.pack, lesson: sl.lesson, periodSeconds: 2400, autoTick: false));
      await t.pumpWidget(const SizedBox());
      FlutterError.onError = old;
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}

