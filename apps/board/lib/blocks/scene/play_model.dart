import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../engine/expr.dart';
import '../../engine/model.dart';

/// The playfield model of interactives, challenges and scenes, mirrored from
/// tools/pack-builder/src/sim.ts (the reference the validator runs): controls → derived vars →
/// integrated state over time. Pure, so it is unit-tested; [PlayRuntime] plays it on screen.
///
/// Each time step (fixed `dt`): vars are evaluated in order with the controls, `t` and the state;
/// the state moves by its rates (Euler: k1·dt; RK2 midpoint: k2·dt with k2 at t + dt/2), then t
/// becomes min + steps·dt. `stopWhen` is checked after each step.
typedef Vars = Map<String, double>;

enum ControlKind { slider, toggle, choice, counter, handle }

class Control {
  Control(this.name, this.kind, this.value, {this.min, this.max, this.values});
  final String name;
  final ControlKind kind;
  final double value;
  final double? min, max;
  final List<double>? values;
}

double _n(Object? v, double d) => (v as num?)?.toDouble() ?? d;
List<Map<String, dynamic>> _maps(Object? v) => [
  for (final e in (v as List?) ?? const [])
    if (e is Map) e.cast<String, dynamic>(),
];

/// A slider of an interactive block.
class SliderSpec {
  SliderSpec({required this.name, required this.label, required this.min, required this.max, required this.step, required this.value, this.unit});
  final String name;
  final L10n label;
  final double min, max, step, value;
  final String? unit;

  factory SliderSpec.fromJson(Map<String, dynamic> j) {
    final min = _n(j['min'], 0), max = math.max(_n(j['max'], 10), min + 1e-9);
    return SliderSpec(name: j['name'] as String? ?? 'a', label: L10n.of(j['label']), min: min, max: max, step: _n(j['step'], 1), value: _n(j['value'], min).clamp(min, max), unit: j['unit'] as String?);
  }
}

class ToggleSpec {
  ToggleSpec(this.name, this.label, this.value);
  final String name;
  final L10n label;
  final bool value;
}

class ChoiceSpec {
  ChoiceSpec(this.name, this.label, this.options, this.value);
  final String name;
  final L10n label;
  final List<(L10n, double)> options;
  final double value;
}

class CounterSpec {
  CounterSpec(this.name, this.value, this.min, this.max);
  final String name;
  final double value;
  final double? min, max;
}

class ButtonSpec {
  ButtonSpec(this.label, this.icon, this.set, this.reset, this.play);
  final L10n label;
  final String? icon;
  final Map<String, Object> set;
  final bool reset, play;
}

/// A draggable point: its position is `<name>_x`, `<name>_y`.
class HandleSpec {
  HandleSpec({required this.name, this.label, required this.x, required this.y, this.axis, this.line, this.box, this.snap, this.color});
  final String name;
  final String? label;
  final double x, y;
  final String? axis;
  final (double, double, double, double)? line;
  final (double, double, double, double)? box; // x0, x1, y0, y1
  final double? snap;
  final String? color;
  String get xName => '${name}_x';
  String get yName => '${name}_y';

  /// Where a drag to (wx, wy) actually puts the handle: on its axis or line, inside its box, snapped.
  (double, double) constrain(double wx, double wy, (double, double, double, double) view) {
    var x = wx, y = wy;
    if (axis == 'x') y = this.y;
    if (axis == 'y') x = this.x;
    final l = line;
    if (l != null) {
      final (x1, y1, x2, y2) = l;
      final dx = x2 - x1, dy = y2 - y1, len2 = dx * dx + dy * dy;
      final k = len2 == 0 ? 0.0 : (((x - x1) * dx + (y - y1) * dy) / len2).clamp(0.0, 1.0);
      x = x1 + k * dx;
      y = y1 + k * dy;
    }
    final s = snap;
    if (s != null) {
      x = (x / s).roundToDouble() * s;
      y = (y / s).roundToDouble() * s;
    }
    final b = box ?? view;
    return (x.clamp(math.min(b.$1, b.$2), math.max(b.$1, b.$2)), y.clamp(math.min(b.$3, b.$4), math.max(b.$3, b.$4)));
  }
}

