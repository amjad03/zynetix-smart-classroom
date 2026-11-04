import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';
import '../engine/session_log.dart';
import 'live/hands_up.dart';
import 'live/strings.dart';

/// Picks a random roll number in 1..[rollCount], never one in [exclude]. Returns null when every
/// roll is excluded. Pure, so it is tested directly.
int? pickRoll(Random rnd, int rollCount, Set<int> exclude) {
  final left = [
    for (var r = 1; r <= rollCount; r++)
      if (!exclude.contains(r)) r,
  ];
  return left.isEmpty ? null : left[rnd.nextInt(left.length)];
}

/// multi_correct: right only when the class picked exactly the correct options.
bool multiCorrect(Question q, Set<int> picked) => setEquals(picked, q.correctSet);

/// numeric: right when the value is within ± tolerance (exact when there is none).
bool numericCorrect(Question q, double? value) => value != null && q.numericAnswer != null && (value - q.numericAnswer!).abs() <= (q.tolerance ?? 0) + 1e-9;

/// The keypad's text as a number ("−" is the minus key); null while it is not a number yet.
double? parseTyped(String typed) => double.tryParse(typed.replaceAll('−', '-'));

/// A number for the board: no trailing zeros.
String formatNumber(double v) => v == v.roundToDouble() && v.abs() < 1e15 ? v.round().toString() : v.toString();

/// Team of a roll number when the class is split into [teams] teams: 1, 1+n, 1+2n… in team 0.
int teamOf(int roll, int teams) => (roll - 1) % teams;

/// Records a hands-up count for [q], source 'hands': one answer per present roll number, or one
/// anonymous answer per raised hand when hands were counted per option.
void recordHands(SessionRecorder rec, Question q, HandsResult res, QuizMode mode) {
  if (res.perRoll != null) {
    for (final e in res.perRoll!.entries) {
      rec.answer(questionId: q.id, mode: mode, roll: e.key, chosen: null, correct: e.value, topicId: q.topicId, chapterId: q.chapterId, source: 'hands');
    }
  } else {
    for (final (option, ok) in handsPerOption(res.perOption!, q.correctSet)) {
      rec.answer(questionId: q.id, mode: mode, chosen: option, correct: ok, topicId: q.topicId, chapterId: q.chapterId, source: 'hands');
    }
  }
}

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
    this.handsUp = true,
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

  /// After a reveal, the teacher can count hands (who got it wrong, by roll number, or hands per
  /// option) so every student's answer is recorded. Never in [auto] (no teacher in the room).
  final bool handsUp;
  final VoidCallback? onDone;

  @override
  State<QuizRunner> createState() => QuizRunnerState();
}

class QuizRunnerState extends State<QuizRunner> {
  int q = 0;
  int? chosen;

  /// multi_correct: the options tapped so far, in tap order.
  final picked = <int>{};

  /// numeric: what the monitor typed on the keypad.
  String typed = '';
  bool revealed = false, lastCorrect = false;
  int? roll;
  int left = 0;

  /// What the hands-up count saved for this question (null until then).
  HandsResult? hands;
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
    picked.clear();
    typed = '';
    revealed = false;
    hands = null;
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
  /// multi_correct: a tap toggles the option; Check reveals.
  void choose(int i) {
    if (revealed) return;
    if (question.isMulti) {
      setState(() => picked.contains(i) ? picked.remove(i) : picked.add(i));
      return;
    }
    setState(() => chosen = i);
    reveal();
  }

  /// numeric: a keypad key (digits, ".", "−", "⌫").
  void key(String k) {
    if (revealed) return;
    setState(() {
      if (k == '⌫') {
        if (typed.isNotEmpty) typed = typed.substring(0, typed.length - 1);
      } else if (k == '−') {
        typed = typed.startsWith('−') ? typed.substring(1) : '−$typed';
      } else if (k == '.') {
        if (!typed.contains('.')) typed = '${typed.isEmpty || typed == '−' ? '${typed}0' : typed}.';
      } else if (typed.replaceAll(RegExp(r'[−.]'), '').length < 9) {
        typed += k;
      }
    });
  }

  /// The big Check button (multi_correct and numeric).
  bool get canCheck => question.isMulti ? picked.isNotEmpty : parseTyped(typed) != null;
  void check() {
    if (canCheck) reveal();
  }

  void reveal() {
    if (revealed) return;
    final q = question;
    if (q.isMulti) chosen = picked.isEmpty ? null : picked.first;
    final correct = q.isNumeric
        ? numericCorrect(q, parseTyped(typed))
        : q.isMulti
        ? multiCorrect(q, picked)
        : chosen == q.answer;
    lastCorrect = correct;
    widget.recorder.answer(
      questionId: question.id,
      mode: widget.mode,
      roll: widget.mode == QuizMode.rollCall ? roll : null,
      team: widget.mode == QuizMode.team ? team : null,
      chosen: q.isNumeric ? null : chosen,
      correct: correct,
      topicId: q.topicId,
      chapterId: q.chapterId,
    );
    if (widget.mode == QuizMode.team && correct) widget.room.scores[team]++;
    setState(() {
      revealed = true;
      if (widget.auto && left > 0) left = 0;
    });
  }

