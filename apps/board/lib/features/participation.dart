import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';
import '../engine/session_log.dart';

/// Picks a random roll number in 1..[rollCount], never one in [exclude]. Returns null when every
/// roll is excluded. Pure, so it is tested directly.
int? pickRoll(Random rnd, int rollCount, Set<int> exclude) {
  final left = [for (var r = 1; r <= rollCount; r++) if (!exclude.contains(r)) r];
  return left.isEmpty ? null : left[rnd.nextInt(left.length)];
}

/// Team of a roll number when the class is split into [teams] teams: 1, 1+n, 1+2n… in team 0.
int teamOf(int roll, int teams) => (roll - 1) % teams;

/// Who has answered in this session: absent rolls, rolls already picked, team scores.
/// Shared by every quiz in one lesson so the roll picker does not keep calling the same students.
class ClassRoom {
  ClassRoom({required this.rollCount, Random? random}) : random = random ?? Random();
  final int rollCount;
  final Random random;
  final absent = <int>{};
  final picked = <int>{};
  int teams = 2;
  final scores = List<int>.filled(4, 0);

  int? nextRoll() {
    var r = pickRoll(random, rollCount, {...absent, ...picked});
    if (r == null) {
      picked.clear(); // everyone has had a turn: start a new round
      r = pickRoll(random, rollCount, absent);
    }
    if (r != null) picked.add(r);
    return r;
  }
}

/// Runs a set of questions with the whole class: [QuizMode.monitor] (the monitor taps the
/// class's answer), [QuizMode.rollCall] (a random roll number answers) or [QuizMode.team].
/// With [auto] (Self-Learning) it counts down, reveals, and moves on by itself.
class QuizRunner extends StatefulWidget {
  const QuizRunner({
    super.key,
    required this.questions,
    required this.mode,
    required this.lang,
    required this.recorder,
    required this.room,
    this.auto = false,
    this.secondsPerQuestion = 45,
    this.showExams = false,
    this.onDone,
  });

  final List<Question> questions;
  final QuizMode mode;
  final Lang lang;
  final SessionRecorder recorder;
  final ClassRoom room;
  final bool auto;
  final int secondsPerQuestion;
  final bool showExams;
  final VoidCallback? onDone;

  @override
  State<QuizRunner> createState() => QuizRunnerState();
}

class QuizRunnerState extends State<QuizRunner> {
  int q = 0;
  int? chosen;
  bool revealed = false;
  int? roll;
  int left = 0;
  Timer? _tick;

  Question get question => widget.questions[q];
  int get team => q % widget.room.teams;
  bool get finished => q >= widget.questions.length;

