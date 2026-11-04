import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../engine/mastery.dart';
import '../../engine/model.dart';
import '../player.dart';
import 'analysis.dart';
import 'readiness.dart';
import 'strings.dart';
import 'worksheet.dart';

Color levelColor(Level l, {int n = 0}) => switch (l) {
  Level.mastered => Z.correct,
  Level.learning => const Color(0xFFF9A825),
  Level.stuck => Z.wrong,
  Level.unknown => n == 0 ? const Color(0x22FFFFFF) : const Color(0x66FFFFFF),
};

String levelLabel(Level v, Lang l) => it(switch (v) {
  Level.mastered => 'mastered',
  Level.learning => 'learning',
  Level.stuck => 'stuck',
  Level.unknown => 'unknown',
}, l);

String pct(Estimate? e) => e == null ? '–' : '${(e.p * 100).round()}%';

/// Roll numbers shown for this section: 1..roll count (and any higher roll that has answered).
List<int> sectionRolls(Services s) {
  final last = s.mastery.rolls.isEmpty ? 0 : s.mastery.rolls.last;
  return [for (var r = 1; r <= max(last, s.config.rollCount); r++) r];
}

/// The class heatmap: topics (rows, grouped by chapter) × roll numbers (columns), coloured by
/// level, with the class estimate per topic. Rows are built lazily and each row's cells are
/// painted in one go, so 60 rolls × hundreds of topics stays smooth. Filters: subject,
/// chapter, only weak, only topics with answers.
class MasteryMapScreen extends StatefulWidget {
  const MasteryMapScreen({super.key});
  @override
  State<MasteryMapScreen> createState() => _MasteryMapScreenState();
}

class _MasteryMapScreenState extends State<MasteryMapScreen> {
  late final Services s = ServicesScope.of(context);
  late final List<TopicRef> all = sectionTopics(s);
  String? subject, chapterId;
  bool onlyWeak = false, onlyData = false;

  bool _weak(String t) {
    final e = s.mastery.classTopic(t);
    return (e != null && (e.level == Level.stuck || e.level == Level.learning)) || s.mastery.stuck(t).isNotEmpty;
  }

  /// Chapter headers and topic rows after the filters.
  List<Object> _items() {
    final out = <Object>[];
    Chapter? last;
    for (final t in all) {
      if (subject != null && t.subject != subject) continue;
      if (chapterId != null && t.chapter.id != chapterId) continue;
      if (onlyData && s.mastery.classTopic(t.id) == null) continue;
      if (onlyWeak && !_weak(t.id)) continue;
      if (t.chapter != last) out.add(last = t.chapter);
      out.add(t);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = s.config.lang, text = Theme.of(context).textTheme;
    final chapters = <Chapter>{
      for (final t in all)
        if (t.subject == subject) t.chapter,
    }.toList();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Z.tap + 16,
        leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(it('masteryMap', l), style: text.headlineLarge, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const ValueKey('openReadiness'),
            iconSize: 56,
            tooltip: it('examReadiness', l),
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExamReadinessScreen())),
          ),
          IconButton(
            key: const ValueKey('openWorksheet'),
            iconSize: 56,
            tooltip: it('worksheet', l),
            icon: const Icon(Icons.print_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorksheetScreen())),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListenableBuilder(
        listenable: s.mastery,
        builder: (context, _) {
          final items = _items();
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: context.narrow ? 16 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filters scroll sideways on a phone rather than taking half the screen.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final sub in [null, ...s.subjects])
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            key: ValueKey('subject:${sub ?? 'all'}'),
                            label: Text(sub == null ? it('allSubjects', l) : subjectName(sub, l), style: zText(26)),
                            selected: subject == sub,
                            onSelected: (_) => setState(() {
                              subject = sub;
                              chapterId = null;
                            }),
                          ),
                        ),
                      if (subject != null && chapters.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: DropdownButton<String?>(
                            key: const ValueKey('chapterFilter'),
                            value: chapterId,
                            style: zText(26),
                            items: [
                              DropdownMenuItem(value: null, child: Text(it('allChapters', l))),
                              for (final c in chapters)
                                DropdownMenuItem(
                                  value: c.id,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 560),
                                    child: Text('${c.year == 'puc1' ? 'I' : 'II'} · ${c.number}. ${c.title.t(l)}', overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => chapterId = v),
                          ),
                        ),
                      FilterChip(
                        key: const ValueKey('onlyWeak'),
                        label: Text(it('onlyWeak', l), style: zText(26)),
                        selected: onlyWeak,
                        onSelected: (v) => setState(() => onlyWeak = v),
                      ),
                      const SizedBox(width: 10),
                      FilterChip(
                        key: const ValueKey('onlyData'),
                        label: Text(it('onlyData', l), style: zText(26)),
                        selected: onlyData,
                        onSelected: (v) => setState(() => onlyData = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Legend(lang: l),
                const SizedBox(height: 12),
                Expanded(
                  child: items.isEmpty
                      ? Center(child: Text(it('noTopics', l), style: text.headlineMedium))
                      : HeatGrid(items: items, rolls: sectionRolls(s), lang: l),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.lang});
  final Lang lang;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 24,
    runSpacing: 8,
    children: [
      for (final v in [Level.mastered, Level.learning, Level.stuck, Level.unknown])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: levelColor(v, n: 1), borderRadius: BorderRadius.circular(6)),
            ),
            const SizedBox(width: 8),
            Text(levelLabel(v, lang), style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
    ],
  );
}

