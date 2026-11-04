// Touch activities (lib/blocks/activity/): the rules (place, check, reveal, reset, seeded
// shuffles) and each kind on screen by drag and by tap, with Check, Show answer and Start again,
// and the first Check recorded as a class answer.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/activity/activity_logic.dart';
import 'package:zynetix_board/blocks/activity/activity_view.dart';
import 'package:zynetix_board/blocks/scene/strings.dart';
import 'package:zynetix_board/core/theme.dart';
import 'package:zynetix_board/core/ui_scale.dart';
import 'package:zynetix_board/engine/mastery.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/period.dart';
import 'package:zynetix_board/engine/session_log.dart';

Map<String, dynamic> L(String en) => {'en': en};

Block act(String kind, Map<String, dynamic> fields, {String id = 'a1'}) => Block(BlockType.activity, {'id': id, 'type': 'activity', 'kind': kind, 'prompt': L('Do it'), ...fields});

final sortBlock = act('sort', {
  'questionId': 'act.test-sort',
  'buckets': [
    {'id': 'asset', 'label': L('Assets')},
    {'id': 'liab', 'label': L('Liabilities')},
  ],
  'items': [
    {'text': L('Cash'), 'answer': 'asset'},
    {'text': L('Creditors'), 'answer': 'liab'},
    {'text': L('Stock'), 'answer': 'asset'},
  ],
  'explanation': L('Owned versus owed.'),
});
final orderBlock = act('order', {
  'steps': [L('Prophase'), L('Metaphase'), L('Anaphase'), L('Telophase')],
});
final matchBlock = act('match', {
  'pairs': [
    {'left': L('Order'), 'right': L('A place for everything')},
    {'left': L('Equity'), 'right': L('Kindness and justice')},
    {'left': L('Discipline'), 'right': L('Rules kept by all')},
  ],
});
final diagram = {
  'view': {
    'x': [0, 10],
    'y': [0, 6],
  },
  'shapes': [
    {'shape': 'circle', 'x': 5, 'y': 3, 'r': 2.6, 'fill': false, 'color': 'green'},
    {'shape': 'circle', 'x': 5, 'y': 3, 'r': 0.8, 'color': 'blue'},
  ],
  'targets': [
    {'id': 'nucleus', 'x': 5, 'y': 3, 'r': 0.8, 'label': L('Nucleus')},
    {'id': 'membrane', 'x': 8.3, 'y': 4.5, 'r': 0.5, 'label': L('Membrane')},
    {'id': 'cytoplasm', 'x': 3, 'y': 1.6, 'r': 0.5, 'label': L('Cytoplasm')},
  ],
};
final labelBlock = act('label', {...diagram, 'distractors': [L('Cell wall')]});
final hotspotBlock = act('hotspot', {...diagram, 'answer': ['nucleus']});
final fillBlock = act('fill', {
  'passage': L('The __1__ falls on the __2__.'),
  'blanks': [
    {'options': [L('rain'), L('sun')], 'answer': 0},
    {'options': [L('sky'), L('hills')], 'answer': 1},
  ],
});

Future<ActivityViewState> pumpActivity(WidgetTester t, Block b, {SessionRecorder? recorder, Size size = const Size(1920, 1080)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: zynetixTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: ActivityView(block: b, lang: Lang.en, recorder: recorder),
        ),
      ),
    ),
  );
  await t.pump();
  return t.state<ActivityViewState>(find.byType(ActivityView));
}

Future<void> tapKey(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(ValueKey(key)));
  await t.tap(find.byKey(ValueKey(key)));
  await t.pump();
}

