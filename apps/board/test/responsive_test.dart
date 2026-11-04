// Every main screen at phone, tablet and board sizes, in both orientations: no overflow and
// nothing thrown. Errors are collected per screen so one run lists everything to fix.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/features/exam_practice.dart';
import 'package:zynetix_board/features/home.dart';
import 'package:zynetix_board/features/pin.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/features/self_learning.dart';
import 'package:zynetix_board/features/smartboard.dart';
import 'package:zynetix_board/features/teacher_mode.dart';
import 'package:zynetix_board/main.dart';

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
      FlutterError.onError = (e) => problems.add('$where: ${e.exceptionAsString().split('\n').first}');
      addTearDown(() => FlutterError.onError = old);
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final s = await testServices(prefs: {'displaySize': display, 'taught': ['puc1-physics-02-motion-in-a-straight-line.t1']});

      Future<void> show(String name, Widget home) async {
        where = name;
        await t.pumpWidget(ZynetixBoardApp(key: UniqueKey(), services: s, home: home));
        await t.pump(const Duration(milliseconds: 500));
      }

      await show('home', const HomeScreen());
      await show('teacher mode', const TeacherModeScreen());
      await show('exam practice', const ExamPracticeScreen());
      await show('smartboard', SmartboardScreen(controller: SmartboardScreen.newBoard()));
      await show('pin', Scaffold(body: Center(child: PinDialog(config: s.config))));
      for (final topic in topics) {
        final hit = s.lessonFor(topic)!;
        await show('player $topic', LessonPlayerScreen(pack: hit.pack, lesson: hit.lesson));
        for (var i = 1; i < hit.lesson.blocks.length; i++) {
          where = 'player $topic block ${hit.lesson.blocks[i].id} (${hit.lesson.blocks[i].type.wire})';
          await t.tap(find.byKey(const ValueKey('next')), warnIfMissed: false);
          await t.pump(const Duration(milliseconds: 400));
        }
      }
      final sl = s.lessonFor(topics.first)!;
      await show('self-learning', SelfLearningScreen(pack: sl.pack, lesson: sl.lesson, periodSeconds: 2400, autoTick: false));
      await t.pumpWidget(const SizedBox());
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}

