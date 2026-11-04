import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import 'strings.dart';

/// What a hands-up count found: either each present roll number right or wrong ([perRoll]), or,
/// from a show of hands per option, how many hands went up for A, B, C, D ([perOption]).
class HandsResult {
  const HandsResult.perRoll(this.perRoll) : perOption = null;
  const HandsResult.perOption(this.perOption) : perRoll = null;
  final Map<int, bool>? perRoll;
  final List<int>? perOption;

  int get right => perRoll?.values.where((v) => v).length ?? 0;
  int get total => perRoll?.length ?? perOption!.fold(0, (a, b) => a + b);
}

/// Each present roll number (1..[rollCount], not in [absent]) right or wrong: the rolls in
/// [tapped] get the opposite of [baseline]. Rolls in [skip] (already recorded, e.g. the roll-call
/// student) are left out.
Map<int, bool> handsPerRoll({required int rollCount, required Set<int> absent, required Set<int> tapped, bool baseline = true, Set<int> skip = const {}}) => {
  for (var r = 1; r <= rollCount; r++)
    if (!absent.contains(r) && !skip.contains(r)) r: tapped.contains(r) ? !baseline : baseline,
};

/// A show of hands per option as anonymous answers, one per hand, right when the option is in
/// [correct]. Right and wrong are interleaved evenly so the class estimate (a moving average)
/// ends at the share that was right, not at whichever came last.
List<(int option, bool correct)> handsPerOption(List<int> counts, Set<int> correct) {
  final right = <int>[], wrong = <int>[];
  for (var i = 0; i < counts.length; i++) {
    for (var k = 0; k < counts[i]; k++) {
      (correct.contains(i) ? right : wrong).add(i);
    }
  }
  final n = right.length + wrong.length;
  final out = <(int, bool)>[];
  var ri = 0, wi = 0;
  for (var i = 0; i < n; i++) {
    final takeRight = ((i + 1) * right.length) ~/ n > (i * right.length) ~/ n;
    if (takeRight) {
      out.add((right[ri++], true));
    } else {
      out.add((wrong[wi++], false));
    }
  }
  return out;
}

/// Opens the hands-up count for [question] full screen. [absent] (the class's absent rolls) is
/// updated in place when the teacher saves. Returns null when cancelled.
Future<HandsResult?> showHandsUp(BuildContext context, {required Question question, required int rollCount, required Set<int> absent, required Lang lang, Set<int> skip = const {}}) =>
    Navigator.of(context).push<HandsResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => HandsUpScreen(question: question, rollCount: rollCount, absent: absent, lang: lang, skip: skip),
      ),
    );

enum TapMeans { wrong, right, absent }

/// Hands-up count after a question is revealed. By roll number: every present roll number in one
/// grid that fits the screen; tap the few who got it wrong (or switch to tap the few who got it
/// right) and Save. Per option: count the raised hands for A, B, C, D.
class HandsUpScreen extends StatefulWidget {
  const HandsUpScreen({super.key, required this.question, required this.rollCount, required this.absent, required this.lang, this.skip = const {}});
  final Question question;
  final int rollCount;
  final Set<int> absent;
  final Lang lang;
  final Set<int> skip;

  @override
  State<HandsUpScreen> createState() => HandsUpScreenState();
}

class HandsUpScreenState extends State<HandsUpScreen> {
  late final Set<int> absent = {...widget.absent};
  final tapped = <int>{};
  TapMeans means = TapMeans.wrong;
  bool byOption = false;
  late final List<int> counts = List.filled(min(4, widget.question.options.length), 0);

  bool get baseline => _mark != TapMeans.right;

  /// A show of hands per option makes sense only with one correct option to choose.
  bool get optionsAllowed => !widget.question.isNumeric && !widget.question.isMulti && widget.question.options.length >= 2;

  Map<int, bool> get perRoll => handsPerRoll(rollCount: widget.rollCount, absent: absent, tapped: tapped, baseline: baseline, skip: widget.skip);

  void tap(int roll) => setState(() {
    if (means == TapMeans.absent) {
      absent.contains(roll) ? absent.remove(roll) : absent.add(roll);
      tapped.remove(roll);
    } else if (!absent.contains(roll)) {
      tapped.contains(roll) ? tapped.remove(roll) : tapped.add(roll);
    }
  });

  /// The last marking mode (wrong or right) chosen; absent mode keeps it.
  TapMeans _mark = TapMeans.wrong;

  void setMeans(TapMeans m) => setState(() {
    // Switching between "tap = wrong" and "tap = right" flips the baseline: start afresh.
    if (m != TapMeans.absent) {
      if (m != _mark) tapped.clear();
      _mark = m;
    }
    means = m;
  });

  void save() {
    if (byOption) {
      Navigator.pop(context, HandsResult.perOption(List.of(counts)));
    } else {
      widget.absent
        ..clear()
        ..addAll(absent);
      Navigator.pop(context, HandsResult.perRoll(perRoll));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang, text = Theme.of(context).textTheme;
    final narrow = context.narrow;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Z.tap + 16,
        leading: IconButton(key: const ValueKey('handsCancel'), iconSize: 56, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(byOption ? ltr('perOption', l) : ltr('handsWho', l), style: narrow ? text.headlineMedium : text.headlineLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (optionsAllowed)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: BigButton(
                key: const ValueKey('handsByOption'),
                collapse: true,
                filled: false,
                icon: byOption ? Icons.grid_view : Icons.bar_chart,
                label: byOption ? ltr('perRoll', l) : ltr('perOption', l),
                onPressed: () => setState(() => byOption = !byOption),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: BigButton(key: const ValueKey('handsSave'), icon: Icons.check, label: ltr('save', l), onPressed: save),
          ),
        ],
      ),
      body: Padding(padding: EdgeInsets.all(narrow ? 16 : 32), child: byOption ? _options(l, text) : _grid(l, text)),
    );
  }