/// The grid itself: a fixed topic column and class column, and roll columns that pan sideways
/// together (drag anywhere on the cells or the header). Tap a roll number or a cell for that
/// roll's report; tap a topic for who is stuck and who has it.
class HeatGrid extends StatefulWidget {
  const HeatGrid({super.key, required this.items, required this.rolls, required this.lang});

  /// [Chapter] headers and [TopicRef] rows.
  final List<Object> items;
  final List<int> rolls;
  final Lang lang;

  static const rowHeight = 64.0, minCell = 44.0;

  @override
  State<HeatGrid> createState() => _HeatGridState();
}

class _HeatGridState extends State<HeatGrid> {
  final offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    offset.dispose();
    super.dispose();
  }

  void _openRoll(int r) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RollReportScreen(roll: r)));

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), m = s.mastery, l = widget.lang, text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) {
        final labelW = context.narrow ? min(340.0, box.maxWidth * 0.36) : 520.0, classW = 120.0;
        final view = max(0.0, box.maxWidth - labelW - classW);
        final n = widget.rolls.length;
        final cell = max(HeatGrid.minCell, n == 0 ? HeatGrid.minCell : view / n);
        final maxOff = max(0.0, cell * n - view);
        if (offset.value > maxOff) offset.value = maxOff;
        int? rollAt(double x) {
          final i = ((x + offset.value) / cell).floor();
          return i >= 0 && i < n ? widget.rolls[i] : null;
        }

        Widget pan(Widget child, {required void Function(int roll) onTap}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: maxOff == 0 ? null : (d) => offset.value = (offset.value - d.delta.dx).clamp(0, maxOff),
          onTapUp: (d) {
            final r = rollAt(d.localPosition.dx);
            if (r != null) onTap(r);
          },
          child: child,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: HeatGrid.rowHeight,
              child: Row(
                children: [
                  SizedBox(width: labelW, child: Text(it('topic', l), style: text.bodyMedium)),
                  SizedBox(width: classW, child: Text(it('classCol', l), style: text.bodyMedium, textAlign: TextAlign.center)),
                  Expanded(
                    child: pan(
                      CustomPaint(key: const ValueKey('rollHeader'), size: Size.infinite, painter: _HeaderPainter(rolls: widget.rolls, cell: cell, offset: offset, color: text.bodyMedium!.color!)),
                      onTap: _openRoll,
                    ),
                  ),
                ],
              ),
            ),
            if (maxOff > 0)
              ValueListenableBuilder(
                valueListenable: offset,
                builder: (_, v, _) => Padding(
                  padding: EdgeInsets.only(left: labelW + classW),
                  child: LinearProgressIndicator(value: maxOff == 0 ? 0 : (v + view) / (cell * n), minHeight: 4),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.items.length,
                itemExtent: HeatGrid.rowHeight,
                itemBuilder: (context, i) {
                  final item = widget.items[i];
                  if (item is Chapter) {
                    return Container(
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${subjectName(item.subject, l)} · ${item.number}. ${item.title.t(l)}',
                        style: text.bodyLarge?.copyWith(color: Z.accent, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  final t = item as TopicRef, est = m.classTopic(t.id);
                  return Row(
                    key: ValueKey('row:${t.id}'),
                    children: [
                      SizedBox(
                        width: labelW,
                        child: InkWell(
                          key: ValueKey('topic:${t.id}'),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TopicInsightScreen(topicId: t.id))),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(t.topic.title.t(l), style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: classW,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: levelColor(est?.level ?? Level.unknown, n: est?.n ?? 0), borderRadius: BorderRadius.circular(20)),
                            child: Text(pct(est), style: zText(24).copyWith(color: Colors.white)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: pan(
                          CustomPaint(size: Size.infinite, painter: _CellsPainter(m: m, topicId: t.id, rolls: widget.rolls, cell: cell, offset: offset)),
                          onTap: _openRoll,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CellsPainter extends CustomPainter {
  _CellsPainter({required this.m, required this.topicId, required this.rolls, required this.cell, required this.offset}) : super(repaint: offset);
  final MasteryStore m;
  final String topicId;
  final List<int> rolls;
  final double cell;
  final ValueNotifier<double> offset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final first = max(0, (offset.value / cell).floor()), last = min(rolls.length - 1, ((offset.value + size.width) / cell).ceil());
    final paint = Paint();
    for (var i = first; i <= last; i++) {
      final e = m.rollTopic(rolls[i], topicId);
      paint.color = levelColor(e?.level ?? Level.unknown, n: e?.n ?? 0);
      final x = i * cell - offset.value;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 6, cell - 4, size.height - 12), const Radius.circular(6)), paint);
    }
  }

  @override
  bool shouldRepaint(_CellsPainter old) => true; // cheap, and the store may have changed
}

class _HeaderPainter extends CustomPainter {
  _HeaderPainter({required this.rolls, required this.cell, required this.offset, required this.color}) : super(repaint: offset);
  final List<int> rolls;
  final double cell;
  final ValueNotifier<double> offset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final first = max(0, (offset.value / cell).floor()), last = min(rolls.length - 1, ((offset.value + size.width) / cell).ceil());
    final every = cell >= 56 ? 1 : (cell >= 30 ? 2 : 5);
    for (var i = first; i <= last; i++) {
      if (rolls[i] % every != 0 && rolls[i] != 1) continue;
      final tp = TextPainter(
        text: TextSpan(text: '${rolls[i]}', style: zText(min(24, cell * 0.55 * every), FontWeight.w600).copyWith(color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * cell - offset.value + (cell - tp.width) / 2, (size.height - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_HeaderPainter old) => old.cell != cell || old.rolls.length != rolls.length || old.color != color;
}

Map<String, TopicRef> _topicIndex(Services s) => {for (final t in sectionTopics(s)) t.id: t};

/// One topic: the class estimate, who is stuck, learning and has it, buddies, and
/// "Teach this now".
class TopicInsightScreen extends StatelessWidget {
  const TopicInsightScreen({super.key, required this.topicId});
  final String topicId;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), m = s.mastery, l = s.config.lang, text = Theme.of(context).textTheme;
    final ref = _topicIndex(s)[topicId];
    final hit = s.lessonFor(topicId);
    final title = ref?.topic.title.t(l) ?? hit?.lesson.title.t(l) ?? topicId;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Z.tap + 16,
        leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(title, style: text.headlineLarge, overflow: TextOverflow.ellipsis),
      ),
      body: ListenableBuilder(
        listenable: m,
        builder: (context, _) {
          final est = m.classTopic(topicId);
          final rolls = sectionRolls(s);
          final learning = [
            for (final r in rolls)
              if (m.rollTopic(r, topicId)?.level == Level.learning) r,
          ];
          Widget group(String label, Level v, List<int> rs) => Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label (${rs.length})', style: text.headlineMedium?.copyWith(color: levelColor(v, n: 1))),
                const SizedBox(height: 8),
                if (rs.isEmpty) Text(it('nobody', l), style: text.bodyMedium),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final r in rs)
                      ActionChip(
                        key: ValueKey('roll:$r'),
                        label: Text('$r', style: zText(26)),
                        backgroundColor: levelColor(v, n: 1).withValues(alpha: 0.25),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RollReportScreen(roll: r))),
                      ),
                  ],
                ),
              ],
            ),
          );
          final pairs = m.buddies(topicId);
          return ListView(
            padding: EdgeInsets.all(context.narrow ? 24 : 40),
            children: [
              if (ref != null) Text('${subjectName(ref.subject, l)} · ${ref.chapter.title.t(l)}', style: text.bodyLarge?.copyWith(color: Z.accent)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${it('classCol', l)}: ${pct(est)}', style: text.displayLarge),
                  Text('${levelLabel(est?.level ?? Level.unknown, l)} · ${est?.n ?? 0} ${it('answers', l)}', style: text.bodyLarge),
                ],
              ),
              const SizedBox(height: 24),
              BigButton(
                key: const ValueKey('teachNow'),
                icon: Icons.co_present_outlined,
                label: hit == null ? it('noLesson', l) : it('teachNow', l),
                onPressed: hit == null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LessonPlayerScreen(pack: hit.pack, lesson: hit.lesson))),
              ),
              const SizedBox(height: 32),
              group(it('stuck', l), Level.stuck, m.stuck(topicId)),
              group(it('learning', l), Level.learning, learning),
              group(it('mastered', l), Level.mastered, m.strong(topicId)),
              if (pairs.isNotEmpty) ...[
                Text(it('buddies', l), style: text.headlineMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [for (final (a, b) in pairs) Chip(label: Text('${it('roll', l)} $a ${it('with', l)} $b', style: zText(26)))],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One roll number: overall, strong and weak topics, week-by-week trend, exam readiness, and a
/// practice sheet. Roll numbers only.
class RollReportScreen extends StatelessWidget {
  const RollReportScreen({super.key, required this.roll});
  final int roll;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), m = s.mastery, l = s.config.lang, text = Theme.of(context).textTheme;
    final index = _topicIndex(s);
    String name(String id) => index[id]?.topic.title.t(l) ?? s.lessonFor(id)?.lesson.title.t(l) ?? id;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Z.tap + 16,
        leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('${it('roll', l)} $roll', style: text.headlineLarge),
        actions: [
          IconButton(
            key: const ValueKey('practiceSheet'),
            iconSize: 56,
            tooltip: it('practiceSheet', l),
            icon: const Icon(Icons.print_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WorksheetScreen(roll: roll))),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListenableBuilder(
        listenable: m,
        builder: (context, _) {
          final mine = m.rollTopics(roll).entries.toList()..sort((a, b) => b.value.p.compareTo(a.value.p));
          final strong = [for (final e in mine) if (e.value.level == Level.mastered) e];
          final weak = [for (final e in mine.reversed) if (e.value.level == Level.stuck || e.value.level == Level.learning) e];
          final trend = weeklyTrend(m.responses, roll: roll);
          final overall = m.rollOverall(roll);
          Widget topicList(String label, List<MapEntry<String, Estimate>> es) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: text.headlineMedium?.copyWith(color: Z.accent)),
              const SizedBox(height: 8),
              if (es.isEmpty) Text(it('nobody', l), style: text.bodyMedium),
              for (final e in es.take(8))
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TopicInsightScreen(topicId: e.key))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(width: 20, height: 20, decoration: BoxDecoration(color: levelColor(e.value.level, n: e.value.n), shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(name(e.key), style: text.bodyLarge, overflow: TextOverflow.ellipsis)),
                        Text(pct(e.value), style: text.bodyLarge),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          );
          final lists = [topicList(it('weakTopics', l), weak), topicList(it('strongTopics', l), strong)];
          return ListView(
            padding: EdgeInsets.all(context.narrow ? 24 : 40),
            children: [
              if (mine.isEmpty) Text(it('noAnswersYet', l), style: text.headlineMedium) else Text('${it('overall', l)}: ${overall == null ? '–' : '${(overall * 100).round()}%'} · ${mine.length} ${it('topicsWithAnswers', l)}', style: text.headlineMedium),
              const SizedBox(height: 24),
              if (context.portrait)
                ...lists
              else
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: lists[0]), const SizedBox(width: 40), Expanded(child: lists[1])]),
              Text(it('trend', l), style: text.headlineMedium?.copyWith(color: Z.accent)),
              const SizedBox(height: 12),
              TrendBars(points: trend, lang: l),
              const SizedBox(height: 32),
              Text(it('examReadiness', l), style: text.headlineMedium?.copyWith(color: Z.accent)),
              const SizedBox(height: 12),
              ReadinessList(roll: roll),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: BigButton(
                  icon: Icons.print_outlined,
                  label: it('practiceSheet', l),
                  filled: false,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WorksheetScreen(roll: roll))),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Share right per week, as bars (oldest left).
class TrendBars extends StatelessWidget {
  const TrendBars({super.key, required this.points, required this.lang});
  final List<WeekPoint> points;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (points.isEmpty) return Text(it('noAnswersYet', lang), style: text.bodyMedium);
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${(p.score * 100).round()}%', style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.clip),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: max(0.04, p.score),
                        child: Container(decoration: BoxDecoration(color: levelColor(p.total < 2 ? Level.unknown : (p.score >= 0.75 ? Level.mastered : p.score >= 0.5 ? Level.learning : Level.stuck), n: p.total), borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${p.weekStart.day}/${p.weekStart.month}', style: text.bodyMedium?.copyWith(fontSize: 20), maxLines: 1, overflow: TextOverflow.clip),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
