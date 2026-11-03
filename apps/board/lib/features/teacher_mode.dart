import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';
import 'home.dart';

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
    final subjects = s.syllabus.keys.toList();
    final taught = s.config.taught.toSet();
    return DefaultTabController(
      length: subjects.length,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: Z.tap + 16,
          leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          title: Text(tr('teacherMode', l), style: Theme.of(context).textTheme.headlineLarge),
          actions: [
            SegmentedButton<String>(
              style: SegmentedButton.styleFrom(minimumSize: const Size(180, Z.tap - 16), textStyle: const TextStyle(fontSize: 28)),
              segments: const [ButtonSegment(value: 'puc1', label: Text('1st PUC')), ButtonSegment(value: 'puc2', label: Text('2nd PUC'))],
              selected: {year},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _year = v.first),
            ),
            const SizedBox(width: 24),
          ],
          bottom: TabBar(
            labelStyle: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 32),
            tabs: [for (final sub in subjects) Tab(height: Z.tap, text: subjectName(sub, l))],
          ),
        ),
        body: TabBarView(children: [
          for (final sub in subjects)
            ListView(
              padding: const EdgeInsets.all(32),
              children: [
                for (final ch in s.syllabus[sub]?[year] ?? const <Chapter>[]) _ChapterTile(chapter: ch, lang: l, taught: taught),
              ],
            ),
        ]),
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
    final s = ServicesScope.of(context), text = Theme.of(context).textTheme;
    final pack = s.store.byChapter(chapter.id);
    final head = Text('${chapter.number}. ${chapter.title.t(lang)}', style: text.headlineMedium?.copyWith(color: pack == null ? Theme.of(context).disabledColor : null));
    if (pack == null) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [Expanded(child: head), Text(tr('comingSoon', lang), style: text.bodyMedium)]));
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head,
          const SizedBox(height: 12),
          for (final t in pack.chapter.topics)
            if (pack.lessons[t.id] case final lesson?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(taught.contains(t.id) ? Icons.check_circle : Icons.radio_button_unchecked, size: 40, color: taught.contains(t.id) ? Z.correct : null),
                  const SizedBox(width: 16),
                  Expanded(child: Text(t.title.t(lang), style: text.bodyLarge)),
                  BigButton(key: ValueKey('start:${t.id}'), icon: Icons.play_arrow, label: tr('start', lang), onPressed: () => openLesson(context, pack, lesson)),
                ]),
              ),
        ]),
      ),
    );
  }
}
