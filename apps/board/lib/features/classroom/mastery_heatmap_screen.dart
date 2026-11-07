import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/model.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'strings.dart';

enum HeatView { skills, rolls }

/// Class mastery as a heatmap: chapters × skills (the class average), or roll numbers ×
/// chapters, with the weak topics to revise next. Built from class quizzes and paper marks.
class MasteryHeatmapScreen extends StatefulWidget {
  const MasteryHeatmapScreen({super.key, required this.samples, this.view = HeatView.skills});
  final ClassSamples samples;
  final HeatView view;

  @override
  State<MasteryHeatmapScreen> createState() => _MasteryHeatmapScreenState();
}

(Color, Color) heatColors(int v) {
  if (v < 0) return (Z.well, Z.ghost);
  if (v >= 85) return (const Color(0xFF7FCBA6), const Color(0xFF0B4D35));
  if (v >= 75) return (Z.correctTint, Z.correctLabel);
  if (v >= 62) return (const Color(0xFFFFE3A8), const Color(0xFF6B4200));
  if (v >= 50) return (const Color(0xFFFFF0CC), const Color(0xFF6B4200));
  if (v >= 40) return (const Color(0xFFF6B48F), const Color(0xFF7A3206));
  return (const Color(0xFFE98B5C), const Color(0xFF4A1A02));
}

class _MasteryHeatmapScreenState extends State<MasteryHeatmapScreen> {
  late HeatView view = widget.view;

  MasteryData get d => widget.samples.mastery;

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final legend = Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _Swatch(heatColors(80).$1, ct('strong', l)),
          _Swatch(heatColors(60).$1, ct('okay', l)),
          _Swatch(heatColors(45).$1, ct('weak', l)),
          _Swatch(Z.well, ct('noData', l)),
        ],
      );
      return ClassScaffold(
        crumbs: [widget.samples.subject.t(l), widget.samples.year.t(l)],
        title: ct('classMastery', l),
        trailing: [
          SizedBox(
            width: 900,
            child: ZSegmented<HeatView>(
              height: 72,
              fontSize: 28,
              items: [(HeatView.skills, ct('chaptersSkills', l), const ValueKey('viewSkills')), (HeatView.rolls, ct('rollsChapters', l), const ValueKey('viewRolls'))],
              selected: view,
              onChanged: (v) => setState(() => view = v),
            ),
          ),
        ],
        body: view == HeatView.skills ? _skills(context, l, legend) : _rolls(context, l, legend),
      );
    },
  );

  Widget _cell(int v, double size, {bool showValue = true}) {
    final (bg, fg) = heatColors(v);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: showValue ? Text(v < 0 ? '—' : '$v', style: zText(size, FontWeight.w700).copyWith(color: fg)) : null,
    );
  }

  Widget _skills(BuildContext context, Lang l, Widget legend) {
    final classAvg = [for (final row in d.bySkill) (row.reduce((a, b) => a + b) / row.length).round()];
    final table = ZPanel(
      padding: const EdgeInsets.all(44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ct('fromQuizzes', l), style: zText(30, FontWeight.w500).copyWith(color: Z.muted)),
          const SizedBox(height: 24),
          SizedBox(
            height: 72,
            child: Row(
              children: [
                SizedBox(width: 440, child: Kicker(ct('chapter', l), size: 30)),
                for (final s in d.skills) Expanded(child: Center(child: Text(s.t(l), style: zText(32, FontWeight.w600).copyWith(color: Z.ink2), maxLines: 1, overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 20),
                SizedBox(width: 180, child: Center(child: Text('Class', style: zText(32, FontWeight.w700)))),
              ],
            ),
          ),
          for (final (ci, row) in d.bySkill.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 440,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('${ci + 1}. ${d.chapters[ci].t(l)}', style: zText(36, FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    for (final v in row) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _cell(v, 44))),
                    const SizedBox(width: 20),
                    SizedBox(width: 180, child: _cell(classAvg[ci], 48)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 28),
          legend,
        ],
      ),
    );
    final weakest = d.revise.first;
    final ch = weakest.$2;
    final rollsBelow = [for (var r = 0; r < d.byRoll[ch].length; r++) if (d.byRoll[ch][r] >= 0 && d.byRoll[ch][r] < 50) r + 1];
    final revise = ZPanel(
      padding: const EdgeInsets.all(44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ct('reviseNext', l), style: zTitle(44)),
          const SizedBox(height: 24),
          for (final (i, (topic, c, score)) in d.revise.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(color: i == 0 ? Z.wrongBg : Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
                child: Row(
                  children: [
                    Text('${i + 1}', style: zTitle(44, FontWeight.w700).copyWith(color: i == 0 ? Z.wrongText : Z.muted)),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(topic.t(l), style: zText(34, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(d.chapters[c].t(l), style: zText(28, FontWeight.w400).copyWith(color: Z.muted)),
                        ],
                      ),
                    ),
                    Text('$score%', style: zText(40, FontWeight.w700).copyWith(color: heatColors(score).$2)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Kicker(ct('rollsBelow', l, {'c': d.chapters[ch].t(l)})),
          const SizedBox(height: 14),
          Expanded(child: SingleChildScrollView(child: Wrap(spacing: 12, runSpacing: 12, children: [for (final r in rollsBelow) RollChip(r, size: 32)]))),
          const SizedBox(height: 16),
          BigButton(icon: Icons.how_to_reg_outlined, label: ct('quizThis', l), onPressed: () {}),
        ],
      ),
    );
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 13, child: table), const SizedBox(width: 32), Expanded(flex: 7, child: revise)]);
  }

  Widget _rolls(BuildContext context, Lang l, Widget legend) {
    final n = d.byRoll.first.length;
    return ZPanel(
      padding: const EdgeInsets.all(44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Expanded(child: Text(ct('fromQuizzes', l), style: zText(30, FontWeight.w500).copyWith(color: Z.muted))), legend]),
          const SizedBox(height: 28),
          SizedBox(
            height: 60,
            child: Row(
              children: [
                SizedBox(width: 340, child: Kicker('${ct('rollShort', l)} →', size: 30)),
                for (var r = 1; r <= n; r++) Expanded(child: Center(child: Text('$r', style: zText(28, FontWeight.w700).copyWith(color: Z.ink2)))),
              ],
            ),
          ),
          for (final (ci, row) in d.byRoll.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 340, child: Align(alignment: Alignment.centerLeft, child: Text('${ci + 1}. ${d.chapters[ci].t(l)}', style: zText(32, FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis))),
                    for (final v in row) Expanded(child: Padding(padding: const EdgeInsets.all(3), child: _cell(v, 22, showValue: false))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: Row(
              children: [
                for (final (i, (topic, _, score)) in d.revise.take(3).indexed) ...[
                  if (i > 0) const SizedBox(width: 24),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(color: i == 0 ? Z.wrongBg : Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
                      child: Row(
                        children: [
                          Expanded(child: Text('${ct('reviseNext', l)}: ${topic.t(l)}', style: zText(32, FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                          Text('$score%', style: zText(38, FontWeight.w700).copyWith(color: heatColors(score).$2)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), border: Border.all(color: Z.line, width: 2))),
      const SizedBox(width: 10),
      Text(label, style: zText(28, FontWeight.w500).copyWith(color: Z.ink2)),
    ],
  );
}