class PlayModel {
  PlayModel(this.raw) {
    sliders = [for (final s in _maps(raw['sliders'])) SliderSpec.fromJson(s)];
    toggles = [for (final s in _maps(raw['toggles'])) ToggleSpec(s['name'] as String? ?? 'on', L10n.of(s['label']), s['value'] == true)];
    choices = [
      for (final s in _maps(raw['choices']))
        ChoiceSpec(s['name'] as String? ?? 'c', L10n.of(s['label']), [for (final o in _maps(s['options'])) (L10n.of(o['label']), _n(o['value'], 0))], _n(s['value'], 0)),
    ];
    counters = [for (final s in _maps(raw['counters'])) CounterSpec(s['name'] as String? ?? 'n', _n(s['value'], 0), (s['min'] as num?)?.toDouble(), (s['max'] as num?)?.toDouble())];
    buttons = [
      for (final s in _maps(raw['buttons']))
        ButtonSpec(L10n.of(s['label']), s['icon'] as String?, {for (final e in ((s['set'] as Map?) ?? const {}).entries) e.key as String: e.value as Object}, s['reset'] == true, s['play'] == true),
    ];
    List<double>? pair(Object? v) => v is List && v.length == 2 && v[0] is num && v[1] is num ? [(v[0] as num).toDouble(), (v[1] as num).toDouble()] : null;
    handles = [
      for (final h in _maps(raw['handles']))
        HandleSpec(
          name: h['name'] as String? ?? 'P',
          label: h['label'] as String?,
          x: _n(h['x'], 0),
          y: _n(h['y'], 0),
          axis: h['axis'] as String?,
          line: switch (h['line']) {
            [final a, final b] when pair(a) != null && pair(b) != null => (pair(a)![0], pair(a)![1], pair(b)![0], pair(b)![1]),
            _ => null,
          },
          box: switch (h['box']) {
            {'x': final bx, 'y': final by} when pair(bx) != null && pair(by) != null => (pair(bx)![0], pair(bx)![1], pair(by)![0], pair(by)![1]),
            _ => null,
          },
          snap: (h['snap'] as num?)?.toDouble(),
          color: h['color'] as String?,
        ),
    ];
    controls = [
      for (final s in sliders) Control(s.name, ControlKind.slider, s.value, min: s.min, max: s.max),
      for (final s in toggles) Control(s.name, ControlKind.toggle, s.value ? 1 : 0, values: const [0, 1]),
      for (final s in choices) Control(s.name, ControlKind.choice, s.value, values: [for (final o in s.options) o.$2]),
      for (final s in counters) Control(s.name, ControlKind.counter, s.value, min: s.min, max: s.max),
      for (final h in handles) ...[Control(h.xName, ControlKind.handle, h.x), Control(h.yName, ControlKind.handle, h.y)],
    ];
    final time = raw['time'];
    hasTime = time is Map;
    if (time is Map) {
      min = _n(time['min'], 0);
      max = math.max(_n(time['max'], min + 10), min + 1e-6);
      loop = time['loop'] == true;
      speeds = [for (final s in (time['speeds'] as List?) ?? const [0.25, 0.5, 1, 2, 4]) (s as num).toDouble()];
      if (speeds.isEmpty) speeds = [1];
      speed = _n(time['speed'], 1);
      autoplay = time['autoplay'] == true;
      dt = _n(time['dt'], 0.01).clamp(1e-4, 0.5);
      unit = time['unit'] as String? ?? 's';
    }
    rk2 = raw['integrator'] != 'euler';
    final control = [for (final c in controls) c.name];
    final stateNames = [for (final s in _maps(raw['state'])) s['name'] as String? ?? 's'];
    final base = [...control, if (hasTime) 't', ...stateNames];
    for (final v in _maps(raw['vars'])) {
      final name = v['name'] as String? ?? 'v';
      _vars.add((name, tryCompileExpr(v['expr'] as String? ?? '', List.of(base))));
      base.add(name);
    }
    names = base;
    if (hasTime) {
      for (final s in _maps(raw['state'])) {
        final init = s['init'];
        _state.add((
          s['name'] as String? ?? 's',
          init is num ? (_) => init.toDouble() : tryCompileExpr(init as String? ?? '0', control),
          tryCompileExpr(s['rate'] as String? ?? '0', names),
        ));
      }
      final sw = time is Map ? time['stopWhen'] : null;
      if (sw is String) _stop = tryCompileExpr(sw, names);
    }
  }

  final Map<String, dynamic> raw;
  late final List<SliderSpec> sliders;
  late final List<ToggleSpec> toggles;
  late final List<ChoiceSpec> choices;
  late final List<CounterSpec> counters;
  late final List<ButtonSpec> buttons;
  late final List<HandleSpec> handles;
  late final List<Control> controls;
  late final bool hasTime;
  double min = 0, max = 0, dt = 0.01, speed = 1;
  bool loop = false, autoplay = false;
  List<double> speeds = const [1];
  String unit = 's';
  late final bool rk2;

  /// Controls, t, state and vars: the names every expression of the block may use.
  late final List<String> names;
  final _vars = <(String, Expr?)>[];
  final _state = <(String, Expr?, Expr?)>[];
  Expr? _stop;

  bool get hasState => _state.isNotEmpty;
  List<String> get stateNames => [for (final s in _state) s.$1];

  Vars defaults() => {for (final c in controls) c.name: c.value};

