import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/expr.dart';
import '../engine/model.dart';
import '../engine/session_log.dart';
import '../features/game/game_store.dart';
import '../features/game/strings.dart';
import '../features/participation.dart';
import 'interactive_view.dart';
import 'math_text.dart';
import 'scene/play_model.dart';

/// What a challenge block asks (schema `challenge`): set the sliders so [goal] lands within
/// [tolerance] of [target]. Pure, so it is unit-tested.
class ChallengeSpec {
  ChallengeSpec._(this.block, this.model, this.goal, this.sliderNames);

  factory ChallengeSpec.of(Block b) {
    final model = PlayModel(b.raw);
    return ChallengeSpec._(b, model, tryCompileExpr(b.s('goal') ?? '', model.names), [for (final s in model.sliders) s.name]);
  }

  /// The playfield's model: controls, vars, state and time (a scene challenge runs it to the end).
  final PlayModel model;
  final Block block;
  final Expr? goal;
  final List<String> sliderNames;
  Map<String, dynamic> get raw => block.raw;

  double get target => (raw['target'] as num?)?.toDouble() ?? 0;
  double get tolerance => (raw['tolerance'] as num?)?.toDouble() ?? 0;
  int get attempts => (raw['attempts'] as num?)?.toInt() ?? 3;
  int? get timeLimit => (raw['timeLimit'] as num?)?.toInt();
  QuizMode get mode => switch (raw['mode']) {
    'monitor' => QuizMode.monitor,
    'roll_call' => QuizMode.rollCall,
    _ => QuizMode.team,
  };
  String? get unit => raw['goalUnit'] as String?;
  L10n get prompt => block.f('prompt');
  L10n get goalLabel => block.f('goalLabel');
  L10n? get hint => block.maybe('hint');
  L10n get explanation => block.f('explanation');
  Map<String, double> get solution => {for (final e in ((raw['solution'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble()};

  /// The goal's value for these control settings (NaN when it cannot be computed). With time,
  /// the model runs from the start until stopWhen or the end, and the goal is taken there.
  double value(Map<String, double> controls) {
    final g = goal;
    return g == null ? double.nan : model.outcome(g, controls);
  }
  bool hits(double v) => v.isFinite && (v - target).abs() <= tolerance + 1e-9;

  /// Stars for a hit on the [tryNumber]th try (1-based): 3, 2, then 1.
  static int starsFor(int tryNumber) => tryNumber <= 1 ? 3 : (tryNumber == 2 ? 2 : 1);

  /// Digits that make sense at this tolerance: one more than the tolerance needs.
  int get digits => tolerance >= 1 ? 1 : (-(math.log(tolerance) / math.ln10).floor() + 1).clamp(1, 4);
  String format(double v) => v.isFinite ? '${v.toStringAsFixed(digits)}${unit == null ? '' : ' $unit'}' : '—';
}

/// One try: what the goal came to (null when time ran out), and who played it.
typedef ChallengeTry = ({double? value, bool hit, int? team, int? roll});

/// A challenge block: the interactive playfield (InteractiveView, reused as is), a target, a
/// limited number of tries with stars, an optional timer per try, team turns or a picked roll
/// number, a celebration on a hit, and the solution with its explanation at the end.
class ChallengeView extends StatefulWidget {
  const ChallengeView({super.key, required this.block, required this.lang, required this.room, this.recorder, this.auto = false, this.onFinished, this.game});
  final Block block;
  final Lang lang;
  final ClassRoom room;

  /// Names the lesson, topic and chapter of the results (none in previews).
  final SessionRecorder? recorder;

  /// Self-Learning: the whole class plays, each try is timed, and the solution shows by itself.
  final bool auto;
  final VoidCallback? onFinished;

  /// Where results go; the board's (next to the mastery store) when null.
  final GameStore? game;

  @override
  State<ChallengeView> createState() => ChallengeViewState();
}

class ChallengeViewState extends State<ChallengeView> with SingleTickerProviderStateMixin {
  late final spec = ChallengeSpec.of(widget.block);
  var _playKey = GlobalKey<InteractiveViewState>();
  final tries = <ChallengeTry>[];
  bool solved = false, over = false;
  int? roll;
  int left = 0;
  Timer? _tick;
  late final AnimationController party = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  QuizMode get mode => widget.auto ? QuizMode.monitor : spec.mode;
  int get triesLeft => spec.attempts - tries.length;
  int get team => tries.length % widget.room.teams;
  int? get timeLimit => spec.timeLimit ?? (widget.auto ? 45 : null);
  int get stars => solved ? ChallengeSpec.starsFor(tries.length) : 0;

  /// Stars still on offer for the next try.
  int get onOffer => over ? stars : ChallengeSpec.starsFor(tries.length + 1);

  late final Block _playfield = Block(BlockType.interactive, {...widget.block.raw, 'type': 'interactive', 'caption': widget.block.raw['prompt'], 'tryThis': const []});

  @override
  void initState() {
    super.initState();
    _startTry();
  }

  @override
  void dispose() {
    _tick?.cancel();
    party.dispose();
    super.dispose();
  }

  void _startTry() {
    if (mode == QuizMode.rollCall) roll = widget.room.nextRoll();
    _tick?.cancel();
    final limit = timeLimit;
    if (limit == null) return;
    left = limit;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || over) return;
      setState(() => left--);
      if (left <= 0) _try(null);
    });
  }

  /// The current control settings.
  Map<String, double> get values => Map.of(_playKey.currentState?.values ?? spec.model.defaults());
  List<SliderSpec> get _sliders => [
    for (final s in (widget.block.raw['sliders'] as List?) ?? const [])
      if (s is Map) SliderSpec.fromJson(s.cast<String, dynamic>()),
  ];

  /// Locks in the controls as they are now. A timed playfield also plays the try from the start
  /// (the result is the same model run, computed at once).
  void lockIn() {
    if (spec.model.hasTime) _playKey.currentState?.replay();
    _try(spec.value(values));
  }

  void _try(double? v) {
    if (over) return;
    final hit = v != null && spec.hits(v);
    setState(() {
      tries.add((value: v, hit: hit, team: mode == QuizMode.team ? team : null, roll: mode == QuizMode.rollCall ? roll : null));
      if (hit) {
        solved = true;
        _finish();
        party.forward(from: 0);
      } else if (triesLeft <= 0) {
        _finish();
      } else {
        _startTry();
      }
    });
  }

  /// The teacher shows the solution now (no stars if it was not hit).
  void giveUp() {
    if (over) return;
    setState(_finish);
  }

  void _finish() {
    over = true;
    _tick?.cancel();
    final last = tries.isEmpty ? null : tries.last;
    if (mode == QuizMode.team && solved && last?.team != null) widget.room.scores[last!.team!] += stars;
    final log = widget.recorder?.log;
    final game = widget.game ?? _boardGame();
    game?.recordChallenge(
      ChallengeResult(
        blockId: widget.block.id,
        lessonId: log?['lessonId'] as String? ?? '',
        topicId: log?['topicId'] as String? ?? '',
        chapterId: log?['chapterId'] as String? ?? '',
        stars: stars,
        tries: tries.length,
        solved: solved,
        mode: switch (mode) {
          QuizMode.monitor => 'monitor',
          QuizMode.team => 'team',
          QuizMode.rollCall => 'roll_call',
        },
        roll: solved ? last?.roll : null,
        team: solved ? last?.team : null,
        at: DateTime.now(),
      ),
    );
    // Show the winning settings on the playfield (after this frame: the playfield may be rebuilding).
    final sol = spec.solution;
    if (!solved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final st = _playKey.currentState;
        if (st == null || !st.mounted) return;
        for (final e in sol.entries) {
          st.setValue(e.key, e.value);
        }
      });
    }
    widget.onFinished?.call();
  }

  GameStore? _boardGame() {
    final s = context.getInheritedWidgetOfExactType<ServicesScope>()?.services;
    return s == null ? null : GameStore.of(s.mastery);
  }

  void playAgain() => setState(() {
    tries.clear();
    solved = false;
    over = false;
    party.reset();
    _playKey = GlobalKey<InteractiveViewState>();
    _startTry();
  });

  void _absent() => setState(() {
    if (roll != null) widget.room.absent.add(roll!);
    roll = widget.room.nextRoll();
  });

  String _who(Lang l) => switch (mode) {
    QuizMode.monitor => gt('wholeClass', l),
    QuizMode.team => '${tr('team', l)} ${team + 1}',
    QuizMode.rollCall => '${tr('rollNo', l)} ${roll ?? '—'}',
  };

  @override
  Widget build(BuildContext context) {
    final l = widget.lang, text = Theme.of(context).textTheme;
    final tol = spec.tolerance;
    final targetText = '${gt('target', l)}: ${spec.goalLabel.t(l)} = ${_trim(spec.target)} ± ${_trim(tol)}${spec.unit == null ? '' : ' ${spec.unit}'}';
    final header = Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.sports_esports_outlined, size: 52, color: Z.accent),
        Text(gt('challenge', l), style: text.headlineLarge),
        _Chip(key: const ValueKey('target'), icon: Icons.track_changes, label: targetText, color: Z.accent),
        StarRow(key: const ValueKey('stars'), stars: onOffer, dim: !over),
        if (!over) _Chip(key: const ValueKey('triesLeft'), icon: Icons.replay, label: '$triesLeft ${gt('triesLeft', l)}'),
        if (!over && timeLimit != null) _Chip(key: const ValueKey('timer'), icon: Icons.timer_outlined, label: '${math.max(left, 0)}s', color: left <= 10 ? Z.wrong : null),
        if (!over && mode != QuizMode.monitor)
          _Chip(
            key: const ValueKey('turn'),
            icon: mode == QuizMode.team ? Icons.groups_outlined : Icons.person_outline,
            label: '${gt('turn', l)}: ${_who(l)}',
            color: mode == QuizMode.team ? Z.teamColors[team % Z.teamColors.length] : Z.accent,
          ),
        if (mode == QuizMode.team) for (var t = 0; t < widget.room.teams; t++) Text('${tr('team', l)} ${t + 1}: ${widget.room.scores[t]}', style: text.bodyMedium),
      ],
    );
    final last = tries.isEmpty ? null : tries.last;
    String feedback() {
      if (last == null) return gt('setSliders', l);
      if (last.value == null) return gt('timeUp', l);
      final v = last.value!;
      return '${gt('youGot', l)} ${spec.format(v)}: ${last.hit ? gt('hit', l) : (v > spec.target ? gt('tooHigh', l) : gt('tooLow', l))}';
    }

    final Widget footer;
    if (over) {
      final sol = [for (final e in spec.solution.entries) '${_label(e.key, l)} = ${_trim(e.value)}'].join(', ');
      footer = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(solved ? '${gt('hit', l)} ${feedback()}' : gt('outOfTries', l), key: const ValueKey('result'), style: text.headlineMedium?.copyWith(color: solved ? Z.correct : Z.accent)),
                  const SizedBox(height: 8),
                  MathText('${gt('solution', l)}: $sol', style: text.bodyLarge),
                  const SizedBox(height: 8),
                  MathText('${gt('whyItWorks', l)}: ${spec.explanation.t(l)}', style: text.bodyLarge),
                ],
              ),
            ),
          ),
          const SizedBox(width: Z.gap),
          if (!widget.auto) BigButton(key: const ValueKey('playAgain'), collapse: true, icon: Icons.replay, label: gt('playAgain', l), filled: false, onPressed: playAgain),
        ],
      );
    } else {
      footer = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(feedback(), key: const ValueKey('feedback'), style: last == null ? text.bodyMedium : text.headlineMedium?.copyWith(color: Z.wrong)),
                  if (last != null && spec.hint != null) MathText('${gt('hint', l)}: ${spec.hint!.t(l)}', style: text.bodyLarge),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (mode == QuizMode.rollCall && roll != null) ...[BigButton(collapse: true, icon: Icons.person_off_outlined, label: tr('absent', l), filled: false, onPressed: _absent), const SizedBox(width: 16)],
          if (!widget.auto) ...[BigButton(key: const ValueKey('giveUp'), collapse: true, icon: Icons.visibility_outlined, label: gt('revealSolution', l), filled: false, onPressed: giveUp), const SizedBox(width: 16)],
          BigButton(key: const ValueKey('lockIn'), icon: Icons.lock_outline, label: gt('lockIn', l), color: Z.correct, onPressed: lockIn),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveView(key: _playKey, block: _playfield, lang: l, showTime: over),
                ),
                Positioned.fill(
                  child: IgnorePointer(child: Celebration(controller: party, stars: stars, label: gt('hit', l))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: math.max(box.maxHeight * 0.3, Z.tap + 8)),
            child: footer,
          ),
        ],
      ),
    );
  }

  String _label(String name, Lang l) {
    for (final s in _sliders) {
      if (s.name == name) return s.label.t(l);
    }
    return name;
  }

  static String _trim(double v) => formatNumber(double.parse(v.toStringAsFixed(4)));
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        border: Border.all(color: c, width: 3),
        borderRadius: BorderRadius.circular(Z.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: c),
          const SizedBox(width: 10),
          Flexible(
            child: MathText(label, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Three stars, [stars] of them lit. [dim] shows the ones still on offer, not yet earned.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.dim = false, this.size = 44});
  final int stars;
  final bool dim;
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++) Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i < stars ? Z.accent.withValues(alpha: dim ? 0.55 : 1) : Colors.white38),
    ],
  );
}

