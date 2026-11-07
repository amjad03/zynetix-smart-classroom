import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../blocks/math_text.dart';
import '../../core/services.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'strings.dart';

enum MockStage { pick, running, scores }

enum MockLength { full, subject, period }

/// A mock test projected for the whole class: pick an exam pattern (from Zynetix School: KCET,
/// NEET, JEE Main, COMEDK), run it with a big clock, section tabs and a question palette while
/// students answer on paper, then enter each roll number's score.
class MockTestScreen extends StatefulWidget {
  const MockTestScreen({super.key, required this.samples});
  final ClassSamples samples;

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  MockStage stage = MockStage.pick;
  late MockPattern pattern = widget.samples.mocks.first;
  MockLength length = MockLength.subject;
  int section = 0, current = 0, secondsLeft = 0;
  final shown = <int>{0};
  final flagged = <int>{};
  Timer? _clock;

  /// Scores by roll number (null: not entered, −1: absent) and the roll being entered.
  late List<int?> scores;
  int entering = 1;
  String typed = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scores = List.filled(ServicesScope.of(context).config.rollCount, null);
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  int get sectionMinutes => switch (length) {
    MockLength.period => 40,
    MockLength.subject => pattern.minutesPerSection ?? (pattern.minutes / pattern.sections.length).round(),
    MockLength.full => pattern.minutesPerSection ?? pattern.minutes,
  };
  int get questionCount => length == MockLength.period ? 30 : pattern.sections[section].count;
  int get maxScore => (questionCount * pattern.sections[section].plus).round();

