import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../engine/model.dart';
import '../app/settings_view.dart' show pickExamDate;
import 'class_data.dart';
import 'class_quiz_screen.dart';
import 'formula_drill_screen.dart';
import 'class_kit.dart';
import 'strings.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// The syllabus worked back from the exam date: every chapter on a timeline with the revision
/// weeks at the end, where the class is now against where the plan says it should be, this
/// week's chapters and what it takes to catch up.
class ClassPlanScreen extends StatelessWidget {
  const ClassPlanScreen({super.key, required this.samples});
  final ClassSamples samples;

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final p = samples.plan;
      final total = p.examDate.difference(p.start).inDays / 7;
      final planned = p.today.difference(p.start).inDays / 7;
      final actual = p.chapters.fold<double>(0, (a, c) => a + c.weeks * c.done);
      final gap = planned - actual;
      final behindBy = gap.round();
      final weeksLeft = (p.examDate.difference(p.today).inDays / 7).floor();
      final status = behindBy >= 1 ? ct('behind', l, {'n': behindBy}) : (behindBy <= -1 ? ct('ahead', l, {'n': -behindBy}) : ct('onTrack', l));
      final behind = behindBy >= 1;
      final current = p.chapters.indexWhere((c) => c.done < 1);
      final thisWeek = [if (current >= 0) p.chapters[current], if (current >= 0 && current + 1 < p.chapters.length) p.chapters[current + 1]];
      final left = p.chapters.fold<double>(0, (a, c) => a + c.weeks * (1 - c.done));
      final teachWeeks = weeksLeft - p.revisionWeeks;
      final perWeek = left / math.max(1, teachWeeks);

