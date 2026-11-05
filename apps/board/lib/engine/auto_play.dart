import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'lesson_controller.dart';
import 'model.dart';
import 'voice.dart';

/// Plays one narration clip at a time (lib/engine/voice_player.dart on the board, a fake in tests).
abstract class VoicePlayer {
  /// Plays [clip]. Completes true when it reaches its end, false when it was stopped.
  Future<bool> play(VoiceClip clip);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

/// A player with no sound: each clip "plays" for its recorded length (tests, muted boards).
class SilentVoicePlayer implements VoicePlayer {
  final _wait = PausableWait();
  final played = <String>[];
  @override
  Future<bool> play(VoiceClip clip) {
    played.add(clip.path);
    return _wait.start(Duration(milliseconds: clip.ms));
  }

  @override
  Future<void> pause() async => _wait.pause();
  @override
  Future<void> resume() async => _wait.resume();
  @override
  Future<void> stop() async => _wait.cancel();
  @override
  Future<void> dispose() async => _wait.cancel();
}

/// A timer that can be paused: [start] completes true when the time has run, false if cancelled.
class PausableWait {
  Completer<bool>? _c;
  Timer? _t;
  Duration _left = Duration.zero;
  DateTime _from = DateTime.now();
  bool get running => _c != null && !_c!.isCompleted;

  /// Starts the wait; [paused] starts it held until [resume].
  Future<bool> start(Duration d, {bool paused = false}) {
    cancel();
    final c = _c = Completer<bool>();
    _left = d;
    if (!paused) _run();
    return c.future;
  }

  void _run() {
    _from = DateTime.now();
    _t = Timer(_left, () {
      if (!(_c?.isCompleted ?? true)) _c!.complete(true);
    });
  }

  void pause() {
    if (!running || _t == null) return;
    _t!.cancel();
    _t = null;
    _left -= DateTime.now().difference(_from);
    if (_left.isNegative) _left = Duration.zero;
  }

  void resume() {
    if (running && _t == null) _run();
  }

  void cancel() {
    _t?.cancel();
    _t = null;
    if (!(_c?.isCompleted ?? true)) _c!.complete(false);
  }
}

/// Auto: plays like a video, each step appears as its clip starts and the next step follows when
/// it ends. Manual: the teacher taps Next; each step still says its line as it appears.
enum PlayMode { auto, manual }

/// What the auto-player is doing, for the controls and the tests.
enum PlayPhase { idle, speaking, silent, gap, waiting, done }

/// Drives a [LessonController] from narration, "video style" (docs/architecture.md → Narration).
///
/// Every reveal step of a block has one voice line (lesson `voice`). On each step the player
/// plays that line's clip from the chapter's audio pack; when it ends and a short [gap] has
/// passed it shows the next step (Auto). Steps that ask the class something (a pause-and-think
/// question, an interactive, a lab, a quiz) wait for the teacher in Teacher Mode, and carry on
/// after their narration in Self-Learning ([teacher] false). A step with no clip (no audio pack,
/// or a clip made for older text) is silent: it stays up for its reading time and moves on.
///
/// It follows the controller: Next, Back, an answer tapped or the language switched just make
/// it play the step now shown. Pause on the controller pauses the clip and the timers.
class AutoPlayer extends ChangeNotifier {
  AutoPlayer({
    required this.c,
    required this.player,
    required this.trackFor,
    PlayMode mode = PlayMode.auto,
    this.teacher = true,
    this.advanceBlocks = true,
    this.gap = const Duration(milliseconds: 700),
  }) : _mode = mode;

  final LessonController c;
  final VoicePlayer player;

  /// The lesson's clips in a language (null: no audio pack for it, so the lesson is silent).
  VoiceTrack? Function(Lang lang) trackFor;

  /// Teacher Mode (asking steps wait for Next) or Self-Learning (they carry on).
  final bool teacher;

  /// False in Self-Learning: the period decides when to move to the next block, so the player
  /// stops at the last step of a block and sets [blockDone].
  final bool advanceBlocks;
  final Duration gap;

  PlayMode _mode;
  PlayMode get mode => _mode;
  PlayPhase _phase = PlayPhase.idle;
  PlayPhase get phase => _phase;
  bool get waiting => _phase == PlayPhase.waiting;
  bool get speaking => _phase == PlayPhase.speaking;

  /// The current block's last step has been said (Self-Learning moves on when the period allows).
  bool blockDone = false;

  /// Has the current language a clip for this step?
  bool get hasVoice => _track != null;
  VoiceTrack? _track;

