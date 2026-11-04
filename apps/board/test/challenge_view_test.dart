import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/challenge_view.dart';
import 'package:zynetix_board/blocks/interactive_view.dart';
import 'package:zynetix_board/core/theme.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/period.dart';
import 'package:zynetix_board/features/game/game_store.dart';
import 'package:zynetix_board/features/participation.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/main.dart';

import 'helpers.dart';

/// Land a projectile on x = 40 m (R = v² sin 2θ / g).
Block challengeBlock({String mode = 'team', int? timeLimit, int attempts = 3}) => Block(BlockType.challenge, {
  'id': 'ch1',
  'type': 'challenge',
  'kind': 'function_plot',
  'prompt': {'en': r'Set speed and angle so the ball lands on $x = 40$ m.'},
  'sliders': [
    {'name': 'v', 'label': {'en': 'Speed'}, 'min': 10, 'max': 30, 'step': 1, 'value': 15, 'unit': 'm/s'},
    {'name': 'a', 'label': {'en': 'Angle'}, 'min': 10, 'max': 80, 'step': 1, 'value': 30, 'unit': '°'},
  ],
  'fns': [
    {'fn': 'x*tan(a*pi/180) - 9.8*x^2/(2*v^2*cos(a*pi/180)^2)', 'color': 'yellow'},
  ],
  'x': [0, 60],
  'y': [0, 30],
  'goal': 'v^2*sin(2*a*pi/180)/9.8',
  'goalLabel': {'en': 'Landing point'},
  'goalUnit': 'm',
  'target': 40,
  'tolerance': 1,
  'solution': {'v': 20, 'a': 40},
  'attempts': attempts,
  'timeLimit': ?timeLimit,
  'mode': mode,
  'hint': {'en': 'Range is largest at 45°.'},
  'explanation': {'en': r'$R = v^2 \sin 2\theta / g$: with 20 m/s at 40°, R = 400 × 0.985 / 9.8 ≈ 40.2 m.'},
});

Future<ChallengeViewState> pumpChallenge(WidgetTester t, Block b, {required GameStore game, required ClassRoom room, Size size = const Size(1920, 1080)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: zynetixTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: ChallengeView(block: b, lang: Lang.en, room: room, game: game),
        ),
      ),
    ),
  );
  await t.pump();
  return t.state<ChallengeViewState>(find.byType(ChallengeView));
}

void setSliders(WidgetTester t, Map<String, double> v) {
  final st = t.state<InteractiveViewState>(find.byType(InteractiveView));
  for (final e in v.entries) {
    st.setValue(e.key, e.value);
  }
}