  /// Opens the hands-up count and records what it found, source 'hands'. In roll call, the
  /// student who answered aloud is already recorded and is left out.
  Future<void> openHands() async {
    if (!revealed || hands != null) return;
    final q = question;
    final rollCallRoll = widget.mode == QuizMode.rollCall ? roll : null;
    final res = await showHandsUp(context, question: q, rollCount: widget.room.rollCount, absent: widget.room.absent, lang: widget.lang, skip: {?rollCallRoll});
    if (res == null || !mounted) return;
    recordHands(widget.recorder, q, res, widget.mode);
    setState(() => hands = res);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: Z.gap - 8),
                    child: Text('${q + 1} / ${widget.questions.length}', style: text.headlineMedium),
                  ),
                  if (widget.showExams) ...[
                    for (final e in question.exams) Chip(label: Text(e, style: const TextStyle(fontSize: 24))),
                    Chip(label: Text(question.pyqYear != null && question.pyqVerified ? '${question.pyqExam} ${question.pyqYear}' : tr('pyqPattern', l), style: const TextStyle(fontSize: 24))),
                  ],
                ],
              ),
            ),
            if (widget.auto && !revealed) _Countdown(left),
          ],
        ),
        const SizedBox(height: 12),
        _ModeBar(state: this),
        const SizedBox(height: 12),
        if (question.passage != null)
          Container(
            key: const ValueKey('passage'),
            constraints: const BoxConstraints(maxHeight: 240),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Z.radius),
              border: Border(left: BorderSide(color: Z.accent, width: 8)),
            ),
            child: SingleChildScrollView(child: Text(question.passage!.t(l), style: text.bodyLarge?.copyWith(fontSize: 28))),
          ),
        Text(question.stem.t(l), style: question.format == 'mcq' ? text.headlineMedium : text.headlineMedium?.copyWith(fontSize: 34)),
        const SizedBox(height: Z.gap),
        if (question.isNumeric)
          Expanded(child: _NumericPad(state: this))
        else
          Expanded(
            // Two rows that share the height left, so all four options stay visible with an explanation.
            child: context.portrait
                ? Column(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        Expanded(
                          child: _OptionTile(index: i, state: this),
                        ),
                        if (i < 3) const SizedBox(height: 12),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      for (final row in const [
                        [0, 1],
                        [2, 3],
                      ]) ...[
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _OptionTile(index: row[0], state: this),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _OptionTile(index: row[1], state: this),
                              ),
                            ],
                          ),
                        ),
                        if (row[0] == 0) const SizedBox(height: 16),
                      ],
                    ],
                  ),
          ),
        if (revealed) ...[
          if (question.explanation != null) Text(question.explanation!.t(l), style: text.bodyLarge),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              if (widget.handsUp && !widget.auto)
                hands == null
                    ? BigButton(key: const ValueKey('hands'), icon: Icons.back_hand_outlined, label: ltr('hands', l), filled: false, onPressed: openHands)
                    : Text(
                        hands!.perRoll != null ? '${ltr('handsSaved', l)}: ${hands!.right} / ${hands!.total} ${ltr('rightCount', l)}' : '${ltr('handsSaved', l)}: ${hands!.total}',
                        key: const ValueKey('handsDone'),
                        style: text.bodyLarge?.copyWith(color: Z.correct),
                      ),
              BigButton(icon: Icons.arrow_forward, label: tr('nextQuestion', l), onPressed: nextQuestion),
            ],
          ),
        ] else if (question.isMulti)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(child: Text(tr('pickAll', l), style: text.bodyMedium)),
                BigButton(key: const ValueKey('check'), icon: Icons.fact_check_outlined, label: tr('check', l), color: Z.correct, onPressed: canCheck ? check : null),
              ],
            ),
          )
        else if (!question.isNumeric)
          Text(tr('monitorTaps', l), style: text.bodyMedium, textAlign: TextAlign.center),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.index, required this.state});
  final int index;
  final QuizRunnerState state;

  @override
  Widget build(BuildContext context) {
    final q = state.question;
    final isAnswer = q.correctSet.contains(index), isChosen = q.isMulti ? state.picked.contains(index) : index == state.chosen;
    final scheme = Theme.of(context).colorScheme;
    final bg = !state.revealed
        ? (isChosen ? Z.accent.withValues(alpha: 0.35) : scheme.surfaceContainerHighest)
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Z.radius),
        side: !state.revealed && isChosen ? const BorderSide(color: Z.accent, width: 5) : BorderSide.none,
      ),
      child: InkWell(
        key: ValueKey('option-$index'),
        borderRadius: BorderRadius.circular(Z.radius),
        onTap: enabled ? () => state.choose(index) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: fg.withValues(alpha: 0.15),
                child: Text(
                  'ABCD'[index],
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  q.options[index].t(state.widget.lang),
                  style: TextStyle(fontSize: q.format == 'assertion_reason' ? 26 : 32, color: fg),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.revealed && isAnswer) const Icon(Icons.check_circle, color: Colors.white, size: 48),
              if (!state.revealed && q.isMulti) Icon(isChosen ? Icons.check_box : Icons.check_box_outline_blank, size: 52, color: isChosen ? Z.accent : fg.withValues(alpha: 0.6)),
            ],
          ),
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
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (state.roll != null)
              Container(
                key: const ValueKey('roll'),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                decoration: BoxDecoration(color: Z.accent, borderRadius: BorderRadius.circular(Z.radius)),
                child: Text(
                  '${tr('rollNo', l)} ${state.roll}',
                  style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: Colors.black),
                ),
              ),
            const SizedBox(width: Z.gap),
            if (!state.revealed) BigButton(icon: Icons.casino_outlined, label: tr('pickRoll', l), filled: state.roll == null, onPressed: state._pickRoll),
            const SizedBox(width: 16),
            if (state.roll != null && !state.revealed) BigButton(icon: Icons.person_off_outlined, label: tr('absent', l), filled: false, onPressed: state._markAbsent),
          ],
        );
      case QuizMode.team:
        return Wrap(
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var t = 0; t < w.room.teams; t++)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Z.teamColors[t].withValues(alpha: t == state.team ? 1 : 0.35),
                  borderRadius: BorderRadius.circular(Z.radius),
                  border: t == state.team ? Border.all(color: Z.accent, width: 6) : null,
                ),
                child: Text(
                  '${tr('team', l)} ${t + 1}: ${w.room.scores[t]}',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            const SizedBox(width: 8),
            Text('${tr('teamTurn', l)}: ${tr('team', l)} ${state.team + 1} (${tr('rollNo', l)} ${state.team + 1}, ${state.team + 1 + w.room.teams}, …)', style: Theme.of(context).textTheme.bodyMedium),
          ],
        );
    }
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown(this.left);
  final int left;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.timer_outlined, size: 44),
      const SizedBox(width: 8),
      Text(
        '${max(left, 0)}s',
        style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: left <= 10 ? Z.wrong : null),
      ),
    ],
  );
}

