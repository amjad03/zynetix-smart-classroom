// Kinetix labs on the stage: on a classroom board and on a phone, where the lab's own panel
// (readouts, controls, aim) runs past the stage, a "more" button says so and brings every part of
// it into view.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/block_view.dart';
import 'package:zynetix_board/blocks/embeds.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/core/ui.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/main.dart';

import 'helpers.dart';

const labs = [
  ('puc2-physics-03-current-electricity.t1', 'lab-ohms-law'),
  ('puc2-physics-03-current-electricity.t1', 'sim-lab.ohms-law'),
  ('puc2-physics-03-current-electricity.t2', 'lab-meter-bridge'),
  ('puc1-chemistry-06-equilibrium.t4', 'lab-titration-hcl-naoh'),
  ('puc1-chemistry-01-some-basic-concepts-of-chemistry.t5', 'lab-titration-oxalic-naoh'),
];

const sizes = <String, (Size, String)>{
  'classroom': (Size(1920, 1080), 'classroom'),
  'phone': (Size(390, 844), 'normal'),
};

void main() {
  for (final sz in sizes.entries) {
    testWidgets('every lab panel is reachable whole: ${sz.key}', (t) async {
      final (size, display) = sz.value;
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final base = await testServices(prefs: {'displaySize': display});
      final s = Services(config: base.config, store: base.store, outbox: base.outbox, narrator: base.narrator, syllabus: base.syllabus, embeds: KinetixEmbeds(), clock: base.clock);
      var checked = 0, cued = 0;
      for (final (topic, id) in labs) {
        final hit = s.lessonFor(topic)!;
        final i = hit.lesson.blocks.indexWhere((b) => b.id == id);
        if (i < 0) continue; // not in this lesson (content changes)
        await t.pumpWidget(ZynetixBoardApp(key: UniqueKey(), services: s, home: LessonPlayerScreen(pack: hit.pack, lesson: hit.lesson)));
        await t.pump();
        t.widget<BlockView>(find.byType(BlockView)).c.goTo(i);
        for (var k = 0; k < 6; k++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        final frame = find.byType(LabFrame);
        expect(frame, findsOneWidget, reason: id);
        List<ScrollPosition> inner() => [
          for (final e in find.descendant(of: frame, matching: find.byType(Scrollable)).evaluate())
            if (((e as StatefulElement).state as ScrollableState).position case final p when p.axis == Axis.vertical) p,
        ];
        // Where the lab's panel runs past the stage, the "more" button says so and scrolls it on.
        final more = find.byKey(const ValueKey('labMore'));
        if (inner().any((p) => p.extentAfter > 1)) {
          expect(more, findsOneWidget, reason: '$id: cut off with no cue');
          cued++;
        }
        checked++;
        for (var k = 0; k < 30 && more.evaluate().isNotEmpty; k++) {
          await t.tap(more);
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          await t.pump();
        }
        expect(more, findsNothing, reason: id);
        for (final p in inner()) {
          expect(p.extentAfter, lessThanOrEqualTo(1), reason: '$id: the end of the lab is out of reach');
        }
        expect(t.takeException(), isNull, reason: id);
      }
      expect(checked, greaterThanOrEqualTo(3));
      expect(cued, greaterThan(0), reason: 'no lab ran past the stage: the test no longer exercises the cue');
      await t.pumpWidget(const SizedBox());
    });
  }
}
