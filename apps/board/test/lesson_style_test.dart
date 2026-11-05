// The "one idea at a time" lesson style (Physical quantities, puc1 physics t1, read from its
// source in content/packs): Next reveals a block's cards before moving on, Back shows a block
// whole, Pause and think answers on a tap, and every block fits a phone and a board in English
// and Kannada.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/lesson_controller.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/narrator.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/main.dart';

import 'helpers.dart';

const topic = 'puc1-physics-01-units-and-measurement.t1';

Future<(Services, InstalledPack, Lesson)> load({Map<String, Object> prefs = const {}}) async {
  final s = await testServices(prefs: prefs);
  final pack = sourcePack(s.lessonFor(topic)!.pack, 'puc1-physics-units-and-measurement');
  return (s, pack, pack.lessons[topic]!);
}

void main() {
  test('the lesson uses the new styles and every question it names exists', () async {
    final (_, pack, lesson) = await load();
    final styles = {for (final b in lesson.blocks) ?b.style};
    expect(styles, containsAll(['pause', 'solve', 'rule', 'trap', 'recall']));
    expect(lesson.blocks.where((b) => b.speaker != null), isNotEmpty);
    for (final b in lesson.blocks) {
      for (final id in [...b.ids('questionIds'), ...b.ids('homeworkQuestionIds')]) {
        expect(pack.questions[id], isNotNull, reason: '${b.id} → $id');
      }
    }
    final either = pack.questions['1p01-q32']!;
    expect(either.format, 'either_or');
    expect(either.options, hasLength(2));
    expect(pack.questions['1p01-q31']!.solution, hasLength(4));
  });

  test('Next reveals a block one idea at a time, then moves on; Back shows a block whole', () async {
    final (s, pack, lesson) = await load();
    final rec = SessionRecorder.raw(outbox: s.outbox, sectionId: 's', mode: 'teacher', chapterId: lesson.chapterId, topicId: lesson.topicId, lessonId: lesson.id, packVersion: '1');
    final c = LessonController(pack: pack, lesson: lesson, narrator: TimedNarrator(perWord: Duration.zero), recorder: rec, lang: Lang.en);
    expect(c.current.id, 'hook');
    expect(c.revealTotal, 3); // three cards
    expect(c.revealed, 1);
    c.next();
    c.next();
    expect((c.index, c.revealed), (0, 3));
    c.next();
    expect(c.current.id, 'number-alone');
    expect(c.revealed, 1);
    c.back();
    expect(c.current.id, 'hook');
    expect(c.revealed, 3);
    // Pause and think: the question, then its answer.
    c.goTo(lesson.blocks.indexWhere((b) => b.style == 'pause'));
    expect(c.revealTotal, 2);
    // The exam-pattern question: the question, then one step per solution line.
    c.goTo(lesson.blocks.indexWhere((b) => b.style == 'solve'));
    expect(c.revealTotal, 5);
    c.dispose();
  });

  testWidgets('Pause and think: a tap shows the right answer and why, and is recorded', (t) async {
    final (s, pack, lesson) = await load(prefs: {'displaySize': 'classroom'});
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [lesson.blocks.firstWhere((b) => b.id == 'think-temperature')])));
    expect(find.text('Tap the class answer'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('think-1'))); // "Derived": wrong
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('A thermometer reads it directly'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final lang in Lang.values) {
    for (final (name, size, display) in [('board', const Size(1920, 1080), 'classroom'), ('phone', const Size(390, 844), 'normal')]) {
      testWidgets('every block fits: $name, ${lang.name}', (t) async {
        final (s, pack, lesson) = await load(prefs: {'displaySize': display, 'lang': lang.name});
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(ZynetixBoardApp(services: s, home: LessonPlayerScreen(pack: pack, lesson: lesson)));
        await t.pump();
        final errors = <String>[];
        var seen = 0;
        for (var guard = 0; guard < 120; guard++) {
          await t.pump(const Duration(milliseconds: 300));
          final e = t.takeException();
          if (e != null) errors.add('step $guard: $e');
          if (find.byKey(const ValueKey('finish')).evaluate().isNotEmpty) break;
          await t.tap(find.byKey(const ValueKey('next')));
          seen++;
        }
        expect(errors, isEmpty);
        expect(find.byKey(const ValueKey('nextTeaser')), findsOneWidget);
        expect(seen, greaterThan(lesson.blocks.length));
      });
    }
  }
}

Lesson lessonWith(InstalledPack p, List<Block> blocks) {
  final l = p.lessons[topic]!;
  return Lesson(id: l.id, chapterId: l.chapterId, topicId: l.topicId, title: l.title, minutes: l.minutes, blocks: blocks);
}