/// numeric: the class answer in big type and an on-screen keypad (digits, ., −, ⌫) with Check.
/// After Check: right or wrong, and the correct value.
class _NumericPad extends StatelessWidget {
  const _NumericPad({required this.state});
  final QuizRunnerState state;
  static const rows = [
    ['7', '8', '9', '⌫'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '.'],
  ];

  @override
  Widget build(BuildContext context) {
    final l = state.widget.lang, q = state.question, scheme = Theme.of(context).colorScheme;
    final shown = state.typed.isEmpty ? '—' : state.typed;
    final tol = q.tolerance ?? 0;
    final answer = '${formatNumber(q.numericAnswer ?? double.nan)}${tol > 0 ? ' ± ${formatNumber(tol)}' : ''}';
    Widget key(String k, {Color? color, Widget? child, VoidCallback? onTap}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: color ?? scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            key: ValueKey('key-$k'),
            borderRadius: BorderRadius.circular(20),
            onTap: state.revealed ? null : (onTap ?? () => state.key(k)),
            child: Center(
              child: child ?? Text(k, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('yourAnswer', l), style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('typed'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: !state.revealed ? scheme.surfaceContainerHighest : (state.lastCorrect ? Z.correct : Z.wrong),
                  borderRadius: BorderRadius.circular(Z.radius),
                  border: Border.all(color: Z.accent, width: state.revealed ? 0 : 4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        shown,
                        style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (state.revealed) Icon(state.lastCorrect ? Icons.check_circle : Icons.cancel, size: 72, color: Colors.white),
                  ],
                ),
              ),
              if (state.revealed) ...[
                const SizedBox(height: 20),
                Text(
                  '${tr('correctAnswer', l)}: $answer',
                  key: const ValueKey('numericAnswer'),
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Z.correct),
                ),
              ] else ...[
                const SizedBox(height: 20),
                Text(tr('typeAnswer', l), style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        const SizedBox(width: Z.gap),
        SizedBox(
          width: 560,
          child: Column(
            children: [
              for (final r in rows)
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final k in r) key(k)]),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    key('0'),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: FilledButton.icon(
                          key: const ValueKey('check'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Z.correct,
                            foregroundColor: Colors.white,
                            textStyle: zText(36, FontWeight.w700),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: !state.revealed && state.canCheck ? state.check : null,
                          icon: const Icon(Icons.fact_check_outlined, size: 44),
                          label: Text(tr('check', l)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
