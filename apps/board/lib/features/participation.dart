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
    this.label,
    this.onReteach,
  });

  /// The tag over the question ("Class quiz", "Exam questions").
  final String? label;

  /// Re-teach the topic another way, from the rail after a reveal (null: no other way left).
  final Future<void> Function()? Function(BuildContext context)? onReteach;

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

  /// Wrong roll numbers from the hands-up count (the "Need help" chips).
  List<int> get needHelp => [
    for (final e in (hands?.perRoll ?? const <int, bool>{}).entries)
      if (!e.value) e.key,
  ]..sort();

  /// Hands per option, when known: a count per option.
  List<int>? get optionCounts {
    final h = hands;
    if (h == null) return null;
    if (h.perOption != null) return h.perOption;
    // By roll: only how many got the answer right.
    final q = question;
    if (q.isMulti || q.isNumeric) return null;
    return [for (var i = 0; i < q.options.length; i++) i == q.answer ? h.right : -1];
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang;
    if (finished) {
      return Center(child: Text(tr('done', l), style: Theme.of(context).textTheme.displayLarge));
    }
    final narrow = context.narrow, portrait = context.portrait;
    final panel = _QuestionPanel(state: this);
    final rail = _Rail(state: this);
    if (portrait) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: panel),
          SizedBox(height: narrow ? 20 : Z.gap),
          rail,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: panel),
        SizedBox(width: narrow ? 20 : Z.gap),
        SizedBox(width: narrow ? 560 : 760, child: rail),
      ],
    );
  }
}

/// The question: tag, position, exams, the stem, the options (or keypad), and Why after a reveal.
class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({required this.state});
  final QuizRunnerState state;

  @override
  Widget build(BuildContext context) {
    final w = state.widget, l = w.lang, question = state.question, q = state.q;
    final narrow = context.narrow, portrait = context.portrait;
    final n = w.questions.length;
    final stemStyle = zTitle(narrow ? (portrait ? 34 : 38) : 52, FontWeight.w500).copyWith(height: 1.4, fontSize: question.format == 'mcq' ? null : (narrow ? 32 : 46));
    return Container(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 28 : 80, vertical: narrow ? 24 : 56),
      decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: LayoutBuilder(builder: (context, box) {
      // A short screen (a phone on its side) drops the position row and keeps the stem small.
      final short = box.maxHeight < 700;
      final h = box.maxHeight;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!short || w.auto) Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (w.label != null && !narrow) ZTag(w.label!),
                    if (n > 1 && n <= 12 && !narrow)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < n; i++) Container(width: 64, height: 12, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: i <= q ? Z.primary : Z.track, borderRadius: BorderRadius.circular(Z.pill))),
                        ],
                      ),
                    Text('${q + 1} / $n', style: zText(28, FontWeight.w500).copyWith(color: Z.muted)),
                    if (w.showExams && !(narrow && portrait)) ...[
                      for (final e in question.exams) ZTag.neutral(e),
                      ZTag.neutral(question.pyqYear != null && question.pyqVerified ? '${question.pyqExam} ${question.pyqYear}' : tr('pyqPattern', l)),
                    ] else if (w.showExams)
                      Text(question.pyqYear != null && question.pyqVerified ? '${question.pyqExam} ${question.pyqYear}' : question.exams.join(' · '), style: zText(24, FontWeight.w500).copyWith(color: Z.muted)),
                  ],
                ),
              ),
              if (w.auto && !state.revealed) _Countdown(state.left),
            ],
          ),
          if (!short || w.auto) SizedBox(height: narrow ? 20 : 40),
          if (question.passage != null)
            Container(
              key: const ValueKey('passage'),
              constraints: const BoxConstraints(maxHeight: 240),
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
              child: SingleChildScrollView(child: Text(question.passage!.t(l), style: zText(28, FontWeight.w400).copyWith(color: Z.ink2, height: 1.5))),
            ),
          // A long stem scrolls in its own box so the options always keep their room.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * (short ? 0.2 : 0.26)),
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!narrow) ...[
                    Container(
                      width: 104,
                      height: 104,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Z.segTrack, borderRadius: BorderRadius.circular(28)),
                      child: Text('Q${q + 1}', style: zTitle(40).copyWith(color: Z.ink2)),
                    ),
                    const SizedBox(width: 40),
                  ],
                  Expanded(child: Text(question.stem.t(l), style: stemStyle)),
                ],
              ),
            ),
          ),
          SizedBox(height: short ? 12 : (narrow ? 20 : 48)),
          if (question.isNumeric)
            Expanded(child: _NumericPad(state: state))
          else
            Expanded(
              // Two rows that share the height left, so all four options stay visible with an explanation.
              child: portrait
                  ? Column(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          Expanded(child: _OptionTile(index: i, state: state)),
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
                                Expanded(child: _OptionTile(index: row[0], state: state)),
                                const SizedBox(width: 24),
                                Expanded(child: _OptionTile(index: row[1], state: state)),
                              ],
                            ),
                          ),
                          if (row[0] == 0) const SizedBox(height: 24),
                        ],
                      ],
                    ),
            ),
          if (state.revealed && question.explanation != null) ...[
            SizedBox(height: short ? 12 : (narrow ? 16 : 40)),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: h * (short ? 0.22 : 0.26)),
              child: Container(
                key: const ValueKey('why'),
                padding: EdgeInsets.symmetric(horizontal: narrow ? 28 : 44, vertical: narrow ? 20 : 36),
                decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(28)),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(question.isNumeric || question.isMulti ? tr('why', l) : '${tr('why', l)} ${question.options[question.answer].t(l)}', style: zTitle(30)),
                      const SizedBox(height: 12),
                      Text(question.explanation!.t(l), style: zText(narrow ? 30 : 34, FontWeight.w400).copyWith(color: const Color(0xFF2A3135), height: 1.55)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      );
      }),
    );
  }
}

