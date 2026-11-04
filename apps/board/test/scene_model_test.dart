// The playfield model (lib/blocks/scene/play_model.dart): the same numbers as the pack
// builder's reference (tools/pack-builder/src/sim.ts) on the showcase blocks, and the runtime's
// play, pause, step, seek, loop, stopWhen, buttons, handles and trails.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/challenge_view.dart';
import 'package:zynetix_board/blocks/scene/play_model.dart';
import 'package:zynetix_board/engine/expr.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/period.dart';

Map<String, dynamic> contentBlock(String lesson, String id) =>
    ((jsonDecode(File('../../content/packs/$lesson').readAsStringSync())['blocks'] as List).cast<Map<String, dynamic>>()).firstWhere((b) => b['id'] == id);

Map<String, dynamic> projectileRaw({String? stopWhen = 'landed', bool loop = false}) => {
  'id': 'p',
  'type': 'interactive',
  'kind': 'scene',
  'sliders': [
    {'name': 'v', 'label': {'en': 'v'}, 'min': 5, 'max': 25, 'step': 1, 'value': 15},
    {'name': 'a', 'label': {'en': 'a'}, 'min': 10, 'max': 80, 'step': 1, 'value': 45},
  ],
  'toggles': [
    {'name': 'vec', 'label': {'en': 'vec'}, 'value': true},
  ],
  'counters': [
    {'name': 'n', 'value': 0, 'min': 0, 'max': 3},
  ],
  'buttons': [
    {'label': {'en': 'Launch'}, 'reset': true, 'play': true},
    {'label': {'en': 'Add'}, 'set': {'n': 'n + 1'}},
    {'label': {'en': 'Fast'}, 'set': {'v': 'v + 2.4'}},
  ],
  'time': {'max': 6, 'stopWhen': ?stopWhen, 'loop': loop},
  'vars': [
    {'name': 'px', 'expr': 'v*cos(rad(a))*t'},
    {'name': 'yraw', 'expr': 'v*sin(rad(a))*t - 4.9*t^2'},
    {'name': 'py', 'expr': 'max(yraw, 0)'},
    {'name': 'landed', 'expr': 't > 0 && yraw <= 0'},
  ],
  'view': {
    'x': [0, 65],
    'y': [0, 33],
  },
  'shapes': [
    {'shape': 'trail', 'x': 'px', 'y': 'py'},
    {'shape': 'circle', 'x': 'px', 'y': 'py', 'r': 1},
  ],
};

