import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'auto_play.dart';
import 'lesson_controller.dart';
import 'model.dart';

/// The five phases of a Self-Learning period, in order.
enum Phase { lesson, examples, quiz, recap, homework }

class PeriodStep {
  PeriodStep(this.block, this.phase, this.seconds);
  final Block block;
  final Phase phase;

  /// Planned time on screen. For narrated blocks it is at least the reading time, so the period
  /// still works on a board whose TTS voice is missing.
  int seconds;
}

class PeriodPlan {
  PeriodPlan(this.steps, this.budgetSeconds, this.dropped);
  final List<PeriodStep> steps;
  final int budgetSeconds;
  final List<String> dropped;
  int get plannedSeconds => steps.fold(0, (a, s) => a + s.seconds);
  List<Block> get blocks => [for (final s in steps) s.block];
}

/// Turns a topic's lesson into a period: narrated lesson → examples → class quiz → recap,
/// leaving the rest of the period for homework. Pure, so it is unit-tested.
abstract final class PeriodPlanner {
  /// Classroom TTS at a slow rate: about 0.4 s a word.
  static int readingSeconds(L10n? text) => text == null ? 0 : (text.en.split(RegExp(r'\s+')).length * 0.4).ceil();

  /// Time kept at the end for homework (at least).
  static const homeworkReserve = 120;
  static const minMediaSeconds = 45, minQuizSeconds = 25;

  static int estimate(Block b) {
    final read = readingSeconds(b.narration) + 6;
    return switch (b.type) {
      BlockType.example => max(read, b.list('steps').length * 8 + 14),
      BlockType.classQuiz || BlockType.pyq => read + b.ids('questionIds').length * (b.secondsPerQuestion + 8),
      BlockType.model3d || BlockType.simulation || BlockType.virtualLab => max(read, b.seconds ?? 90),
      BlockType.whiteboard => readingSeconds(b.narration) + whiteboardSeconds(b),
      BlockType.interactive => max(read, b.seconds ?? interactiveSeconds(b)),
      BlockType.activity => max(read, b.seconds ?? activitySeconds(b)),
      BlockType.challenge => max(read, b.seconds ?? challengeSeconds(b)),
      BlockType.explainer => max(read, b.seconds ?? [for (final w in (b.raw['watch'] as List?) ?? const []) if (w is Map) readingSeconds(L10n.maybe(w['say'])) + 2].fold(30, (a, x) => a + x)),
      BlockType.conceptVideo => max(read, b.seconds ?? (b.raw['video'] is Map ? ((b.raw['video'] as Map)['seconds'] as num?)?.toInt() : null) ?? 300),
      _ => max(read, b.seconds ?? 0),
    };
  }

  /// A challenge: the mission read aloud, each try (its time limit, or 45 s to think and set the
  /// sliders) and 20 s for the explanation at the end.
  static int challengeSeconds(Block b) {
    final tries = (b.raw['attempts'] as num?)?.toInt() ?? 3;
    final perTry = (b.raw['timeLimit'] as num?)?.toInt() ?? 45;
    return readingSeconds(b.maybe('prompt')) + tries * perTry + 20;
  }

  /// An interactive: 60 s to explore; a timed model (scene) also plays through twice at 1×
  /// (at most 3 minutes in all).
  static int interactiveSeconds(Block b) {
    final time = b.raw['time'];
    if (time is! Map) return 60;
    final span = ((time['max'] as num?) ?? 0) - ((time['min'] as num?) ?? 0);
    return min(180, 60 + (2 * span).ceil());
  }

  /// An activity: the prompt read aloud, about 8 s an item (sort, match, label, order) or 12 s a
  /// blank, and 20 s to check and talk about it.
  static int activitySeconds(Block b) {
    final items = switch (b.raw['kind']) {
      'sort' => (b.raw['items'] as List?)?.length ?? 4,
      'order' => (b.raw['steps'] as List?)?.length ?? 4,
      'match' => (b.raw['pairs'] as List?)?.length ?? 4,
      'label' || 'hotspot' => (b.raw['targets'] as List?)?.length ?? 4,
      'fill' => ((b.raw['blanks'] as List?)?.length ?? 3) * 3 ~/ 2,
      _ => 4,
    };
    return readingSeconds(b.maybe('prompt')) + items * 8 + 20;
  }

  /// A whiteboard block's steps: each step's line read aloud (at least 3 s of drawing) + 3 s to look.
  static int whiteboardSeconds(Block b) => [for (final st in b.boardSteps) max(readingSeconds(st.say), 3) + 3].fold(0, (a, s) => a + s);

  static Phase phaseOf(Block b) => switch (b.type) {
    BlockType.example => Phase.examples,
    BlockType.classQuiz || BlockType.pyq => Phase.quiz,
    BlockType.recap => Phase.recap,
    _ => Phase.lesson,
  };