  Widget _grid(Lang l, TextTheme text) {
    final pr = perRoll;
    final right = pr.values.where((v) => v).length, wrong = pr.length - right;
    final help = switch (means) {
      TapMeans.wrong => ltr('handsHelp', l),
      TapMeans.right => ltr('handsHelpRight', l),
      TapMeans.absent => ltr('handsHelpAbsent', l),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<TapMeans>(
              style: SegmentedButton.styleFrom(minimumSize: const Size(160, Z.tap - 16), textStyle: zText(context.narrow ? 24 : 28)),
              segments: [
                ButtonSegment(value: TapMeans.wrong, label: Text(ltr('tapWrong', l), key: const ValueKey('tapWrong'))),
                ButtonSegment(value: TapMeans.right, label: Text(ltr('tapRight', l), key: const ValueKey('tapRight'))),
                ButtonSegment(value: TapMeans.absent, label: Text(ltr('tapAbsent', l), key: const ValueKey('tapAbsent'))),
              ],
              selected: {means},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setMeans(v.first),
            ),
            Text(
              '$right ${ltr('rightCount', l)} · $wrong ${ltr('wrongCount', l)} · ${absent.length} ${ltr('absentCount', l)}',
              key: const ValueKey('handsTally'),
              style: text.headlineMedium?.copyWith(fontSize: 36),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(help, style: text.bodyMedium),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final n = widget.rollCount;
              const gap = 8.0;
              // The column count that gives the biggest square-ish cells with every roll visible.
              var best = 1, bestSide = 0.0;
              for (var cols = 1; cols <= n; cols++) {
                final rows = (n / cols).ceil();
                final side = min((c.maxWidth - gap * (cols - 1)) / cols, (c.maxHeight - gap * (rows - 1)) / rows);
                if (side > bestSide) {
                  bestSide = side;
                  best = cols;
                }
              }
              final scroll = bestSide < 72;
              final cols = scroll ? max(1, (c.maxWidth / 96).floor()) : best;
              final cellW = (c.maxWidth - gap * (cols - 1)) / cols;
              final cellH = scroll ? 88.0 : min(cellW, bestSide);
              return GridView.builder(
                physics: scroll ? null : const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: gap, crossAxisSpacing: gap, mainAxisExtent: cellH),
                itemCount: n,
                itemBuilder: (_, i) => _cell(i + 1, pr, min(cellW, cellH)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cell(int roll, Map<int, bool> pr, double side) {
    final isAbsent = absent.contains(roll), skipped = widget.skip.contains(roll);
    final ok = pr[roll];
    final scheme = Theme.of(context).colorScheme;
    final bg = isAbsent
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : skipped
        ? Z.accent.withValues(alpha: 0.4)
        : ok == true
        ? Z.correctBg
        : Z.wrong;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('roll-$roll'),
        borderRadius: BorderRadius.circular(14),
        onTap: skipped ? null : () => tap(roll),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                '$roll',
                style: zText(max(24, side * 0.42), FontWeight.w600).copyWith(
                  color: isAbsent ? Z.ghost : (ok == true && !skipped ? Z.correct : Colors.white),
                  decoration: isAbsent ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _options(Lang l, TextTheme text) {
    final q = widget.question;
    final present = widget.rollCount - absent.length;
    final total = counts.fold(0, (a, b) => a + b);
    Widget stepper(int i, int by, IconData icon) => Padding(
      padding: const EdgeInsets.only(left: 12),
      child: IconButton.filledTonal(
        key: ValueKey('count-$i-$by'),
        iconSize: 52,
        constraints: const BoxConstraints(minWidth: Z.tap, minHeight: Z.tap),
        onPressed: counts[i] + by < 0 ? null : () => setState(() => counts[i] += by),
        icon: by == 5 ? const Text('+5', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800)) : Icon(icon),
      ),
    );
    return ListView(
      children: [
        Text(ltr('perOptionHelp', l), style: text.bodyMedium),
        const SizedBox(height: 8),
        Text('$total / $present', key: const ValueKey('optionTotal'), style: text.headlineMedium),
        const SizedBox(height: 16),
        for (var i = 0; i < counts.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: (q.correctSet.contains(i) ? Z.correct : Theme.of(context).colorScheme.surfaceContainerHighest).withValues(alpha: q.correctSet.contains(i) ? 0.5 : 1),
              borderRadius: BorderRadius.circular(Z.radius),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  child: Text('ABCD'[i], style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(q.options[i].t(l), style: text.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 110,
                  child: Text('${counts[i]}', key: ValueKey('count-$i'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800)),
                ),
                stepper(i, -1, Icons.remove),
                stepper(i, 1, Icons.add),
                if (!context.narrow) stepper(i, 5, Icons.add),
              ],
            ),
          ),
        Text('${tr('correctAnswer', l)}: ${'ABCD'[q.answer.clamp(0, 3)]}', style: text.bodyMedium?.copyWith(color: Z.correct)),
      ],
    );
  }
}