void main() {
  group('ChallengeSpec', () {
    test('computes the goal, hits within tolerance, and gives 3-2-1 stars', () {
      final s = ChallengeSpec.of(challengeBlock());
      expect(s.value(s.solution), closeTo(40.2, 0.05));
      expect(s.hits(s.value(s.solution)), isTrue);
      expect(s.hits(s.value({'v': 15, 'a': 30})), isFalse);
      expect([1, 2, 3, 4].map(ChallengeSpec.starsFor), [3, 2, 1, 1]);
      expect(s.mode, QuizMode.team);
      expect(s.format(40.19), '40.2 m');
    });
    test('the period planner budgets each try', () {
      expect(PeriodPlanner.estimate(challengeBlock(timeLimit: 30)), greaterThanOrEqualTo(3 * 30 + 20));
      expect(PeriodPlanner.estimate(challengeBlock()), greaterThanOrEqualTo(3 * 45 + 20));
    });
  });

  testWidgets('teams take turns; a hit on the 2nd try earns 2 stars for that team', (t) async {
    final game = GameStore(), room = ClassRoom(rollCount: 40);
    final st = await pumpChallenge(t, challengeBlock(), game: game, room: room);
    expect(find.textContaining('Turn: Team 1'), findsOneWidget);
    // Nothing gives the goal away before locking in.
    expect(find.textContaining('40.2'), findsNothing);
    await t.tap(find.byKey(const ValueKey('lockIn')));
    await t.pump();
    expect(find.textContaining('Too low'), findsOneWidget);
    expect(find.textContaining('Hint'), findsOneWidget);
    expect(find.textContaining('Turn: Team 2'), findsOneWidget);
    setSliders(t, {'v': 20, 'a': 40});
    await t.pump();
    await t.tap(find.byKey(const ValueKey('lockIn')));
    await t.pump(const Duration(milliseconds: 600));
    expect(st.solved, isTrue);
    expect(st.stars, 2);
    expect(room.scores[1], 2);
    expect(game.challenges.single.stars, 2);
    expect(game.challenges.single.team, 1);
    expect(find.byKey(const ValueKey('result')), findsOneWidget);
    await t.pumpAndSettle();
    // Play again starts fresh.
    await t.tap(find.byKey(const ValueKey('playAgain')));
    await t.pump();
    expect(st.over, isFalse);
    expect(st.tries, isEmpty);
  });

  testWidgets('out of tries: no stars, the solution is shown on the playfield', (t) async {
    final game = GameStore(), room = ClassRoom(rollCount: 40);
    final st = await pumpChallenge(t, challengeBlock(mode: 'monitor', attempts: 2), game: game, room: room);
    for (var i = 0; i < 2; i++) {
      await t.tap(find.byKey(const ValueKey('lockIn')));
      await t.pump();
    }
    await t.pump();
    expect(st.over, isTrue);
    expect(st.stars, 0);
    expect(game.challenges.single.solved, isFalse);
    expect(t.state<InteractiveViewState>(find.byType(InteractiveView)).values, {'v': 20.0, 'a': 40.0});
    expect(find.textContaining('Out of tries'), findsOneWidget);
  });

  testWidgets('roll call names a roll number; the timer loses a try', (t) async {
    final game = GameStore(), room = ClassRoom(rollCount: 40);
    final st = await pumpChallenge(t, challengeBlock(mode: 'roll_call', timeLimit: 15), game: game, room: room);
    expect(st.roll, isNotNull);
    expect(find.textContaining('Turn: Roll No. ${st.roll}'), findsOneWidget);
    await t.pump(const Duration(seconds: 16));
    expect(st.tries.length, 1);
    expect(st.tries.single.value, isNull);
    expect(find.textContaining('Time up'), findsOneWidget);
    final second = st.roll;
    setSliders(t, {'v': 20, 'a': 40});
    await t.tap(find.byKey(const ValueKey('lockIn')));
    await t.pump();
    expect(game.challenges.single.roll, second);
    expect(game.challenges.single.stars, 2);
    await t.pumpAndSettle();
  });

  testWidgets('Self-Learning: the whole class plays on a timer and the solution shows by itself', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = GameStore();
    var finished = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: zynetixTheme(),
        home: Scaffold(
          body: ChallengeView(block: challengeBlock(), lang: Lang.en, room: ClassRoom(rollCount: 40), game: game, auto: true, onFinished: () => finished++),
        ),
      ),
    );
    final st = t.state<ChallengeViewState>(find.byType(ChallengeView));
    expect(st.mode, QuizMode.monitor);
    expect(find.byKey(const ValueKey('giveUp')), findsNothing);
    for (var i = 0; i < 3 * 45 + 2; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(st.over, isTrue);
    expect(finished, 1);
    expect(game.challenges.single.solved, isFalse);
  });

  testWidgets('a challenge in a lesson fits phone and board screens', (t) async {
    final s = await testServices(prefs: {'displaySize': 'normal'});
    final hit = s.lessonFor('puc1-physics-02-motion-in-a-straight-line.t1')!;
    final lesson = Lesson(id: hit.lesson.id, chapterId: hit.lesson.chapterId, topicId: hit.lesson.topicId, title: hit.lesson.title, minutes: 40, blocks: [challengeBlock(), ...hit.lesson.blocks]);
    for (final (size, display) in const [(Size(390, 844), 'normal'), (Size(844, 390), 'normal'), (Size(1920, 1080), 'classroom')]) {
      await s.config.setDisplaySize(display);
      final problems = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (e) => problems.add('$size: ${e.exceptionAsString().split('\n').first}');
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(ZynetixBoardApp(key: UniqueKey(), services: s, home: LessonPlayerScreen(pack: hit.pack, lesson: lesson)));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(ChallengeView), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('lockIn')));
      await t.pump(const Duration(milliseconds: 300));
      setSliders(t, {'v': 20, 'a': 40});
      await t.tap(find.byKey(const ValueKey('lockIn')));
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      FlutterError.onError = old;
      expect(problems, isEmpty);
    }
    await t.pumpWidget(const SizedBox());
    t.view.reset();
  });
}