void main() {
  group('rules', () {
    test('sort: place, check per item, reveal, reset', () {
      final g = SortLogic(sortBlock);
      expect(g.complete, isFalse);
      g.place(0, 'asset');
      g.place(1, 'asset');
      g.place(2, 'asset');
      expect(g.check(), 2);
      expect(g.marks, [true, false, true]);
      g.place(1, 'liab');
      expect(g.marks, isEmpty, reason: 'a move clears the old marks');
      expect(g.allRight, isTrue);
      g.reset();
      expect(g.placed, [null, null, null]);
      g.reveal();
      expect(g.allRight, isTrue);
    });
    test('order and match start shuffled (never solved) and the same every time', () {
      final a = OrderLogic(orderBlock), b = OrderLogic(orderBlock);
      expect(a.order, b.order);
      expect(a.allRight, isFalse);
      a.reveal();
      expect(a.order, [0, 1, 2, 3]);
      final m = MatchLogic(matchBlock);
      expect(m.rightOrder.toSet(), {0, 1, 2});
      m.join(0, 1);
      m.join(1, 1);
      expect(m.link, [null, 1, null], reason: 'a right card belongs to one left card');
      // Two items can never start in order, even when the shuffle would leave them so.
      for (var i = 0; i < 30; i++) {
        final two = OrderLogic(act('order', {'steps': [L('a'), L('b')]}, id: 'x$i'));
        expect(two.order, [1, 0]);
      }
    });
    test('label, hotspot and fill', () {
      final lb = LabelLogic(labelBlock);
      expect(lb.chips.length, 4);
      final nucleusChip = lb.chips.indexWhere((c) => c.target == 0);
      final wrong = lb.chips.indexWhere((c) => c.target == null);
      lb.place(wrong, 0);
      lb.place(nucleusChip, 1);
      expect(lb.check(), 0);
      lb.place(nucleusChip, 0);
      expect(lb.onTarget[0], nucleusChip);
      expect(lb.free, contains(wrong), reason: 'the chip it replaced goes back');
      final h = HotspotLogic(hotspotBlock)..tap(0);
      expect(h.allRight, isTrue);
      h.tap(2);
      expect(h.check(), 2);
      final f = FillLogic(fillBlock)..choose(0, 0);
      expect(f.complete, isFalse);
      f.choose(1, 1);
      expect(f.allRight, isTrue);
      expect(FillLogic.pieces('The __1__ falls on the __2__.'), ['The ', 0, ' falls on the ', 1, '.']);
    });
    test('the period planner and every string in both languages', () {
      expect(PeriodPlanner.estimate(sortBlock), greaterThanOrEqualTo(3 * 8 + 20));
      for (final k in sceneStringKeys) {
        expect(st(k, Lang.kn), isNot(st(k, Lang.en)), reason: k);
      }
    });
  });

  testWidgets('sort by tap and by drag; check, show answer, start again; the first check is recorded', (t) async {
    final dir = Directory.systemTemp.createTempSync('zx-act');
    addTearDown(() => dir.deleteSync(recursive: true));
    final mastery = MasteryStore();
    final rec = SessionRecorder.raw(outbox: Outbox(File('${dir.path}/o.jsonl')), sectionId: 's', mode: 'teacher', chapterId: 'c', topicId: 't', lessonId: 'l', packVersion: '1', mastery: mastery);
    final s = await pumpActivity(t, sortBlock, recorder: rec);
    final g = s.logic as SortLogic;
    // Check before everything is placed.
    await tapKey(t, 'activityCheck');
    expect(find.text(st('notDone', Lang.en)), findsOneWidget);
    // Tap Cash, then Liabilities (wrong on purpose).
    await tapKey(t, 'item-0');
    await tapKey(t, 'bucket-liab');
    expect(g.placed[0], 'liab');
    // Drag Creditors to Liabilities, Stock to Assets.
    await t.drag(find.byKey(const ValueKey('item-1')), t.getCenter(find.byKey(const ValueKey('bucket-liab'))) - t.getCenter(find.byKey(const ValueKey('item-1'))));
    await t.pump();
    await t.drag(find.byKey(const ValueKey('item-2')), t.getCenter(find.byKey(const ValueKey('bucket-asset'))) - t.getCenter(find.byKey(const ValueKey('item-2'))));
    await t.pump();
    expect(g.placed, ['liab', 'liab', 'asset']);
    await tapKey(t, 'activityCheck');
    expect(find.textContaining('2 of 3'), findsOneWidget);
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(rec.log['answers'], [containsPair('correct', false)]);
    expect((rec.log['answers'] as List).single['source'], 'activity');
    // Move Cash to Assets and check again: right, and not recorded twice.
    await t.drag(find.byKey(const ValueKey('item-0')), t.getCenter(find.byKey(const ValueKey('bucket-asset'))) - t.getCenter(find.byKey(const ValueKey('item-0'))));
    await t.pump();
    await tapKey(t, 'activityCheck');
    expect(find.text(st('allRight', Lang.en)), findsOneWidget);
    expect(find.textContaining('Owned versus owed'), findsOneWidget);
    expect((rec.log['answers'] as List).length, 1);
    // Start again, then show the answer.
    await tapKey(t, 'activityReset');
    expect(g.placed, [null, null, null]);
    await tapKey(t, 'activityShow');
    expect(g.allRight, isTrue);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
  });

  testWidgets('order with the arrows, then check', (t) async {
    final s = await pumpActivity(t, orderBlock);
    final g = s.logic as OrderLogic;
    // Bubble each step into place with the up arrows.
    for (var step = 0; step < 4; step++) {
      while (g.order.indexOf(step) != step) {
        await tapKey(t, 'up-$step');
      }
    }
    expect(g.order, [0, 1, 2, 3]);
    await tapKey(t, 'activityCheck');
    expect(find.text(st('allRight', Lang.en)), findsOneWidget);
    await tapKey(t, 'activityReset');
    expect(g.allRight, isFalse);
  });

  testWidgets('match by tap and by drag', (t) async {
    final s = await pumpActivity(t, matchBlock);
    final g = s.logic as MatchLogic;
    await tapKey(t, 'left-0');
    await tapKey(t, 'right-0');
    expect(g.link[0], 0);
    await t.drag(find.byKey(const ValueKey('left-1')), t.getCenter(find.byKey(const ValueKey('right-2'))) - t.getCenter(find.byKey(const ValueKey('left-1'))));
    await t.pump();
    expect(g.link[1], 2);
    await tapKey(t, 'left-2');
    await tapKey(t, 'right-1');
    await tapKey(t, 'activityCheck');
    expect(find.textContaining('1 of 3'), findsOneWidget);
    await tapKey(t, 'activityShow');
    expect(g.allRight, isTrue);
  });

  testWidgets('label a diagram by tap and by drag', (t) async {
    final s = await pumpActivity(t, labelBlock);
    final g = s.logic as LabelLogic;
    int chipFor(int target) => g.chips.indexWhere((c) => c.target == target);
    await tapKey(t, 'chip-${chipFor(0)}');
    await tapKey(t, 'target-nucleus');
    expect(g.onTarget[0], chipFor(0));
    final c1 = chipFor(1);
    await t.drag(find.byKey(ValueKey('chip-$c1')), t.getCenter(find.byKey(const ValueKey('target-membrane'))) - t.getCenter(find.byKey(ValueKey('chip-$c1'))));
    await t.pump();
    expect(g.onTarget[1], c1);
    final wrong = g.chips.indexWhere((c) => c.target == null);
    await tapKey(t, 'chip-$wrong');
    await tapKey(t, 'target-cytoplasm');
    await tapKey(t, 'activityCheck');
    expect(find.textContaining('2 of 3'), findsOneWidget);
    // Tapping a placed label sends it back.
    await tapKey(t, 'target-cytoplasm');
    expect(g.onTarget[2], isNull);
  });

  testWidgets('hotspot: tap the right spot; names show after check', (t) async {
    final s = await pumpActivity(t, hotspotBlock);
    expect(find.text('Nucleus'), findsNothing);
    await tapKey(t, 'target-membrane');
    await tapKey(t, 'activityCheck');
    expect(find.textContaining('1 of 3'), findsOneWidget);
    expect(find.text('Nucleus'), findsOneWidget);
    await tapKey(t, 'target-membrane');
    await tapKey(t, 'target-nucleus');
    await tapKey(t, 'activityCheck');
    expect(s.logic.allRight, isTrue);
  });

  testWidgets('fill: tap a blank, choose a word; the next blank opens', (t) async {
    final s = await pumpActivity(t, fillBlock, size: const Size(844, 390));
    await tapKey(t, 'blank-0');
    await tapKey(t, 'option-0-0');
    expect(find.text('rain'), findsOneWidget);
    await tapKey(t, 'option-1-1');
    await tapKey(t, 'activityCheck');
    expect(s.logic.allRight, isTrue);
    await tapKey(t, 'activityReset');
    expect(find.text('____ 1'), findsOneWidget);
  });

  for (final (name, size, scale) in const [('phone portrait', Size(390, 844), 0.5), ('phone landscape', Size(844, 390), 0.5), ('board classroom', Size(1920, 1080), 1.0)]) {
    testWidgets('every kind fits with feedback shown: $name', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final problems = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (e) => problems.add(e.exceptionAsString().split('\n').first);
      for (final b in [sortBlock, orderBlock, matchBlock, labelBlock, hotspotBlock, fillBlock]) {
        for (final l in Lang.values) {
          await t.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              theme: zynetixTheme(),
              builder: (context, c) => UiScale(scale: scale, child: c!),
              home: Scaffold(
                body: Padding(padding: const EdgeInsets.all(24), child: ActivityView(block: b, lang: l)),
              ),
            ),
          );
          await t.pump();
          t.state<ActivityViewState>(find.byType(ActivityView)).showAnswer();
          await t.pump();
        }
      }
      FlutterError.onError = old;
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}