/// The rail beside the question: who answers, the class's responses and who needs help, and the
/// next step (Check, Count hands, Re-teach, Next question).
class _Rail extends StatelessWidget {
  const _Rail({required this.state});
  final QuizRunnerState state;

  @override
  Widget build(BuildContext context) {
    final w = state.widget, l = w.lang, question = state.question;
    final portrait = context.portrait, narrow = context.narrow;
    final hands = state.hands;
    final reteach = state.revealed && !w.auto ? w.onReteach?.call(context) : null;
    final actions = <Widget>[
      if (state.revealed) ...[
        if (w.handsUp && !w.auto && hands == null) BigButton(key: const ValueKey('hands'), icon: Icons.back_hand_outlined, label: ltr('hands', l), filled: false, onPressed: state.openHands),
        if (reteach != null) BigButton(key: const ValueKey('quizReteach'), icon: Icons.replay, label: tr('reteach', l), filled: false, onPressed: reteach),
        BigButton(icon: Icons.arrow_forward, trailingIcon: true, label: tr('nextQuestion', l), onPressed: state.nextQuestion),
      ] else if (question.isMulti)
        BigButton(key: const ValueKey('check'), icon: Icons.fact_check_outlined, label: tr('check', l), onPressed: state.canCheck ? state.check : null),
    ];
    final hint = !state.revealed
        ? (question.isMulti ? tr('pickAll', l) : (question.isNumeric ? tr('typeAnswer', l) : tr('monitorTaps', l)))
        : (hands == null && w.handsUp && !w.auto ? tr('countHands', l) : null);
    final help = state.needHelp;
    final responses = hands == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ZTileGrid(
                children: [
                  ZReadout(label: tr('answered', l), value: '${hands.total}', unit: '/ ${w.room.rollCount}', valueSize: 48),
                  if (hands.perRoll != null || hands.perOption != null)
                    ZReadout(
                      label: tr('correct', l),
                      value: hands.total == 0 ? '—' : '${(100 * _right(hands, question) / hands.total).round()}%',
                      tone: Tone.correct,
                      valueSize: 48,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                hands.perRoll != null ? '${ltr('handsSaved', l)}: ${hands.right} / ${hands.total} ${ltr('rightCount', l)}' : '${ltr('handsSaved', l)}: ${hands.total}',
                key: const ValueKey('handsDone'),
                style: zText(26, FontWeight.w500).copyWith(color: Z.correctLabel),
              ),
              if (w.room.absent.isNotEmpty) ...[const SizedBox(height: 16), Wrap(spacing: 12, children: [ZTag.neutral('${tr('absent', l)} ${w.room.absent.length}')])],
            ],
          );
    final needHelp = hands?.perRoll == null
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (help.isEmpty)
                RailNote(tr('allRight', l))
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final r in help)
                      Container(
                        key: ValueKey('help-$r'),
                        constraints: const BoxConstraints(minWidth: 80, minHeight: 68, maxHeight: 68),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: Z.wrongBg, borderRadius: BorderRadius.circular(20)),
                        child: Center(widthFactor: 1, child: Text('$r', style: zText(28, FontWeight.w600).copyWith(color: Z.wrongText))),
                      ),
                  ],
                ),
            ],
          );

    if (portrait) {
      // Under the question: one compact panel.
      return ZPanel(
        padding: EdgeInsets.all(narrow ? 24 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeBar(state: state),
            if (hands != null) ...[
              Text(
                hands.perRoll != null ? '${ltr('handsSaved', l)}: ${hands.right} / ${hands.total} ${ltr('rightCount', l)}${help.isEmpty ? '' : ' · ${tr('needHelp', l)}: ${help.join(', ')}'}' : '${ltr('handsSaved', l)}: ${hands.total}',
                key: const ValueKey('handsDone'),
                style: zText(26, FontWeight.w500).copyWith(color: Z.correctLabel),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ] else if (hint != null) ...[
              Text(hint, style: zText(26, FontWeight.w400).copyWith(color: Z.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (actions.isNotEmpty) const SizedBox(height: 12),
            ],
            if (actions.isNotEmpty) Wrap(alignment: WrapAlignment.end, spacing: 16, runSpacing: 12, children: actions),
          ],
        ),
      );
    }

    final modePanel = w.mode == QuizMode.monitor ? null : RailPanel(title: w.mode == QuizMode.team ? tr('team', l) : tr('rollNo', l), children: [_ModeBar(state: state)]);
    final responsesPanel = RailPanel(title: tr('responses', l), children: [?responses, if (hint != null) RailNote(hint)]);
    final helpTitle = needHelp == null ? null : ZSectionTitle(help.isEmpty ? tr('needHelp', l) : '${tr('needHelp', l)} · ${help.length} ${tr('rollNumbers', l)}');
    final pad = EdgeInsets.fromLTRB(narrow ? 32 : 44, 40, narrow ? 32 : 44, 40);
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxHeight < 1000) {
          // Short screen: one scrolling column.
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (modePanel != null) ...[modePanel, const SizedBox(height: 20)],
                responsesPanel,
                const SizedBox(height: 20),
                ZPanel(
                  padding: pad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (helpTitle != null) ...[helpTitle, const SizedBox(height: 24), needHelp!, const SizedBox(height: 32)],
                      for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(height: 16), a],
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (modePanel != null) ...[modePanel, const SizedBox(height: Z.gap)],
            responsesPanel,
            const SizedBox(height: Z.gap),
            // Nothing to show yet (before the reveal): no empty panel.
            if (needHelp == null && actions.isEmpty)
              const Spacer()
            else
            Expanded(
              child: ZPanel(
                padding: pad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (helpTitle != null) ...[helpTitle, const SizedBox(height: 24)],
                    Expanded(child: SingleChildScrollView(child: needHelp ?? const SizedBox.shrink())),
                    for (final a in actions) ...[const SizedBox(height: 16), a],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static int _right(HandsResult h, Question q) {
    if (h.perRoll != null) return h.right;
    final c = h.perOption!;
    return [for (var i = 0; i < c.length; i++) if (q.correctSet.contains(i)) c[i]].fold(0, (a, b) => a + b);
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
    final revealed = state.revealed;
    final right = revealed && isAnswer, wrongPick = revealed && isChosen && !isAnswer;
    final narrow = context.narrow;
    final bg = right
        ? const Color(0xFFEEF8F3)
        : wrongPick
        ? Z.wrongBg
        : (!revealed && isChosen ? Z.tagBg : Z.panel);
    final border = right
        ? const BorderSide(color: Z.correct, width: 4)
        : wrongPick
        ? const BorderSide(color: Z.wrong, width: 4)
        : (!revealed && isChosen ? const BorderSide(color: Z.primary, width: 4) : const BorderSide(color: Z.track, width: 2));
    final fg = revealed && !isAnswer ? Z.ink2 : Z.ink;
    // Roll call: wait until a roll number has been picked.
    final enabled = !revealed && (state.widget.mode != QuizMode.rollCall || state.roll != null);
    final counts = state.optionCounts;
    final total = counts == null ? 0 : state.hands!.total;
    final count = counts != null && index < counts.length ? counts[index] : -1;
    final badge = Container(
      width: narrow ? 64 : 80,
      height: narrow ? 64 : 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: right ? Z.correct : (wrongPick ? Z.wrong : (!revealed && isChosen ? Z.primary : Z.segTrack)), borderRadius: BorderRadius.circular(20)),
      child: right
          ? Icon(Icons.check, size: narrow ? 36 : 44, color: Colors.white)
          : wrongPick
          ? Icon(Icons.close, size: narrow ? 36 : 44, color: Colors.white)
          : Text('ABCD'[index], style: zText(narrow ? 28 : 34, FontWeight.w600).copyWith(color: !revealed && isChosen ? Colors.white : Z.ink2)),
    );
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: border),
      child: InkWell(
        key: ValueKey('option-$index'),
        borderRadius: BorderRadius.circular(28),
        onTap: enabled ? () => state.choose(index) : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 36, vertical: narrow ? 8 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  children: [
                    badge,
                    SizedBox(width: narrow ? 16 : 28),
                    Expanded(
                      child: Text(
                        q.options[index].t(state.widget.lang),
                        style: zText(q.format == 'assertion_reason' ? (narrow ? 24 : 28) : (narrow ? 30 : 44), right ? FontWeight.w600 : FontWeight.w400).copyWith(color: fg),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (right && !narrow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: Z.correctTint, borderRadius: BorderRadius.circular(Z.pill)),
                        child: Text(tr('correct', state.widget.lang), style: zText(26, FontWeight.w600).copyWith(color: Z.correct)),
                      ),
                    if (!revealed && q.isMulti) Icon(isChosen ? Icons.check_box : Icons.check_box_outline_blank, size: 52, color: isChosen ? Z.primary : Z.faint),
                    if (narrow && counts != null && count >= 0 && total > 0) ...[
                      const SizedBox(width: 12),
                      Text('$count · ${(100 * count / total).round()}%', key: ValueKey('count-$index'), style: zText(26, right ? FontWeight.w600 : FontWeight.w400).copyWith(color: right ? Z.correct : Z.muted)),
                    ],
                  ],
                ),
              ),
              // The class's responses for this option, once counted.
              if (!narrow && counts != null && count >= 0 && total > 0) ...[
                SizedBox(height: narrow ? 8 : 24),
                Row(
                  children: [
                    Expanded(child: ZProgress(value: count / total, height: 16, color: right ? Z.correct : Z.ghost, track: right ? Z.correctTint : Z.segTrack)),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 150,
                      child: Text('$count · ${(100 * count / total).round()}%', key: ValueKey('count-$index'), textAlign: TextAlign.right, style: zText(28, right ? FontWeight.w600 : FontWeight.w400).copyWith(color: right ? Z.ink : Z.muted)),
                    ),
                  ],
                ),
              ],
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(color: Z.tagBg, borderRadius: BorderRadius.circular(Z.radius)),
                child: Text(
                  '${tr('rollNo', l)} ${state.roll}',
                  style: zText(52, FontWeight.w600).copyWith(color: Z.primary),
                ),
              ),
            if (!state.revealed) BigButton(icon: Icons.casino_outlined, label: tr('pickRoll', l), filled: state.roll == null, onPressed: state._pickRoll),
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
                  color: t == state.team ? Z.teamColors[t] : Z.segTrack,
                  borderRadius: BorderRadius.circular(Z.radius),
                ),
                child: Text(
                  '${tr('team', l)} ${t + 1}: ${w.room.scores[t]}',
                  style: zText(34, FontWeight.w600).copyWith(color: t == state.team ? Colors.white : Z.ink2),
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
        style: zText(40, FontWeight.w600).copyWith(color: left <= 10 ? Z.wrongText : Z.ink),
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
    final l = state.widget.lang, q = state.question;
    final shown = state.typed.isEmpty ? '—' : state.typed;
    final tol = q.tolerance ?? 0;
    final answer = '${formatNumber(q.numericAnswer ?? double.nan)}${tol > 0 ? ' ± ${formatNumber(tol)}' : ''}';
    Widget key(String k, {Color? color, Widget? child, VoidCallback? onTap}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: color ?? Z.tile,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            key: ValueKey('key-$k'),
            borderRadius: BorderRadius.circular(20),
            onTap: state.revealed ? null : (onTap ?? () => state.key(k)),
            child: Center(
              child: child ?? Text(k, style: zText(48, FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
    // Answer beside the keypad; on an upright screen, above it. The answer side scrolls if short.
    final portrait = context.portrait;
    return Flex(
      direction: portrait ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          fit: portrait ? FlexFit.loose : FlexFit.tight,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('yourAnswer', l), style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('typed'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: !state.revealed ? Z.panel : (state.lastCorrect ? Z.correctBg : Z.wrongBg),
                    borderRadius: BorderRadius.circular(Z.radius),
                    border: Border.all(color: !state.revealed ? Z.primary : (state.lastCorrect ? Z.correct : Z.wrong), width: 4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          shown,
                          style: zText(80, FontWeight.w600).copyWith(color: !state.revealed ? Z.ink : (state.lastCorrect ? Z.correct : Z.wrongText)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (state.revealed) Icon(state.lastCorrect ? Icons.check_circle : Icons.cancel, size: 72, color: state.lastCorrect ? Z.correct : Z.wrong),
                    ],
                  ),
                ),
                if (state.revealed) ...[
                  const SizedBox(height: 20),
                  Text(
                    '${tr('correctAnswer', l)}: $answer',
                    key: const ValueKey('numericAnswer'),
                    style: zText(44, FontWeight.w600).copyWith(color: Z.correct),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  Text(tr('typeAnswer', l), style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
        portrait ? const SizedBox(height: Z.gap) : const SizedBox(width: Z.gap),
        portrait ? Expanded(child: _keys(key)) : SizedBox(width: 560, child: _keys(key)),
      ],
    );
  }

  Widget _keys(Widget Function(String k, {Color? color, Widget? child, VoidCallback? onTap}) key) {
    final l = state.widget.lang;
    return Column(
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
                      textStyle: zText(34, FontWeight.w600),
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
    );
  }
}
