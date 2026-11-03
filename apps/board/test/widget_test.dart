import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/period.dart';
import 'package:zynetix_board/features/self_learning.dart';

import 'helpers.dart';

void main() {
  testWidgets('a lesson starts in 3 taps from Home and logs the session', (t) async {
    final s = await testServices();
    await pumpBoard(t, s);
    var taps = 0;
    Future<void> tap(Finder f) async {
      await t.tap(f);
      taps++;
      await t.pumpAndSettle();
    }

    await tap(find.byKey(const ValueKey('teacherMode')));
    await tap(find.text('Physics'));
    await tap(find.byKey(const ValueKey('start:puc1-physics-02-motion-in-a-straight-line.t1')));
    expect(taps, lessThanOrEqualTo(3));
    expect(find.text('Where is it, and how far did it really go?'), findsOneWidget);

    // Walk to the end with Next, then Finish.
    while (find.byKey(const ValueKey('next')).evaluate().isNotEmpty) {
      await t.tap(find.byKey(const ValueKey('next')));
      await t.pump();
    }
    expect(find.byKey(const ValueKey('embed:sim:kinetix_sim:lab.graph-plotter')), findsNothing, reason: 'media is gone by the last block');
    await t.tap(find.byKey(const ValueKey('finish')));
    await t.pumpAndSettle();
    expect(s.config.taught, contains('puc1-physics-02-motion-in-a-straight-line.t1'));
    final log = s.outbox.pending().single;
    expect(log['mode'], 'teacher');
    expect(log['completed'], isTrue);
    expect(log.toString(), isNot(contains('name')));
  });

  testWidgets('Continue starts the next untaught topic in one tap', (t) async {
    final s = await testServices(prefs: {'taught': ['puc1-physics-02-motion-in-a-straight-line.t1']});
    await pumpBoard(t, s);
    await t.tap(find.byKey(const ValueKey('continue')));
    await t.pumpAndSettle();
    expect(find.text('Instantaneous velocity and speed'), findsWidgets);
  });

  testWidgets('roll-call quiz: pick a roll, the monitor taps the answer, it is logged by roll number', (t) async {
    final s = await testServices();
    await pumpBoard(t, s);
    final p = s.store.byChapter('puc1-physics-02-motion-in-a-straight-line')!;
    // Topic 3's quiz is roll_call.
    await t.tap(find.byKey(const ValueKey('teacherMode')));
    await t.pumpAndSettle();
    await t.tap(find.text('Physics'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(ValueKey('start:${p.chapter.id}.t3')), 200, scrollable: find.byType(Scrollable).last);
    await t.tap(find.byKey(ValueKey('start:${p.chapter.id}.t3')));
    await t.pumpAndSettle();
    while (find.text('Pick a roll number').evaluate().isEmpty) {
      await t.tap(find.byKey(const ValueKey('next')));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('Pick a roll number'));
    await t.pump();
    expect(find.byKey(const ValueKey('roll')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('option-1')));
    await t.pump();
    expect(find.text('Next question'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('close')));
    await t.pumpAndSettle();
    final a = (s.outbox.pending().single['answers'] as List).single as Map;
    expect(a['mode'], 'roll_call');
    expect(a['roll'], inInclusiveRange(1, 60));
    expect(a['correct'], isTrue); // mot-q16: answer B
  });

  testWidgets('Self-Learning cannot be left without the teacher PIN', (t) async {
    final s = await testServices();
    final p = s.store.byChapter('puc2-chemistry-01-solutions')!;
    await pumpBoard(t, s, home: SelfLearningScreen(pack: p, lesson: p.lessons.values.first, periodSeconds: 2400, autoTick: false));
    await t.pump();
    // System back does nothing.
    await t.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await t.pumpAndSettle();
    expect(find.byType(SelfLearningScreen), findsOneWidget);
    // Wrong PIN keeps us in.
    await t.tap(find.byKey(const ValueKey('lockExit')));
    await t.pumpAndSettle();
    for (final k in ['9', '9', '9', '9']) {
      await t.tap(find.byKey(ValueKey('pin-$k')));
    }
    await t.pump();
    await t.tap(find.byKey(const ValueKey('pin-ok')));
    await t.pumpAndSettle();
    expect(find.text('Wrong PIN'), findsOneWidget);
    for (final k in ['1', '2', '3', '4']) {
      await t.tap(find.byKey(ValueKey('pin-$k')));
    }
    await t.pump();
    await t.tap(find.byKey(const ValueKey('pin-ok')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('teacherMode')), findsOneWidget);
  });

  testWidgets('a scheduled period is offered as the Self-Learning topic', (t) async {
    final now = DateTime(2026, 11, 4, 10, 5);
    final s = await testServices(
      now: now,
      prefs: {'schedule': '[{"date":"2026-11-04","start":"10:00","end":"10:40","topicId":"puc2-chemistry-01-solutions.t4"}]'},
    );
    expect(s.config.scheduledNow(now)?.topicId, endsWith('.t4'));
    expect(ScheduledPeriod.fromJson({'date': '2026-11-04', 'start': '10:00', 'end': '10:40', 'topicId': 'x'}).secondsLeft(now), 35 * 60);
    await pumpBoard(t, s, home: const SelfLearningStartScreen());
    expect(find.text('Scheduled by the college'), findsOneWidget);
    expect(find.text('Colligative properties'), findsOneWidget);
  });
}
