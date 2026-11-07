import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';
import 'player.dart' show openLesson;
import 'smartboard.dart';

/// Subject tabs; under each, the section's chapters with their topics already open, so a lesson
/// is three taps from Home: Teacher Mode → subject → Start.
class TeacherModeScreen extends StatefulWidget {
  const TeacherModeScreen({super.key});
  @override
  State<TeacherModeScreen> createState() => _TeacherModeScreenState();
}

class _TeacherModeScreenState extends State<TeacherModeScreen> {
  String? _year;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), l = s.config.lang;
    final year = _year ?? s.config.year;
    final subjects = s.subjects;
    final taught = s.config.taught.toSet();
    final narrow = context.narrow, pad = narrow ? 20.0 : 32.0;
    final phone = narrow && context.portrait;
    final years = ZSegmented<String>(
      expand: phone,
      height: 68,
      fontSize: narrow ? 24 : 28,
      items: [for (final y in const ['puc1', 'puc2']) (y, yearLabel(y, s.config.board, l), ValueKey('year-$y'))],
      selected: year,
      onChanged: (v) => setState(() => _year = v),
    );
    return DefaultTabController(
      length: subjects.length,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ZTopBar(
                  leading: ZIconSquare(icon: Icons.arrow_back, tooltip: tr('back', l), onPressed: () => Navigator.pop(context)),
                  title: tr('teacherMode', l),
                  trailing: [if (!phone) years, const SmartboardButton()],
                ),
                if (phone) ...[SizedBox(height: pad), years],
                SizedBox(height: pad),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
                  child: TabBar(
                    isScrollable: subjects.length > 5 || narrow,
                    tabAlignment: subjects.length > 5 || narrow ? TabAlignment.start : TabAlignment.fill,
                    labelStyle: zText(30, FontWeight.w600),
                    unselectedLabelStyle: zText(30, FontWeight.w500),
                    labelColor: Z.primary,
                    unselectedLabelColor: Z.ink2,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(color: Z.tagBg, borderRadius: BorderRadius.circular(Z.radius)),
                    splashBorderRadius: BorderRadius.circular(Z.radius),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 36),
                    tabs: [
                      for (final sub in subjects)
                        Tab(
                          height: 80,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(subjectIcon(sub), size: 30), const SizedBox(width: 12), Flexible(child: Text(subjectName(sub, l), overflow: TextOverflow.ellipsis))]),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final sub in subjects)
                        ListView(
                          padding: EdgeInsets.only(top: pad, bottom: pad),
                          children: [for (final ch in s.chapters(sub, year)) _ChapterTile(chapter: ch, lang: l, taught: taught)],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter, required this.lang, required this.taught});
  final Chapter chapter;
  final Lang lang;
  final Set<String> taught;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final narrow = context.narrow;
    final pack = s.store.byChapter(chapter.id);
    final head = Text('${chapter.number}. ${chapter.title.t(lang)}', style: zTitle(narrow ? 34 : 38).copyWith(color: pack == null ? Z.faint : Z.ink));
    if (pack == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: narrow ? 28 : 44, vertical: 20),
        child: Row(
          children: [
            Expanded(child: head),
            const SizedBox(width: 16),
            ZTag.neutral(tr('comingSoon', lang)),
          ],
        ),
      );
    }
    final topics = [
      for (final t in pack.chapter.topicsFor(s.config.board))
        if (pack.lessons[t.id] case final lesson?) (t, lesson),
    ];
    final nextUp = topics.where((e) => !taught.contains(e.$1.id)).firstOrNull?.$1.id;
    final done = topics.where((e) => taught.contains(e.$1.id)).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.fromLTRB(narrow ? 28 : 44, narrow ? 24 : 36, narrow ? 20 : 32, narrow ? 16 : 28),
      decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: head),
              if (done > 0) ...[const SizedBox(width: 16), Text('$done / ${topics.length} ${tr('taught', lang).toLowerCase()}', style: zText(26, FontWeight.w500).copyWith(color: Z.muted))],
            ],
          ),
          const SizedBox(height: 16),
          for (final (i, (t, lesson)) in topics.indexed) ...[
            if (i > 0) const Divider(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: taught.contains(t.id) ? Z.correctBg : Z.segTrack, shape: BoxShape.circle),
                    child: taught.contains(t.id)
                        ? const Icon(Icons.check, size: 32, color: Z.correct)
                        : Center(child: Text('${i + 1}', style: zText(24, FontWeight.w600).copyWith(color: Z.ink2))),
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: Text(t.title.t(lang), style: zText(narrow ? 28 : 32, t.id == nextUp ? FontWeight.w600 : FontWeight.w400).copyWith(color: taught.contains(t.id) ? Z.muted : Z.ink))),
                  const SizedBox(width: 16),
                  BigButton(collapse: true, key: ValueKey('start:${t.id}'), icon: Icons.play_arrow, label: tr('start', lang), filled: t.id == nextUp, onPressed: () => openLesson(context, pack, lesson)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