  /// Controls + t + state + vars.
  Vars env(Vars controls, double t, Vars state) {
    final e = <String, double>{...controls, ...state};
    if (hasTime) e['t'] = t;
    for (final (name, f) in _vars) {
      e[name] = f?.call(e) ?? double.nan;
    }
    return e;
  }

  Vars initState(Vars controls) => {for (final (name, init, _) in _state) name: init?.call(controls) ?? double.nan};

  Vars _rates(Vars controls, double t, Vars s) {
    final e = env(controls, t, s);
    return {for (final (name, _, rate) in _state) name: rate?.call(e) ?? double.nan};
  }

  /// One fixed step from [steps] steps after min.
  Vars step(Vars controls, int steps, Vars s) {
    if (_state.isEmpty) return s;
    final t = min + steps * dt;
    final k1 = _rates(controls, t, s);
    if (!rk2) return {for (final (n, _, _) in _state) n: s[n]! + k1[n]! * dt};
    final mid = {for (final (n, _, _) in _state) n: s[n]! + k1[n]! * dt / 2};
    final k2 = _rates(controls, t + dt / 2, mid);
    return {for (final (n, _, _) in _state) n: s[n]! + k2[n]! * dt};
  }

  bool stopped(Vars e) {
    final v = _stop?.call(e);
    return v != null && v != 0 && !v.isNaN;
  }

  int get totalSteps => hasTime ? ((max - min) / dt).round() : 0;

  /// Runs from the start with these controls until stopWhen or the end of time; the final env.
  Vars run(Vars controls) {
    var s = initState(controls);
    var e = env(controls, min, s);
    final n = totalSteps;
    for (var k = 0; k < n; k++) {
      s = step(controls, k, s);
      e = env(controls, min + (k + 1) * dt, s);
      if (stopped(e)) break;
    }
    return e;
  }

  /// The value of [goal] for these controls: where the model stops when there is time, else now.
  double outcome(Expr goal, Vars controls) {
    final c = {...defaults(), ...controls};
    return goal(hasTime ? run(c) : env(c, min, initState(c)));
  }

  /// The view of a scene as (x0, x1, y0, y1), or the plot ranges of other kinds.
  (double, double, double, double) get view {
    final v = raw['view'];
    List<double> r(Object? x, List<double> d) => x is List && x.length == 2 ? [(x[0] as num).toDouble(), (x[1] as num).toDouble()] : d;
    final xr = r(v is Map ? v['x'] : raw['x'], [0, 10]), yr = r(v is Map ? v['y'] : raw['y'], [0, 10]);
    return (xr[0], xr[1], yr[0], yr[1]);
  }
}

/// A trail shape: the past positions of a point, recorded while time runs.
class TrailSource {
  TrailSource(this.x, this.y, this.length);
  final Expr? x, y;
  final int length;
  final points = <(double, double)>[];
}

/// Plays a [PlayModel] on screen: control values, time (play, pause, speed, step, seek, loop,
/// stopWhen), the integrated state, trails, and buttons. Listeners repaint the scene.
class PlayRuntime extends ChangeNotifier {
  PlayRuntime(this.model) : controls = model.defaults(), speed = model.speed {
    for (final sh in _maps(model.raw['shapes'])) {
      if (sh['shape'] == 'trail') {
        Expr? c(Object? v) => v is num ? (_) => v.toDouble() : tryCompileExpr(v as String? ?? '', model.names);
        trails.add(TrailSource(c(sh['x']), c(sh['y']), (sh['length'] as num?)?.toInt() ?? 300));
      }
    }
    reset();
    playing = model.hasTime && model.autoplay;
  }

  final PlayModel model;

  /// Sliders, toggles, choices, counters and handle coordinates, by name.
  final Vars controls;
  double t = 0;
  int steps = 0;
  double _acc = 0;
  Vars state = {};

  /// Controls + t + state + vars, as now.
  Vars env = {};
  bool playing = false;
  double speed;

  /// Set when time reached its end or stopWhen came true (cleared by reset and seek).
  bool ended = false;
  final trails = <TrailSource>[];

  void _update({bool record = false}) {
    env = model.env(controls, t, state);
    if (record) {
      for (final tr in trails) {
        final x = tr.x?.call(env) ?? double.nan, y = tr.y?.call(env) ?? double.nan;
        if (!x.isFinite || !y.isFinite) continue;
        tr.points.add((x, y));
        if (tr.points.length > tr.length) tr.points.removeAt(0);
      }
    }
  }

  /// Back to the start of time: the state from its initial values, trails cleared.
  void reset({bool notify = true}) {
    t = model.min;
    steps = 0;
    _acc = 0;
    ended = false;
    state = model.initState(controls);
    for (final tr in trails) {
      tr.points.clear();
    }
    _update(record: true);
    if (notify) notifyListeners();
  }