  @override
  void initState() {
    super.initState();
    _startQuestion();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _startQuestion() {
    chosen = null;
    revealed = false;
    roll = widget.mode == QuizMode.rollCall && widget.auto ? widget.room.nextRoll() : null;
    left = widget.secondsPerQuestion;
    _tick?.cancel();
    if (widget.auto) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => left--);
        if (left <= 0 && !revealed) reveal();
        if (left <= -8) nextQuestion(); // 8 s to read the explanation
      });
    }
  }

  /// The monitor tapped the class's (or the roll number's, or the team's) answer.
  void choose(int i) {
    if (revealed) return;
    setState(() => chosen = i);
    reveal();
  }

  void reveal() {
    if (revealed) return;
    final correct = chosen == question.answer;
    widget.recorder.answer(
      questionId: question.id,
      mode: widget.mode,
      roll: widget.mode == QuizMode.rollCall ? roll : null,
      team: widget.mode == QuizMode.team ? team : null,
      chosen: chosen,
      correct: correct,
    );
    if (widget.mode == QuizMode.team && correct) widget.room.scores[team]++;
    setState(() {
      revealed = true;
      if (widget.auto && left > 0) left = 0;
    });
  }

  void nextQuestion() {
    setState(() => q++);
    if (finished) {
      _tick?.cancel();
      widget.onDone?.call();
    } else {
      _startQuestion();
    }
  }

  void _pickRoll() => setState(() => roll = widget.room.nextRoll());

  void _markAbsent() {
    if (roll != null) widget.room.absent.add(roll!);
    _pickRoll();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang;
    if (finished) {
      return Center(child: Text(tr('done', l), style: Theme.of(context).textTheme.displayLarge));
    }
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('${q + 1} / ${widget.questions.length}', style: text.headlineMedium),
        const SizedBox(width: Z.gap),
        if (widget.showExams) ...[
          for (final e in question.exams) Padding(padding: const EdgeInsets.only(right: 8), child: Chip(label: Text(e, style: const TextStyle(fontSize: 24)))),
          Chip(label: Text(question.pyqYear != null && question.pyqVerified ? '${question.pyqExam} ${question.pyqYear}' : tr('pyqPattern', l), style: const TextStyle(fontSize: 24))),
        ],
        const Spacer(),
        if (widget.auto && !revealed) _Countdown(left),
      ]),
      const SizedBox(height: 12),
      _ModeBar(state: this),
      const SizedBox(height: 12),
      Text(question.stem.t(l), style: text.headlineMedium),
      const SizedBox(height: Z.gap),
      Expanded(
        // Two rows that share the height left, so all four options stay visible with an explanation.
        child: Column(children: [
          for (final row in const [[0, 1], [2, 3]]) ...[
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _OptionTile(index: row[0], state: this)),
              const SizedBox(width: 16),
              Expanded(child: _OptionTile(index: row[1], state: this)),
            ])),
            if (row[0] == 0) const SizedBox(height: 16),
          ],
        ]),
      ),
      if (revealed) ...[
        if (question.explanation != null) Text(question.explanation!.t(l), style: text.bodyLarge),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: BigButton(icon: Icons.arrow_forward, label: tr('nextQuestion', l), onPressed: nextQuestion)),
      ] else
        Text(tr('monitorTaps', l), style: text.bodyMedium, textAlign: TextAlign.center),
    ]);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.index, required this.state});
  final int index;
  final QuizRunnerState state;

  @override
  Widget build(BuildContext context) {
    final q = state.question;
    final isAnswer = index == q.answer, isChosen = index == state.chosen;
    final scheme = Theme.of(context).colorScheme;
    final bg = !state.revealed
        ? scheme.surfaceContainerHighest
        : isAnswer
            ? Z.correct
            : isChosen
                ? Z.wrong
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final fg = state.revealed && (isAnswer || isChosen) ? Colors.white : scheme.onSurface;
    // Roll call: wait until a roll number has been picked.
    final enabled = !state.revealed && (state.widget.mode != QuizMode.rollCall || state.roll != null);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(Z.radius),
      child: InkWell(
        key: ValueKey('option-$index'),
        borderRadius: BorderRadius.circular(Z.radius),
        onTap: enabled ? () => state.choose(index) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [
            CircleAvatar(radius: 34, backgroundColor: fg.withValues(alpha: 0.15), child: Text('ABCD'[index], style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: fg))),
            const SizedBox(width: 20),
            Expanded(child: Text(q.options[index].t(state.widget.lang), style: TextStyle(fontSize: 32, color: fg), maxLines: 2, overflow: TextOverflow.ellipsis)),
            if (state.revealed && isAnswer) const Icon(Icons.check_circle, color: Colors.white, size: 48),
          ]),
        ),
      ),
    );
  }
}

/// The strip above the question: who answers (roll number, team) and the team scores.
class _ModeBar extends StatelessWidget {
  const _ModeBar({required this.state});
  final QuizRunnerState state;

  @override
  Widget build(BuildContext context) {
    final w = state.widget, l = w.lang;
    switch (w.mode) {
      case QuizMode.monitor:
        return const SizedBox.shrink();
      case QuizMode.rollCall:
        return Row(children: [
          if (state.roll != null)
            Container(
              key: const ValueKey('roll'),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              decoration: BoxDecoration(color: Z.accent, borderRadius: BorderRadius.circular(Z.radius)),
              child: Text('${tr('rollNo', l)} ${state.roll}', style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
          const SizedBox(width: Z.gap),
          if (!state.revealed) BigButton(icon: Icons.casino_outlined, label: tr('pickRoll', l), filled: state.roll == null, onPressed: state._pickRoll),
          const SizedBox(width: 16),
          if (state.roll != null && !state.revealed) BigButton(icon: Icons.person_off_outlined, label: tr('absent', l), filled: false, onPressed: state._markAbsent),
        ]);
      case QuizMode.team:
        return Row(children: [
          for (var t = 0; t < w.room.teams; t++)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: Z.teamColors[t].withValues(alpha: t == state.team ? 1 : 0.35),
                borderRadius: BorderRadius.circular(Z.radius),
                border: t == state.team ? Border.all(color: Z.accent, width: 6) : null,
              ),
              child: Text('${tr('team', l)} ${t + 1}: ${w.room.scores[t]}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          const SizedBox(width: 8),
          Text('${tr('teamTurn', l)}: ${tr('team', l)} ${state.team + 1} (${tr('rollNo', l)} ${state.team + 1}, ${state.team + 1 + w.room.teams}, …)', style: Theme.of(context).textTheme.bodyMedium),
        ]);
    }
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown(this.left);
  final int left;
  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.timer_outlined, size: 44),
        const SizedBox(width: 8),
        Text('${max(left, 0)}s', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: left <= 10 ? Z.wrong : null)),
      ]);
}
