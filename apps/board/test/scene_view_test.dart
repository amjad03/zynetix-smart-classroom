// Scenes on screen: play/pause, step, speed, scrub, buttons, toggles, choices and draggable
// handles; a scene challenge; and every scene and activity in content/packs drawn without
// overflow on a phone held both ways (display size normal) and on a classroom board.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/activity/activity_view.dart';
import 'package:zynetix_board/blocks/challenge_view.dart';
import 'package:zynetix_board/blocks/interactive_view.dart';
import 'package:zynetix_board/blocks/scene/scene_painter.dart';
import 'package:zynetix_board/core/theme.dart';
import 'package:zynetix_board/core/ui_scale.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/game/game_store.dart';
import 'package:zynetix_board/features/participation.dart';

Block contentBlock(String lesson, String id) => Block.fromJson(((jsonDecode(File('../../content/packs/$lesson').readAsStringSync())['blocks'] as List).cast<Map<String, dynamic>>()).firstWhere((b) => b['id'] == id))!;

/// Every block in content/packs that is a scene, a timed playfield, or an activity.
List<(String, Block)> contentScenes() => [
  for (final f in Directory('../../content/packs').listSync(recursive: true).whereType<File>().where((f) => f.path.contains('/lessons/') && f.path.endsWith('.json')))
    for (final b in (jsonDecode(f.readAsStringSync())['blocks'] as List).cast<Map<String, dynamic>>())
      if (b['type'] == 'activity' || b['kind'] == 'scene' || b['time'] != null) ('${f.path.split('/packs/').last} ${b['id']}', Block.fromJson(b)!),
];

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  key: UniqueKey(),
  theme: zynetixTheme(),
  builder: (context, c) => UiScale(scale: scale, child: c!),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(24), child: child),
  ),
);

