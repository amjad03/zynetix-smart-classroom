// The rail beside a simulation scrolls with its panels whole: on a classroom board the projectile's
// Readouts panel runs past the bottom, the rail says so (fade + scrollbar), and scrolling to the
// end shows the panel in full.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/block_view.dart';
import 'package:zynetix_board/core/ui.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/main.dart';

import 'helpers.dart';

void main() {
  testWidgets('the simulation rail scrolls to show the Readouts panel whole', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final s = await testServices(prefs: {'displaySize': 'classroom'});
    final hit = s.lessonFor('puc1-physics-03-motion-in-a-plane.t4')!;
    await t.pumpWidget(ZynetixBoardApp(services: s, home: LessonPlayerScreen(pack: hit.pack, lesson: hit.lesson)));
    await t.pump();
    final c = t.widget<BlockView>(find.byType(BlockView)).c;
    c.goTo(c.blocks.indexWhere((b) => b.id == 'scene-projectile'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    final rail = find.byKey(const ValueKey('railScroll'));
    expect(rail, findsOneWidget);
    final panel = find.ancestor(of: find.text('Readouts'), matching: find.byType(RailPanel));
    expect(panel, findsOneWidget);
    Rect view() => t.getRect(find.byType(RailScroll));
    // Before: the panel runs past the bottom, and the rail shows there is more.
    expect(t.getRect(panel).bottom, greaterThan(view().bottom));
    await t.pump();
    expect(t.widget<RawScrollbar>(find.descendant(of: find.byType(RailScroll), matching: find.byType(RawScrollbar))).thumbVisibility, isTrue);
    final pos = t.state<ScrollableState>(find.descendant(of: rail, matching: find.byType(Scrollable))).position;
    expect(pos.maxScrollExtent, greaterThan(0));
    // Scrolled into view, the whole Readouts panel is inside the rail.
    await t.drag(rail, const Offset(0, -2000));
    await t.pumpAndSettle();
    final ctx = t.element(panel);
    await t.runAsync(() => Scrollable.ensureVisible(ctx));
    await t.pump();
    final r = t.getRect(panel);
    expect(r.top, greaterThanOrEqualTo(view().top - 0.5));
    expect(r.bottom, lessThanOrEqualTo(view().bottom + 0.5));
    expect(t.takeException(), isNull);
  });
}