  void _start() {
    setState(() {
      stage = MockStage.running;
      secondsLeft = sectionMinutes * 60;
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => secondsLeft = math.max(0, secondsLeft - 1));
    });
  }

  void _go(int q) => setState(() {
    current = q.clamp(0, questionCount - 1);
    shown.add(current);
  });

  void _end() {
    _clock?.cancel();
    setState(() => stage = MockStage.scores);
  }

  void _key(String k) => setState(() {
    if (k == '⌫') {
      if (typed.isNotEmpty) typed = typed.substring(0, typed.length - 1);
    } else if (k == 'A') {
      scores[entering - 1] = -1;
      typed = '';
      entering = math.min(scores.length, entering + 1);
    } else if (k == '↵') {
      if (typed.isNotEmpty) scores[entering - 1] = math.min(maxScore, int.parse(typed));
      typed = '';
      entering = math.min(scores.length, entering + 1);
    } else if (typed.length < 3) {
      typed += k;
    }
  });

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final narrow = context.narrow;
      final subject = subjectName(pattern.sections[section].subject, l);
      return ClassScaffold(
        crumbs: [widget.samples.year.t(l), ct('mockTest', l)],
        title: stage == MockStage.pick ? ct('pickExam', l) : '${pattern.exam} · $subject',
        trailing: [if (!narrow && stage != MockStage.pick) BarChip(pattern.marking, icon: Icons.rule)],
        bottomLeft: switch (stage) {
          MockStage.pick => [Text(ct('privacy', l), style: zText(28, FontWeight.w500).copyWith(color: Z.muted))],
          MockStage.running => [
            BigButton(icon: Icons.arrow_back, label: ct('previous', l), filled: false, collapse: true, onPressed: current > 0 ? () => _go(current - 1) : null),
            BigButton(key: const ValueKey('mockFlag'), icon: Icons.flag_outlined, label: ct('flag', l), filled: false, collapse: true, onPressed: () => setState(() => flagged.contains(current) ? flagged.remove(current) : flagged.add(current))),
          ],
          MockStage.scores => [Text(ct('privacy', l), style: zText(28, FontWeight.w500).copyWith(color: Z.muted))],
        },
        bottomRight: switch (stage) {
          MockStage.pick => [BigButton(key: const ValueKey('mockStart'), icon: Icons.play_arrow_rounded, label: ct('startTest', l), onPressed: _start)],
          MockStage.running => [
            BigButton(key: const ValueKey('mockEnd'), icon: Icons.stop_circle_outlined, label: ct('endTest', l), filled: false, onPressed: _end),
            BigButton(key: const ValueKey('mockNext'), icon: Icons.arrow_forward, trailingIcon: true, label: ct('next', l), onPressed: () => _go(current + 1)),
          ],
          MockStage.scores => [BigButton(key: const ValueKey('mockSave'), icon: Icons.save_outlined, label: ct('saveScores', l), onPressed: () => Navigator.of(context).maybePop())],
        },
        body: switch (stage) {
          MockStage.pick => _pick(context, l),
          MockStage.running => _running(context, l),
          MockStage.scores => _scores(context, l),
        },
      );
    },
  );

  Widget _pick(BuildContext context, Lang l) {
    Widget card(MockPattern p) {
      final on = p.id == pattern.id;
      Widget stat(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: zText(28, FontWeight.w400).copyWith(color: Z.muted))),
            Text(value, style: zText(30, FontWeight.w600)),
          ],
        ),
      );
      return Material(
        color: on ? Z.tagBg : Z.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.panelRadius), side: BorderSide(color: on ? Z.primary : Z.panel, width: 5)),
        child: InkWell(
          key: ValueKey('mock-${p.id}'),
          borderRadius: BorderRadius.circular(Z.panelRadius),
          onTap: () => setState(() {
            pattern = p;
            section = 0;
          }),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(p.exam, style: zTitle(64, FontWeight.w700).copyWith(color: on ? Z.primary : Z.ink))),
                    if (on) const Icon(Icons.check_circle, size: 56, color: Z.primary),
                  ],
                ),
                Text(p.title.t(l), style: zText(32, FontWeight.w600).copyWith(color: Z.ink2)),
                const SizedBox(height: 16),
                Text(p.blurb.t(l), style: zText(28, FontWeight.w400).copyWith(color: Z.muted, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Kicker(ct('sections', l)),
                const SizedBox(height: 8),
                for (final sec in p.sections)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 200, child: Text(subjectName(sec.subject, l), style: zText(30, FontWeight.w600))),
                        Expanded(child: ZProgress(value: sec.count / p.sections.map((x) => x.count).reduce(math.max), height: 18, color: on ? Z.primary : Z.ink2, track: on ? Z.panel : Z.track)),
                        SizedBox(width: 90, child: Text('${sec.count}', textAlign: TextAlign.right, style: zText(30, FontWeight.w600))),
                      ],
                    ),
                  ),
                const Spacer(),
                stat(ct('palette', l), '${p.questions}'),
                stat(ct('minutes', l), p.minutesPerSection != null ? '${p.minutesPerSection} × ${p.sections.length}' : '${p.minutes}'),
                stat(ct('marks', l), '${p.maxMarks} · ${p.marking}'),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, p) in widget.samples.mocks.indexed) ...[if (i > 0) const SizedBox(width: 28), Expanded(child: card(p))],
            ],
          ),
        ),
        const SizedBox(height: 28),
        ZPanel(
          padding: const EdgeInsets.all(36),
          child: Row(
            children: [
              Kicker(ct('length', l), size: 30),
              const SizedBox(width: 24),
              SizedBox(
                width: 1000,
                child: ZSegmented<MockLength>(
                  height: 84,
                  fontSize: 30,
                  items: [(MockLength.full, ct('fullPaper', l), null), (MockLength.subject, ct('oneSubject', l), const ValueKey('lenSubject')), (MockLength.period, ct('onePeriod', l), null)],
                  selected: length,
                  onChanged: (v) => setState(() => length = v),
                ),
              ),
              const SizedBox(width: 24),
              for (final (i, s) in pattern.sections.indexed) ...[
                ChoiceChip(
                  label: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text(subjectName(s.subject, l), style: zText(30, FontWeight.w600))),
                  selected: i == section,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => section = i),
                ),
                const SizedBox(width: 12),
              ],
              const SizedBox(width: 12),
              Expanded(child: Text(ct('paperNote', l), style: zText(26, FontWeight.w400).copyWith(color: Z.muted, height: 1.35), maxLines: 3, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _running(BuildContext context, Lang l) {
    final q = widget.samples.questions[current % widget.samples.questions.length];
    final mm = (secondsLeft ~/ 60).toString().padLeft(2, '0'), ss = (secondsLeft % 60).toString().padLeft(2, '0');
    final low = secondsLeft < 5 * 60;
    final timer = Container(
      padding: const EdgeInsets.fromLTRB(44, 32, 44, 36),
      decoration: BoxDecoration(color: Z.stage, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(ct('timeLeft', l), style: zText(30, FontWeight.w600).copyWith(color: Z.onStage2))),
              Text('$sectionMinutes min', style: zText(28, FontWeight.w500).copyWith(color: Z.onStage2)),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('$mm:$ss', key: const ValueKey('mockClock'), style: zText(168, FontWeight.w700).copyWith(color: low ? Z.stageAccent : Colors.white, height: 1.1)),
          ),
          const SizedBox(height: 12),
          ZProgress(value: secondsLeft / (sectionMinutes * 60), height: 16, color: Z.stageAccent, track: Z.stageTrack),
        ],
      ),
    );
    final tabs = Row(
      children: [
        for (final (i, s) in pattern.sections.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: i == section ? Z.primary : Z.segTrack, borderRadius: BorderRadius.circular(Z.radius)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i != section && pattern.minutesPerSection != null) ...[const Icon(Icons.lock_outline, size: 28, color: Z.faint), const SizedBox(width: 8)],
                  Flexible(child: Text(subjectName(s.subject, l), maxLines: 1, overflow: TextOverflow.ellipsis, style: zText(30, FontWeight.w600).copyWith(color: i == section ? Colors.white : Z.ink2))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
    Widget legend(Color bg, Color border, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border, width: 3))),
        const SizedBox(width: 10),
        Text(label, style: zText(26, FontWeight.w500).copyWith(color: Z.ink2)),
      ],
    );
    final palette = ZPanel(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tabs,
          const SizedBox(height: 24),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                const cols = 10, gap = 10.0;
                final rows = (questionCount / cols).ceil();
                final w = (box.maxWidth - gap * (cols - 1)) / cols;
                final h = math.min(w, (box.maxHeight - gap * (rows - 1)) / rows);
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < questionCount; i++)
                      GestureDetector(
                        onTap: () => _go(i),
                        child: Container(
                          width: w,
                          height: h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == current ? Z.primary : (flagged.contains(i) ? Z.highlight : (shown.contains(i) ? Z.tagBg : Z.panel)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: i == current ? Z.primary : (flagged.contains(i) ? Z.star : (shown.contains(i) ? Z.tagBg : Z.line)), width: 3),
                          ),
                          child: Text('${i + 1}', style: zText(h * 0.42, FontWeight.w600).copyWith(color: i == current ? Colors.white : Z.ink)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 24, runSpacing: 10, children: [legend(Z.primary, Z.primary, ct('current', l)), legend(Z.tagBg, Z.tagBg, ct('shown', l)), legend(Z.highlight, Z.star, ct('flagged', l)), legend(Z.panel, Z.line, ct('notYet', l))]),
        ],
      ),
    );
    final question = ZPanel(
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ZTag('${subjectName(pattern.sections[section].subject, l)} · Q ${current + 1} / $questionCount'),
              const SizedBox(width: 16),
              if (flagged.contains(current)) ZTag(ct('flagged', l), color: Z.wrongText, background: Z.highlight, icon: Icons.flag),
            ],
          ),
          const SizedBox(height: 40),
          Text('${current + 1}.', style: zTitle(56).copyWith(color: Z.primary)),
          const SizedBox(height: 8),
          MathText(q.stem.t(l), style: zText(56, FontWeight.w500).copyWith(color: Z.ink, height: 1.4)),
          const SizedBox(height: 48),
          for (final (i, o) in q.options.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(
                children: [
                  Text('(${optionLetters[i]})', style: zText(48, FontWeight.w600).copyWith(color: Z.ink2)),
                  const SizedBox(width: 28),
                  Expanded(child: MathText(o.t(l), style: zText(48, FontWeight.w500).copyWith(color: Z.ink))),
                ],
              ),
            ),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 13, child: question),
        const SizedBox(width: 32),
        Expanded(flex: 7, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [timer, const SizedBox(height: 32), Expanded(child: palette)])),
      ],
    );
  }

  Widget _scores(BuildContext context, Lang l) {
    final entered = [for (final s in scores) if (s != null && s >= 0) s];
    final absent = scores.where((s) => s == -1).length;
    final avg = entered.isEmpty ? 0.0 : entered.reduce((a, b) => a + b) / entered.length;
    final best = entered.isEmpty ? 0 : entered.reduce(math.max);
    final bands = List.filled(4, 0);
    for (final s in entered) {
      bands[math.min(3, s * 4 ~/ (maxScore + 1))]++;
    }
    final most = math.max(1, bands.reduce(math.max));
    final bandLabels = [for (var b = 0; b < 4; b++) '${(b * (maxScore + 1) / 4).ceil()}–${((b + 1) * (maxScore + 1) / 4).ceil() - 1}'];
    final stats = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: ZReadout(label: ct('classAverage', l), value: avg.toStringAsFixed(1), unit: '/ $maxScore', valueSize: 64)),
        const SizedBox(width: 20),
        Expanded(child: ZReadout(label: ct('highest', l), value: '$best', unit: '/ $maxScore', valueSize: 64, tone: Tone.correct)),
        const SizedBox(width: 20),
        Expanded(child: ZReadout(label: ct('entered', l), value: '${entered.length}', unit: '/ ${scores.length}', valueSize: 64)),
        const SizedBox(width: 20),
        Expanded(child: ZReadout(label: ct('absent', l), value: '$absent', valueSize: 64)),
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 14),
            decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ct('spread', l), style: zText(28, FontWeight.w400).copyWith(color: Z.muted)),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var b = 0; b < 4; b++) ...[
                        if (b > 0) const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${bands[b]}', style: zText(26, FontWeight.w700)),
                              Flexible(child: FractionallySizedBox(heightFactor: bands[b] / most, child: Container(decoration: BoxDecoration(color: b == 3 ? Z.correct : (b == 0 ? Z.wrong : Z.primary), borderRadius: BorderRadius.circular(8))))),
                              const SizedBox(height: 6),
                              Text(bandLabels[b], style: zText(22, FontWeight.w500).copyWith(color: Z.muted)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final grid = ZPanel(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 230, child: stats),
          const SizedBox(height: 28),
          Expanded(
            child: RollGrid(
              count: scores.length,
              columns: 10,
              cell: (r) {
                final s = scores[r - 1];
                return RollCell(
                  key: ValueKey('score-$r'),
                  roll: r,
                  mark: Mark.none,
                  selected: r == entering,
                  dim: s == -1,
                  label: s == null ? (r == entering && typed.isNotEmpty ? typed : '—') : (s == -1 ? ct('absent', l) : '$s'),
                  onTap: () => setState(() {
                    entering = r;
                    typed = '';
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
    Widget key(String k, {Color? color}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: color ?? Z.tile,
          borderRadius: BorderRadius.circular(Z.radius),
          child: InkWell(
            key: ValueKey('key-$k'),
            borderRadius: BorderRadius.circular(Z.radius),
            onTap: () => _key(k),
            child: Center(child: Text(k == 'A' ? ct('absent', l) : (k == '↵' ? '${ct('next', l)}  →' : k), style: zText(k == 'A' || k == '↵' ? 32 : 52, FontWeight.w600).copyWith(color: color == null ? Z.ink : Colors.white))),
          ),
        ),
      ),
    );
    final pad = ZPanel(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ct('enterScores', l), style: zTitle(36)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(color: Z.tagBg, borderRadius: BorderRadius.circular(Z.radius)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${ct('rollShort', l)} $entering', style: zText(48, FontWeight.w700).copyWith(color: Z.primary)),
                const Spacer(),
                Text(typed.isEmpty ? '–' : typed, style: zText(88, FontWeight.w700)),
                Text(' / $maxScore', style: zText(34, FontWeight.w500).copyWith(color: Z.muted)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['A', '0', '⌫'],
          ])
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final k in row) key(k)])),
          SizedBox(height: 110, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [key('↵', color: Z.primary)])),
        ],
      ),
    );
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 13, child: grid), const SizedBox(width: 32), Expanded(flex: 5, child: pad)]);
  }
}