  void setControl(String name, double v) {
    controls[name] = v;
    // With no time the state is just its initial value, which may depend on the controls.
    if (!model.hasTime) state = model.initState(controls);
    if (!playing && steps == 0 && t == model.min && model.hasState) state = model.initState(controls);
    _update();
    notifyListeners();
  }

  void dragHandle(HandleSpec h, double wx, double wy) {
    final (x, y) = h.constrain(wx, wy, model.view);
    controls[h.xName] = x;
    controls[h.yName] = y;
    _update();
    notifyListeners();
  }

  void play() {
    if (!model.hasTime) return;
    if (ended) reset(notify: false);
    playing = true;
    notifyListeners();
  }

  void pause() {
    playing = false;
    notifyListeners();
  }

  void toggle() => playing ? pause() : play();

  void setSpeed(double s) {
    speed = s;
    notifyListeners();
  }

  /// Advances by [realSeconds] of wall time at the chosen speed (called each frame).
  void tick(double realSeconds) {
    if (!playing || !model.hasTime) return;
    _advance(math.min(realSeconds, 0.1) * speed);
    notifyListeners();
  }

  /// One step forward: a 1/60 s frame at 1×, at least one integrator step.
  void stepOnce() {
    if (!model.hasTime) return;
    if (ended) return;
    playing = false;
    _advance(math.max(model.dt, 1 / 60));
    notifyListeners();
  }

  void _advance(double sim) {
    if (!model.hasState) {
      // A closed form: time is continuous, so slow motion stays smooth.
      final steps0 = ((t - model.min) / model.dt).floor();
      t += sim;
      if (t >= model.max) {
        if (model.loop) {
          reset(notify: false);
          return;
        }
        t = model.max;
        _end();
      }
      steps = ((t - model.min) / model.dt).floor();
      // Check stopWhen at each dt crossed, as the reference does.
      for (var k = steps0 + 1; k <= steps && !ended; k++) {
        final at = model.min + k * model.dt;
        if (model.stopped(model.env(controls, at, state))) {
          t = at;
          steps = k;
          _end();
        }
      }
      _update(record: true);
      return;
    }
    _acc += sim;
    final n = model.totalSteps;
    while (_acc >= model.dt - 1e-12 && !ended) {
      _acc -= model.dt;
      state = model.step(controls, steps, state);
      steps++;
      t = model.min + steps * model.dt;
      _update(record: true);
      if (model.stopped(env)) _end();
      if (steps >= n && !ended) {
        if (model.loop) {
          reset(notify: false);
        } else {
          _end();
        }
      }
    }
  }

  void _end() {
    ended = true;
    playing = false;
  }

  /// Jumps to time [to]: the model is run again from the start (it is deterministic).
  void seek(double to) {
    if (!model.hasTime) return;
    final target = to.clamp(model.min, model.max);
    final wasPlaying = playing;
    reset(notify: false);
    playing = false;
    if (!model.hasState) {
      // Rebuild trails by sampling the closed form.
      final n = ((target - model.min) / model.dt).floor();
      final every = math.max(1, n ~/ 400);
      for (var k = 1; k <= n; k += every) {
        t = model.min + k * model.dt;
        _update(record: true);
      }
      t = target;
      _update(record: true);
    } else {
      final n = ((target - model.min) / model.dt).round();
      for (var k = 0; k < n; k++) {
        state = model.step(controls, steps, state);
        steps++;
        t = model.min + steps * model.dt;
        _update(record: true);
      }
    }
    playing = wasPlaying && target < model.max;
    notifyListeners();
  }

  /// A button press: `set` is evaluated with the values before the press; then `reset` rewinds
  /// time (the state starts again from the new controls) and `play` starts it.
  void press(ButtonSpec b) {
    final before = Map.of(env);
    for (final e in b.set.entries) {
      final v = e.value;
      var x = v is num ? v.toDouble() : (tryCompileExpr(v as String, model.names)?.call(before) ?? double.nan);
      if (!x.isFinite) continue;
      final c = model.controls.where((c) => c.name == e.key).firstOrNull;
      if (c == null || c.kind == ControlKind.handle) continue;
      if (c.min != null) x = math.max(x, c.min!);
      if (c.max != null) x = math.min(x, c.max!);
      if (c.kind == ControlKind.toggle) x = x != 0 ? 1 : 0;
      if (c.kind == ControlKind.slider) {
        final s = model.sliders.firstWhere((s) => s.name == c.name);
        x = (s.min + ((x - s.min) / s.step).roundToDouble() * s.step).clamp(s.min, s.max);
      }
      controls[e.key] = x;
    }
    if (b.reset) {
      reset(notify: false);
    } else {
      if (!model.hasTime) state = model.initState(controls);
      _update();
    }
    if (b.play) play();
    notifyListeners();
  }
}
