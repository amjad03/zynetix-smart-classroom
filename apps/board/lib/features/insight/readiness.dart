import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import 'analysis.dart';
import 'mastery_map.dart' show RollReportScreen;
import 'strings.dart';

final _scopes = Expando<(int, ExamScope)>('examScope');

/// The section's exam scope, worked out once (again only when packs are installed or removed).
ExamScope examScopeOf(Services s) {
  final n = s.store.packs.length;
  final hit = _scopes[s];
  if (hit != null && hit.$1 == n) return hit.$2;
  final scope = ExamScope.of(s);
  _scopes[s] = (n, scope);
  return scope;
}

Color bandColor(Band b) => switch (b) {
  Band.ready => Z.correct,
  Band.onTrack => const Color(0xFF1565C0),
  Band.needsWork => Z.wrong,
  Band.noData => const Color(0xFF616161),
};

String bandLabel(Band b, Lang l) => it(switch (b) {
  Band.ready => 'bandReady',
  Band.onTrack => 'bandOnTrack',
  Band.needsWork => 'bandNeedsWork',
  Band.noData => 'bandNoData',
}, l);

/// One exam's readiness: band, estimate % and coverage.
class ReadinessTile extends StatelessWidget {
  const ReadinessTile({super.key, required this.r, required this.curriculum, required this.lang});
  final Readiness r;
  final String curriculum;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme, b = r.band;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 260, child: Text(r.exam.labelFor(curriculum), style: text.headlineMedium)),
              _BandChip(band: b, lang: lang),
              Text(
                b == Band.noData
                    ? '${(r.coverage * 100).round()}% ${it('coverage', lang)}'
                    : '${it('estimate', lang)} ${(r.score * 100).round()}% · ${(r.coverage * 100).round()}% ${it('coverage', lang)}',
                style: text.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: b == Band.noData ? 0 : r.score, minHeight: 12, color: bandColor(b), borderRadius: BorderRadius.circular(6)),
        ],
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({required this.band, required this.lang, this.compact = false});
  final Band band;
  final Lang lang;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18, vertical: compact ? 4 : 8),
    decoration: BoxDecoration(color: bandColor(band), borderRadius: BorderRadius.circular(40)),
    child: Text(bandLabel(band, lang), style: zText(compact ? 22 : 26).copyWith(color: Colors.white), overflow: TextOverflow.ellipsis),
  );
}

/// Readiness for every exam this section can sit, for the class or one roll number, with the
/// "this is an estimate" note.
class ReadinessList extends StatelessWidget {
  const ReadinessList({super.key, this.roll});
  final int? roll;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), l = s.config.lang, scope = examScopeOf(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in scope.exams) ReadinessTile(r: scope.readiness(s.mastery, e, roll: roll), curriculum: s.config.board, lang: l),
        Text(it('estimateNote', l), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
      ],
    );
  }
}

/// Exam readiness for the class, then every roll number by exam (a lazy list: 60+ rolls).
class ExamReadinessScreen extends StatelessWidget {
  const ExamReadinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), l = s.config.lang, text = Theme.of(context).textTheme;
    final scope = examScopeOf(s), exams = scope.exams;
    final last = s.mastery.rolls.isEmpty ? 0 : s.mastery.rolls.last;
    final rolls = [for (var r = 1; r <= (last > s.config.rollCount ? last : s.config.rollCount); r++) r];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Z.tap + 16,
        leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(it('examReadiness', l), style: text.headlineLarge),
      ),
      body: ListenableBuilder(
        listenable: s.mastery,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(context.narrow ? 24 : 40),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${s.config.sectionLabel} · ${it('classCol', l)}', style: text.headlineMedium?.copyWith(color: Z.accent)),
                    const SizedBox(height: 16),
                    const ReadinessList(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: context.narrow ? 24 : 40),
              sliver: SliverList.builder(
                itemCount: rolls.length,
                itemBuilder: (context, i) {
                  final r = rolls[i];
                  return InkWell(
                    key: ValueKey('readinessRoll:$r'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RollReportScreen(roll: r))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 160, child: Text('${it('roll', l)} $r', style: text.bodyLarge)),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final e in exams)
                                  Tooltip(
                                    message: e.labelFor(s.config.board),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(child: Text('${e.labelFor(s.config.board)} ', style: text.bodyMedium, overflow: TextOverflow.ellipsis)),
                                        Flexible(child: _BandChip(band: scope.readiness(s.mastery, e, roll: r).band, lang: l, compact: true)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