  static PeriodPlan plan(Lesson lesson, {required int periodMinutes}) {
    final budget = periodMinutes * 60 - homeworkReserve;
    final steps = [for (final b in lesson.blocks) PeriodStep(b, phaseOf(b), estimate(b))]..sort((a, b) => a.phase.index.compareTo(b.phase.index)); // stable: keeps lesson order inside a phase
    final dropped = <String>[];
    int total() => steps.fold(0, (a, s) => a + s.seconds);

    // 1. Drop optional blocks, tricks first, then media, from the end of the lesson.
    for (final type in [BlockType.trick, BlockType.model3d, BlockType.virtualLab, BlockType.simulation, BlockType.pyq]) {
      for (final s in steps.reversed.toList()) {
        if (total() <= budget) break;
        if (s.block.type == type && s.block.optional) {
          steps.remove(s);
          dropped.add(s.block.id);
        }
      }
    }
    // 2. Shorten media blocks.
    for (final s in steps) {
      if (total() <= budget) break;
      if (s.block.type case BlockType.model3d || BlockType.simulation || BlockType.virtualLab) {
        s.seconds = max(minMediaSeconds, s.seconds - (total() - budget));
      }
    }
    // 3. Never drop the class quiz or the recap: if still over, the homework time absorbs it.
    return PeriodPlan(steps, budget, dropped);
  }
}

/// Drives a [LessonController] through a [PeriodPlan], one second at a time: reads each block
/// aloud, waits its time, waits for quizzes to finish, then shows the homework until the period
/// ends. [tick] is public so tests can run a whole period instantly.
class PeriodRunner extends ChangeNotifier {
  PeriodRunner({required this.c, required this.plan, required this.periodSeconds, this.autoTick = true, this.voice});

  final LessonController c;
  final PeriodPlan plan;
  final int periodSeconds;
  final bool autoTick;

  /// The chapter's voice (an [AutoPlayer] with teacher false, advanceBlocks false): narrated
  /// blocks play step by step and move on when their narration ends, not after a fixed time.
  final AutoPlayer? voice;
  bool get _voiced => voice != null && current.block.raw['voice'] is List;

  int step = 0, elapsed = 0, periodElapsed = 0;
  bool narrationDone = false, quizDone = false, paused = false, homework = false, over = false;
  Timer? _timer;
  int _narrationToken = 0;

  PeriodStep get current => plan.steps[step];
  Phase get phase => homework ? Phase.homework : current.phase;
  int get secondsLeft => max(0, periodSeconds - periodElapsed);

  void start() {
    if (voice != null) c.voiceDriven = true;
    _enter(0);
    voice?.start();
    if (autoTick) _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _enter(int i) {
    step = i;
    elapsed = 0;
    quizDone = false;
    narrationDone = false;
    c.goTo(i);
    _speak();
    notifyListeners();
  }

  Future<void> _speak() async {
    final token = ++_narrationToken;
    if (_voiced) return; // the AutoPlayer follows the controller to this block
    final n = current.block.narration;
    if (n != null && !paused) await c.speak(n);
    if (token == _narrationToken) narrationDone = true;
  }

  bool get _stepDone {
    final b = current.block;
    // A narrated block is done when its last step has been said; a running quiz still finishes.
    if (_voiced) {
      final runsQuiz = (b.type == BlockType.classQuiz && b.style != 'pause') || (b.type == BlockType.pyq && b.style != 'solve');
      return voice!.blockDone && (!runsQuiz || quizDone || elapsed >= current.seconds + 30);
    }
    final isQuiz = current.phase == Phase.quiz;
    if (isQuiz) return quizDone || elapsed >= current.seconds + 30;
    return narrationDone && elapsed >= current.seconds;
  }

  /// Called by the quiz block when its last question is done.
  void onQuizFinished() => quizDone = true;

  void tick() {
    if (over) return;
    if (!paused) periodElapsed++;
    if (periodElapsed >= periodSeconds) {
      _end();
      return;
    }
    if (paused || homework) {
      notifyListeners();
      return;
    }
    elapsed++;
    if (_stepDone) {
      if (step + 1 < plan.steps.length) {
        _enter(step + 1);
      } else {
        homework = true;
        c.recorder.close(completed: true);
      }
    }
    notifyListeners();
  }

  void setPaused(bool p) {
    paused = p;
    c.setPaused(p); // blocks that run on their own (whiteboard steps) wait too
    if (p) {
      _narrationToken++;
      c.stopSpeech();
      narrationDone = true; // on resume the block finishes its time without re-reading
    }
    notifyListeners();
  }

  void _end() {
    over = true;
    homework = true;
    _timer?.cancel();
    c.stopSpeech();
    c.recorder.close(completed: step >= plan.steps.length - 1);
    notifyListeners();
  }

  /// Teacher entered the PIN and left early.
  void stop() {
    _timer?.cancel();
    c.stopSpeech();
    c.recorder.close(completed: homework);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// A Self-Learning period booked by the college (Admin → Self-learning scheduler), synced to the
/// board so it starts on time with no internet.
class ScheduledPeriod {
  ScheduledPeriod({required this.date, required this.start, required this.end, required this.topicId});
  final String date, start, end, topicId; // yyyy-mm-dd, HH:mm, HH:mm

  factory ScheduledPeriod.fromJson(Map<String, dynamic> j) => ScheduledPeriod(date: j['date'] as String, start: j['start'] as String, end: j['end'] as String, topicId: j['topicId'] as String);

  DateTime _at(String hm) => DateTime.parse('${date}T$hm:00');
  DateTime get startsAt => _at(start);
  DateTime get endsAt => _at(end);
  bool isNow(DateTime now) => !now.isBefore(startsAt) && now.isBefore(endsAt);
  int secondsLeft(DateTime now) => endsAt.difference(now).inSeconds;
}