void main() {
  group('PlayModel matches the reference', () {
    test('the launch challenge lands at the same place and time', () {
      final b = Block.fromJson(contentBlock('puc1-physics-motion-in-a-plane/lessons/t4.json', 'challenge-launch'))!;
      final m = PlayModel(b.raw);
      final e = m.run({...m.defaults(), 'v': 20, 'a': 40});
      // tools/pack-builder: px 40.29393770805824 at t 2.63.
      expect(e['px'], closeTo(40.29393770805824, 1e-9));
      expect(e['t'], closeTo(2.63, 1e-9));
      final s = ChallengeSpec.of(b);
      expect(s.hits(s.value(s.solution)), isTrue);
      expect(s.hits(s.value({'v': 15, 'a': 30})), isFalse);
    });

    test('the RK2 pendulum keeps its energy; RC reaches 63% at one time constant', () {
      final p = PlayModel(contentBlock('puc1-physics-oscillations/lessons/t5.json', 'scene-pendulum'));
      final e = p.run(p.defaults());
      expect((e['KE']! + e['PE']!) / e['E0']!, closeTo(1.0000242893286209, 1e-9));
      expect(e['th'], closeTo(0.5235199631208838, 1e-9));
      final rc = PlayModel(contentBlock('puc2-physics-electrostatic-potential-and-capacitance/lessons/t4.json', 'scene-rc'));
      var s = rc.initState(rc.defaults());
      for (var k = 0; k < (2 / rc.dt).round(); k++) {
        s = rc.step(rc.defaults(), k, s);
      }
      expect(s['Vc']! / 6, closeTo(0.632114381283808, 1e-9));
    });

    test('Euler and RK2 differ; a small-angle pendulum swings with T = 2π√(L/g)', () {
      Map<String, dynamic> raw(String integrator) => {
        'sliders': [
          {'name': 'L', 'label': {'en': 'L'}, 'min': 0.5, 'max': 2, 'step': 0.1, 'value': 1},
        ],
        'time': {'max': 4, 'dt': 0.001},
        'integrator': integrator,
        'state': [
          {'name': 'th', 'init': 0.05, 'rate': 'w'},
          {'name': 'w', 'init': 0, 'rate': '-9.8/L*sin(th)'},
        ],
      };
      final m = PlayModel(raw('rk2'));
      final period = 2 * math.pi * math.sqrt(1 / 9.8);
      var s = m.initState(m.defaults());
      for (var k = 0; (k + 1) * m.dt <= period; k++) {
        s = m.step(m.defaults(), k, s);
      }
      expect(s['th'], closeTo(0.05, 1e-3));
      final eu = PlayModel(raw('euler'));
      expect((eu.run(eu.defaults())['th']! - m.run(m.defaults())['th']!).abs(), greaterThan(1e-4));
    });

    test('names: controls, handles, t, state and vars, in order', () {
      final m = PlayModel({
        ...projectileRaw(),
        'handles': [
          {'name': 'P', 'x': 1, 'y': 2},
        ],
      });
      expect(m.names, ['v', 'a', 'vec', 'n', 'P_x', 'P_y', 't', 'px', 'yraw', 'py', 'landed']);
      expect(m.defaults(), {'v': 15, 'a': 45, 'vec': 1, 'n': 0, 'P_x': 1, 'P_y': 2});
      expect(tryCompileExpr('P_x + t', m.names), isNotNull);
    });
  });

  group('PlayRuntime', () {
    test('plays, pauses, steps, stops when landed and resets', () {
      final rt = PlayRuntime(PlayModel(projectileRaw()));
      expect(rt.playing, isFalse);
      rt.tick(1);
      expect(rt.t, 0, reason: 'paused: time does not move');
      rt.play();
      for (var i = 0; i < 30; i++) {
        rt.tick(1 / 60);
      }
      expect(rt.t, closeTo(0.5, 1e-9));
      expect(rt.env['px'], closeTo(15 * math.cos(math.pi / 4) * 0.5, 1e-9));
      rt.pause();
      rt.stepOnce();
      expect(rt.t, closeTo(0.5 + 1 / 60, 1e-9));
      // Flight time 2·15·sin45°/9.8 ≈ 2.165 s: it stops there, on a dt step.
      rt.play();
      for (var i = 0; i < 400; i++) {
        rt.tick(1 / 60);
      }
      expect(rt.ended, isTrue);
      expect(rt.playing, isFalse);
      expect(rt.t, closeTo(2.17, 1e-9));
      expect(rt.trails.single.points.length, greaterThan(100));
      rt.reset();
      expect(rt.t, 0);
      expect(rt.trails.single.points.length, 1);
      // Play after the end starts again.
      for (var i = 0; i < 300; i++) {
        rt.tick(1 / 60);
      }
      rt.play();
      expect(rt.playing, isTrue);
    });

    test('speed scales time; a long frame is cut to 0.1 s; loop starts again at the end', () {
      final rt = PlayRuntime(PlayModel(projectileRaw(stopWhen: null, loop: true)));
      rt.setSpeed(4);
      rt.play();
      rt.tick(0.05);
      expect(rt.t, closeTo(0.2, 1e-9));
      rt.tick(5);
      expect(rt.t, closeTo(0.6, 1e-9));
      for (var i = 0; i < 20; i++) {
        rt.tick(0.1);
      }
      expect(rt.t, lessThan(6));
      expect(rt.playing, isTrue);
    });

    test('seek runs the model again; buttons set counters and sliders within their limits', () {
      final rt = PlayRuntime(PlayModel(projectileRaw()));
      rt.seek(1);
      expect(rt.t, 1);
      expect(rt.env['py'], closeTo(15 * math.sin(math.pi / 4) - 4.9, 1e-9));
      expect(rt.trails.single.points.length, greaterThan(50));
      final add = rt.model.buttons[1], fast = rt.model.buttons[2], launch = rt.model.buttons[0];
      for (var i = 0; i < 5; i++) {
        rt.press(add);
      }
      expect(rt.controls['n'], 3, reason: 'a counter stops at its max');
      rt.press(fast);
      expect(rt.controls['v'], 17, reason: 'a slider snaps to its step');
      rt.press(launch);
      expect(rt.t, 0);
      expect(rt.playing, isTrue);
    });

    test('a stateful model integrates while playing and seeks deterministically', () {
      final m = PlayModel(contentBlock('puc1-physics-oscillations/lessons/t5.json', 'scene-pendulum'));
      final rt = PlayRuntime(m)..play();
      for (var i = 0; i < 120; i++) {
        rt.tick(1 / 60);
      }
      final th = rt.state['th']!;
      expect(rt.t, closeTo(2, 0.01));
      final again = PlayRuntime(m)..seek(rt.t);
      expect(again.state['th'], closeTo(th, 1e-9));
      // Changing the release angle before playing restarts the state from it.
      final fresh = PlayRuntime(m)..setControl('th0', 60);
      expect(fresh.state['th'], closeTo(math.pi / 3, 1e-12));
    });

    test('handles stay on their axis, line or box and snap', () {
      final h = HandleSpec(name: 'D', x: 40, y: 12, axis: 'x', box: (15, 65, 0, 25), snap: 1);
      expect(h.constrain(70.4, 3, (0, 100, 0, 25)), (65, 12));
      expect(h.constrain(30.4, 3, (0, 100, 0, 25)), (30, 12));
      final onLine = HandleSpec(name: 'P', x: 0, y: 0, line: (0, 0, 10, 10));
      expect(onLine.constrain(10, 0, (0, 20, 0, 20)), (5, 5));
      expect(onLine.constrain(30, 30, (0, 20, 0, 20)), (10, 10));
      final rt = PlayRuntime(
        PlayModel({
          'kind': 'scene',
          'handles': [
            {'name': 'O', 'x': -25, 'y': 4, 'box': {'x': [-45, -3], 'y': [1, 8]}},
          ],
          'view': {
            'x': [-50, 60],
            'y': [-22, 14],
          },
        }),
      );
      rt.dragHandle(rt.model.handles.single, -1, 20);
      expect((rt.controls['O_x'], rt.controls['O_y']), (-3, 8));
    });
  });

  test('the period planner budgets timed scenes and activities', () {
    final scene = Block.fromJson(contentBlock('puc1-physics-motion-in-a-plane/lessons/t4.json', 'scene-projectile'))!;
    expect(PeriodPlanner.estimate(scene), greaterThanOrEqualTo(120));
    final wave = Block.fromJson(contentBlock('puc1-physics-waves/lessons/t3.json', 'scene-wave'))!;
    expect(PeriodPlanner.interactiveSeconds(wave), 60 + 24);
    final sort = Block.fromJson(contentBlock('puc1-accountancy-introduction-to-accounting/lessons/t5.json', 'activity-sort-alc'))!;
    expect(PeriodPlanner.activitySeconds(sort), PeriodPlanner.readingSeconds(sort.maybe('prompt')) + 10 * 8 + 20);
    expect(PeriodPlanner.phaseOf(sort), Phase.lesson);
  });
}