Future<InteractiveViewState> pumpScene(WidgetTester t, Block b, {Size size = const Size(1920, 1080)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(app(InteractiveView(block: b, lang: Lang.en)));
  await t.pump();
  return t.state<InteractiveViewState>(find.byType(InteractiveView));
}

void main() {
  const projectile = ('puc1-physics-motion-in-a-plane/lessons/t4.json', 'scene-projectile');

  testWidgets('launch, pause, step, speed, scrub and reset a projectile', (t) async {
    final s = await pumpScene(t, contentBlock(projectile.$1, projectile.$2));
    expect(s.rt.playing, isFalse);
    expect(find.byKey(const ValueKey('timeScrub')), findsOneWidget);
    // Launch: reset + play.
    await t.tap(find.byKey(const ValueKey('button-0')));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(s.rt.playing, isTrue);
    expect(s.rt.t, greaterThan(0.3));
    // Pause.
    await t.tap(find.byKey(const ValueKey('timePlay')));
    await t.pump();
    final paused = s.rt.t;
    await t.pump(const Duration(milliseconds: 500));
    expect(s.rt.t, paused);
    // Step moves one frame.
    await t.tap(find.byKey(const ValueKey('timeStep')));
    await t.pump();
    expect(s.rt.t, closeTo(paused + 1 / 60, 1e-9));
    // Speed cycles 1× → 2×.
    expect(find.text('1×'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('timeSpeed')));
    await t.pump();
    expect(s.rt.speed, 2);
    // Scrub to the far right: the ball has landed (stopped at its landing time, not at 6 s).
    await t.drag(find.byKey(const ValueKey('timeScrub')), const Offset(2000, 0));
    await t.pump();
    expect(s.rt.t, greaterThan(1));
    expect(s.rt.env['py'], 0);
    expect(find.textContaining('${s.rt.t.toStringAsFixed(2)} s'), findsOneWidget);
    // Reset.
    await t.tap(find.byKey(const ValueKey('timeReset')));
    await t.pump();
    expect(s.rt.t, 0);
    // Paused, the ticker is stopped: the frame pipeline settles.
    await t.pumpAndSettle();
    expect(s.rt.playing, isFalse);
  });

  testWidgets('a scene plays at 60 fps only while playing, and pauses when its route is hidden', (t) async {
    final s = await pumpScene(t, contentBlock('puc1-physics-waves/lessons/t3.json', 'scene-wave'));
    expect(s.rt.playing, isTrue, reason: 'autoplay');
    await t.pump(const Duration(milliseconds: 16));
    final t0 = s.rt.t;
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(s.rt.t - t0, closeTo(0.96, 0.02));
    // Hidden (TickerMode off, as for a route underneath another): time stands still.
    await t.pumpWidget(app(TickerMode(enabled: false, child: InteractiveView(block: s.widget.block, lang: Lang.en))));
    final hidden = t.state<InteractiveViewState>(find.byType(InteractiveView));
    final th = hidden.rt.t;
    await t.pump(const Duration(seconds: 1));
    expect(hidden.rt.t, th);
  });

  testWidgets('toggles and choices change the model', (t) async {
    final s = await pumpScene(t, contentBlock('puc1-physics-kinetic-theory/lessons/t3.json', 'scene-gas'));
    expect(s.values['track'], 0);
    await t.tap(find.byKey(const ValueKey('toggle-track')));
    await t.pump();
    expect(s.values['track'], 1);
    final n2 = s.rt.env['vrms']!;
    await t.tap(find.byKey(const ValueKey('choice-M-0'))); // helium
    await t.pump();
    expect(s.values['M'], 4);
    expect(s.rt.env['vrms'], greaterThan(n2 * 2.5));
    expect(find.textContaining('m/s'), findsWidgets);
    s.rt.pause();
    await t.pump();
  });

  testWidgets('drag a handle: the lens object moves and the image follows', (t) async {
    final s = await pumpScene(t, contentBlock('puc2-physics-ray-optics-and-optical-instruments/lessons/t4.json', 'scene-lens'));
    final v0 = s.rt.env['v']!;
    expect(v0, closeTo(-25 * 10 / (-25 + 10), 1e-9));
    final chart = t.getRect(find.byKey(const ValueKey('interactiveChart')));
    final frame = SceneFrame(chart.size, s.model.view, equal: true);
    final at = chart.topLeft + frame.toScreen(-25, 4);
    // Drag 15 cm towards the lens.
    await t.dragFrom(at, Offset(15 * frame.sx, 0));
    await t.pump();
    expect(s.values['O_x'], closeTo(-10, 0.6));
    expect(s.rt.env['v']!.abs(), greaterThan(100), reason: 'near F the image runs off far away');
    // A drag that starts away from every handle does nothing.
    await t.dragFrom(chart.center + const Offset(0, 200), const Offset(-300, 0));
    await t.pump();
    expect(s.values['O_x'], closeTo(-10, 0.6));
  });

  testWidgets('a scene challenge hides time until it is over, launches on lock-in and wins', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = GameStore();
    await t.pumpWidget(app(ChallengeView(block: contentBlock(projectile.$1, 'challenge-launch'), lang: Lang.en, room: ClassRoom(rollCount: 40), game: game)));
    await t.pump();
    expect(find.byKey(const ValueKey('timeScrub')), findsNothing);
    final play = t.state<InteractiveViewState>(find.byType(InteractiveView));
    play.setValue('v', 15);
    await t.tap(find.byKey(const ValueKey('lockIn')));
    await t.pump();
    expect(find.textContaining('Too low'), findsOneWidget);
    expect(play.rt.playing, isTrue, reason: 'the try is launched');
    for (var i = 0; i < 200; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(play.rt.ended, isTrue);
    play.setValue('v', 20);
    play.setValue('a', 40);
    await t.tap(find.byKey(const ValueKey('lockIn')));
    await t.pump();
    final st = t.state<ChallengeViewState>(find.byType(ChallengeView));
    expect(st.solved, isTrue);
    expect(st.stars, 2);
    await t.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('timeScrub')), findsOneWidget);
  });

  final all = contentScenes();
  test('content has the showcase scenes and activities', () {
    final kinds = {for (final (_, b) in all) b.type == BlockType.activity ? b.raw['kind'] : b.raw['kind']};
    expect(kinds, containsAll(['scene', 'sort', 'order', 'match', 'fill']));
    expect(all.length, greaterThanOrEqualTo(14));
  });

  for (final (name, size, scale) in const [('phone portrait', Size(390, 844), 0.5), ('phone landscape', Size(844, 390), 0.5), ('board classroom', Size(1920, 1080), 1.0)]) {
    testWidgets('every content scene and activity fits: $name', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final problems = <String>[];
      var where = '';
      final old = FlutterError.onError;
      FlutterError.onError = (e) => problems.add('$where: ${e.exceptionAsString().split('\n').first}');
      for (final (w, b) in all) {
        where = w;
        final Widget view = switch (b.type) {
          BlockType.activity => ActivityView(block: b, lang: Lang.en),
          BlockType.challenge => ChallengeView(block: b, lang: Lang.en, room: ClassRoom(rollCount: 40), game: GameStore()),
          _ => InteractiveView(block: b, lang: Lang.en),
        };
        await t.pumpWidget(app(view, scale: scale));
        await t.pump(const Duration(milliseconds: 100));
        // Kannada too, and the finished state of activities (feedback and explanation).
        if (b.type == BlockType.activity) {
          t.state<ActivityViewState>(find.byType(ActivityView)).showAnswer();
          await t.pump();
        }
        if (b.type == BlockType.challenge) {
          t.state<ChallengeViewState>(find.byType(ChallengeView)).giveUp();
          await t.pump();
          await t.pump();
        }
        await t.pumpWidget(
          app(switch (b.type) {
            BlockType.activity => ActivityView(block: b, lang: Lang.kn),
            BlockType.challenge => ChallengeView(block: b, lang: Lang.kn, room: ClassRoom(rollCount: 40), game: GameStore()),
            _ => InteractiveView(block: b, lang: Lang.kn),
          }, scale: scale),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.pumpWidget(const SizedBox());
      FlutterError.onError = old;
      expect(problems.toSet().toList(), isEmpty);
    });
  }
}