  (int, int, Lang)? _at;
  int _gen = 0;
  bool _paused = false, _started = false;
  final _wait = PausableWait();

  void start() {
    if (_started) return;
    _started = true;
    _paused = c.paused;
    c.addListener(_onChange);
    _enter();
  }

  void setMode(PlayMode m) {
    if (m == _mode) return;
    _mode = m;
    // Switching to Auto on a step already said moves straight on; to Manual just stops advancing.
    if (m == PlayMode.auto && (_phase == PlayPhase.idle || _phase == PlayPhase.waiting) && !_paused) {
      _advance(++_gen);
    } else if (m == PlayMode.manual && (_phase == PlayPhase.gap || _phase == PlayPhase.silent)) {
      _gen++;
      _wait.cancel();
      _set(PlayPhase.idle);
    }
    notifyListeners();
  }

  /// The audio pack has arrived (downloaded) or gone: play the current step again with it.
  void reload() {
    _at = null;
    _onChange();
  }

  /// Back in Auto: the previous block from its first step, as a video would replay it.
  void back() => c.goTo(c.index - 1);

  void _onChange() {
    if (c.paused != _paused) {
      _paused = c.paused;
      if (_paused) {
        _wait.pause();
        unawaited(player.pause());
      } else if (_phase == PlayPhase.speaking) {
        unawaited(player.resume());
      } else {
        _wait.resume();
      }
    }
    final at = (c.index, c.revealed, c.lang);
    if (at != _at && !_paused) _enter();
  }

  Future<void> _enter() async {
    final gen = ++_gen;
    _at = (c.index, c.revealed, c.lang);
    _wait.cancel();
    await player.stop();
    if (gen != _gen) return;
    if (_paused) {
      _at = null; // paused meanwhile: Resume plays this step
      return;
    }
    _track = trackFor(c.lang);
    final b = c.current, step = c.revealed;
    if (step == 1) blockDone = false;
    final clip = _track?.clip(b, step);
    bool ended;
    if (clip != null) {
      _set(PlayPhase.speaking);
      ended = await player.play(clip);
    } else if (_mode == PlayMode.auto) {
      _set(PlayPhase.silent);
      ended = await _wait.start(silentTime(b, step, c.lang), paused: _paused);
    } else {
      ended = true;
    }
    if (gen != _gen || !ended) return;
    if (c.revealDone) blockDone = true;
    if (_mode == PlayMode.manual) {
      _set(PlayPhase.idle);
      return;
    }
    _set(PlayPhase.gap);
    if (!await _wait.start(gap, paused: _paused) || gen != _gen) return;
    _advance(gen);
  }

  void _advance(int gen) {
    if (gen != _gen) return;
    final b = c.current;
    if (teacher && waitsForTeacher(b, c.revealed, c.pack)) return _set(PlayPhase.waiting);
    if (c.revealDone && (c.isLast || !advanceBlocks)) return _set(PlayPhase.done);
    _set(PlayPhase.idle);
    c.next(); // the controller changes: _onChange plays the new step
  }

  void _set(PlayPhase p) {
    if (_phase == p) return;
    _phase = p;
    notifyListeners();
  }

  /// A step with no clip stays up for its recorded length, else about 0.4 s a word (at least 2 s).
  static Duration silentTime(Block b, int step, Lang lang) {
    final v = b.raw['voice'];
    final line = v is List && step <= v.length ? v[step - 1] : null;
    final lengths = line is Map ? line['ms'] : null;
    final ms = lengths is Map ? lengths[lang.name] : null;
    if (ms is int) return Duration(milliseconds: ms);
    final text = voiceLine(b, step, lang) ?? (step == 1 ? b.narration?.t(lang) : null) ?? '';
    return Duration(milliseconds: max(2000, text.split(RegExp(r'\s+')).length * 400));
  }

  /// Steps that ask the class something: Auto waits there for the teacher's Next (or answer).
  static bool waitsForTeacher(Block b, int step, InstalledPack pack) => switch (b.type) {
    BlockType.classQuiz when b.style == 'pause' => step.isOdd, // the question; its answer follows the tap
    BlockType.pyq when b.style == 'solve' => step == 1,
    BlockType.interactive || BlockType.activity || BlockType.challenge || BlockType.virtualLab || BlockType.model3d || BlockType.simulation || BlockType.whiteboard => true,
    BlockType.classQuiz || BlockType.pyq => true,
    _ => false,
  };

  @override
  void dispose() {
    _gen++;
    _wait.cancel();
    if (_started) c.removeListener(_onChange);
    unawaited(player.stop());
    super.dispose();
  }
}