      final head = ZPanel(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
        child: Row(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: Z.tagBg, borderRadius: BorderRadius.circular(Z.radius)),
              child: const Icon(Icons.event_available_outlined, size: 64, color: Z.primary),
            ),
            const SizedBox(width: 36),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.exam.t(l), style: zTitle(48)),
                  Text('${ct('examOn', l, {'d': _date(p.examDate)})}  ·  ${ct('weeksLeft', l, {'n': weeksLeft})}', style: zText(34, FontWeight.w500).copyWith(color: Z.ink2)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              decoration: BoxDecoration(color: behind ? Z.wrongBg : Z.correctBg, borderRadius: BorderRadius.circular(Z.radius)),
              child: Row(
                children: [
                  Icon(behind ? Icons.trending_down : Icons.trending_up, size: 56, color: behind ? Z.wrongText : Z.correct),
                  const SizedBox(width: 16),
                  Text(status, key: const ValueKey('planStatus'), style: zTitle(52, FontWeight.w700).copyWith(color: behind ? Z.wrongText : Z.correct)),
                ],
              ),
            ),
          ],
        ),
      );

      final timeline = ZPanel(
        padding: const EdgeInsets.fromLTRB(48, 36, 48, 36),
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            double x(double weeks) => w * weeks / total;
            final segs = <Widget>[];
            var at = 0.0;
            for (final c in p.chapters) {
              final color = c.done >= 1 ? Z.correct : (c.done > 0 ? Z.primary : Z.track);
              segs.add(
                Positioned(
                  left: x(at) + 3,
                  width: x(c.weeks.toDouble()) - 6,
                  top: 110,
                  height: 120,
                  child: Container(
                    decoration: BoxDecoration(color: c.done > 0 && c.done < 1 ? Z.tagBg : color, borderRadius: BorderRadius.circular(16), border: c.done > 0 && c.done < 1 ? Border.all(color: Z.primary, width: 4) : null),
                    child: Stack(
                      children: [
                        if (c.done > 0 && c.done < 1) FractionallySizedBox(widthFactor: c.done, child: Container(decoration: BoxDecoration(color: Z.primary, borderRadius: BorderRadius.circular(12)))),
                        Center(
                          child: c.done > 0 && c.done < 1
                              ? Container(
                                  width: 72,
                                  height: 72,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: Text('${c.no}', style: zText(40, FontWeight.w700).copyWith(color: Z.primary)),
                                )
                              : Text('${c.no}', style: zText(40, FontWeight.w700).copyWith(color: c.done > 0 ? Colors.white : Z.ink2)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              at += c.weeks;
            }
            // Revision weeks at the end.
            segs.add(
              Positioned(
                left: x(total - p.revisionWeeks) + 3,
                width: x(p.revisionWeeks.toDouble()) - 6,
                top: 110,
                height: 120,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Z.highlight, borderRadius: BorderRadius.circular(16), border: Border.all(color: Z.star, width: 3)),
                  child: Text(ct('revision', l), style: zText(30, FontWeight.w600).copyWith(color: Z.wrongText), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            );
            // Month ticks.
            final ticks = <Widget>[];
            for (var m = DateTime(p.start.year, p.start.month + 1); m.isBefore(p.examDate); m = DateTime(m.year, m.month + 1)) {
              final wk = m.difference(p.start).inDays / 7;
              ticks.add(Positioned(left: x(wk), top: 238, child: Container(width: 3, height: 28, color: Z.line)));
              if ((x(wk) + 10 - x(planned)).abs() < 90) continue; // keep clear of the plan marker
              ticks.add(Positioned(left: x(wk) + 10, top: 236, child: Text(_months[m.month - 1], style: zText(30, FontWeight.w500).copyWith(color: Z.muted))));
            }
            final planLine = [
              Positioned(left: x(planned) - 2, top: 232, child: Container(width: 4, height: 64, color: Z.ink2)),
              Positioned(
                left: x(planned) - 2,
                top: 296,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.pill), border: Border.all(color: Z.ink2, width: 3)),
                  child: Text(ct('planSaysHere', l), style: zText(28, FontWeight.w600).copyWith(color: Z.ink2)),
                ),
              ),
            ];
            final hereLine = [
              Positioned(left: x(actual) - 3, top: 60, child: Container(width: 6, height: 50, color: Z.primary)),
              Positioned(
                key: const ValueKey('weAreHere'),
                left: x(actual) - 3,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 26, 10),
                  decoration: BoxDecoration(color: Z.primary, borderRadius: BorderRadius.circular(Z.pill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.place, size: 38, color: Colors.white), const SizedBox(width: 8), Text(ct('weAreHere', l), style: zText(32, FontWeight.w700).copyWith(color: Colors.white))]),
                ),
              ),
            ];
            return SizedBox(
              height: 360,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ...segs,
                  ...ticks,
                  ...planLine,
                  ...hereLine,
                  Positioned(right: 0, top: 10, child: Row(children: [const Icon(Icons.flag, size: 38, color: Z.ink2), const SizedBox(width: 8), Text(_date(p.examDate), style: zText(32, FontWeight.w600).copyWith(color: Z.ink2))])),
                ],
              ),
            );
          },
        ),
      );

      Widget weekCard(PlanChapter c) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(color: c.done > 0 ? Z.tagBg : Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ZTag(c.done > 0 ? ct('inProgress', l) : ct('upNext', l), color: c.done > 0 ? Z.primary : Z.ink2, background: c.done > 0 ? Z.panel : Z.segTrack),
                  const Spacer(),
                  Text('${(c.done * 100).round()}%', style: zText(40, FontWeight.w700).copyWith(color: c.done > 0 ? Z.primary : Z.muted)),
                ],
              ),
              const SizedBox(height: 20),
              Text('${c.no}. ${c.title.t(l)}', style: zTitle(44), maxLines: 2, overflow: TextOverflow.ellipsis),
              const Spacer(),
              if (c.done > 0) ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    BigButton(icon: Icons.how_to_reg_outlined, label: ct('classQuiz', l), filled: false, onPressed: samples.questions.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClassQuizScreen(samples: samples)))),
                    BigButton(icon: Icons.functions, label: ct('formulaDrill', l), filled: false, onPressed: samples.formulas.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FormulaDrillScreen(samples: samples)))),
                  ],
                ),
                const SizedBox(height: 28),
              ],
              ZProgress(value: c.done, height: 18, track: Z.panel),
              const SizedBox(height: 12),
              Text(ct('weeks', l, {'n': c.weeks}), style: zText(28, FontWeight.w500).copyWith(color: Z.muted)),
            ],
          ),
        ),
      );

      final week = ZPanel(
        padding: const EdgeInsets.all(44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ct('thisWeek', l), style: zTitle(40)),
            const SizedBox(height: 24),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final (i, c) in thisWeek.indexed) ...[if (i > 0) const SizedBox(width: 28), weekCard(c)]])),
          ],
        ),
      );

      final catchUp = ZPanel(
        padding: const EdgeInsets.all(44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ct('catchUp', l), style: zTitle(40)),
            const SizedBox(height: 24),
            for (final line in [
              (Icons.add_alarm, 'Add 1 extra period a week for ${behindBy * 2} weeks'),
              (Icons.speed, 'Teach ${perWeek.toStringAsFixed(1)} chapters a week until ${_date(p.examDate.subtract(Duration(days: 7 * p.revisionWeeks)))}, then revise'),
              (Icons.assignment_outlined, 'Set Ch ${current + 2} formula drill and worksheet as homework'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(line.$1, size: 44, color: Z.primary),
                    const SizedBox(width: 20),
                    Expanded(child: Text(line.$2, style: zText(32, FontWeight.w500).copyWith(height: 1.35))),
                  ],
                ),
              ),
            const Spacer(),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                _Legend(Z.correct, ct('done', l)),
                _Legend(Z.primary, ct('inProgress', l)),
                _Legend(Z.track, ct('upNext', l)),
                _Legend(Z.highlight, ct('revision', l)),
              ],
            ),
          ],
        ),
      );

      return ClassScaffold(
        crumbs: [samples.subject.t(l), samples.year.t(l)],
        title: ct('classPlan', l),
        trailing: [
          BarChip('${ct('planSaysHere', l)}: ${planned.toStringAsFixed(0)} / ${total.round()} wk'),
          GestureDetector(key: const ValueKey('setExamDate'), onTap: () => pickExamDate(context), child: BarChip(l == Lang.kn ? 'ಪರೀಕ್ಷೆ ದಿನಾಂಕ' : 'Exam date', icon: Icons.event_outlined)),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            const SizedBox(height: 32),
            timeline,
            const SizedBox(height: 32),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 3, child: week), const SizedBox(width: 32), Expanded(flex: 2, child: catchUp)])),
          ],
        ),
      );
    },
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
      const SizedBox(width: 10),
      Text(label, style: zText(28, FontWeight.w500).copyWith(color: Z.ink2)),
    ],
  );
}