/// Confetti and the stars won, played once by [controller]; invisible when it is not running.
class Celebration extends StatelessWidget {
  const Celebration({super.key, required this.controller, required this.stars, required this.label});
  final AnimationController controller;
  final int stars;
  final String label;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final t = controller.value;
      if (t == 0 || t == 1) return const SizedBox.expand();
      final pop = Curves.elasticOut.transform(math.min(1, t * 2.5));
      final fade = t < 0.8 ? 1.0 : (1 - t) / 0.2;
      return Opacity(
        opacity: fade.clamp(0, 1),
        child: CustomPaint(
          painter: _ConfettiPainter(t),
          child: Center(
            child: Transform.scale(
              scale: 0.3 + 0.7 * pop,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StarRow(stars: stars, size: 120),
                    Text(label, style: zText(72, FontWeight.w800).copyWith(color: Z.accent, shadows: const [Shadow(blurRadius: 12)])),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;
  static final _bits = List.generate(70, (i) {
    final r = math.Random(i * 7919);
    return (x: r.nextDouble(), speed: 0.6 + r.nextDouble() * 0.8, spin: r.nextDouble() * 6, drift: (r.nextDouble() - 0.5) * 0.2, color: [Z.accent, Z.correct, ...Z.teamColors][i % 6]);
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _bits) {
      final y = (t * b.speed * 1.3 - 0.15) * size.height;
      final x = (b.x + b.drift * t) * size.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin + t * 10);
      canvas.drawRect(const Rect.fromLTWH(-10, -5, 20, 10), Paint()..color = b.color);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
