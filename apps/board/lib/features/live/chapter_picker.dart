import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import 'strings.dart';

/// A chapter test: the first [count] questions of the chapter's pack, in the pack's order, so the
/// same chapter and size always give the same test (the paper the class wrote).
List<Question> chapterQuestions(InstalledPack pack, {int count = 10}) => pack.questions.values.take(count).toList();

/// The installed chapters for the section's subjects and curriculum, by subject, in syllabus order.
Map<String, List<InstalledPack>> installedChapters(Services s) {
  final out = <String, List<InstalledPack>>{};
  for (final p in s.store.packs) {
    final c = p.chapter;
    if (!s.subjects.contains(c.subject) || !c.forBoard(s.config.board) || p.questions.isEmpty) continue;
    (out[c.subject] ??= []).add(p);
  }
  for (final l in out.values) {
    l.sort((a, b) => a.chapter.year != b.chapter.year ? a.chapter.year.compareTo(b.chapter.year) : a.chapter.number.compareTo(b.chapter.number));
  }
  return {
    for (final sub in s.subjects)
      if (out[sub] != null) sub: out[sub]!,
  };
}

/// Pick a subject, the test size and a chapter; [onPick] gets the chapter and its questions.
class ChapterTestPicker extends StatefulWidget {
  const ChapterTestPicker({super.key, required this.onPick, this.initialCount = 10});
  final void Function(InstalledPack pack, List<Question> questions) onPick;
  final int initialCount;

  @override
  State<ChapterTestPicker> createState() => _ChapterTestPickerState();
}

class _ChapterTestPickerState extends State<ChapterTestPicker> {
  String? subject;
  late int count = widget.initialCount;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), l = s.config.lang, text = Theme.of(context).textTheme;
    final bySubject = installedChapters(s);
    if (bySubject.isEmpty) return Center(child: Text(ltr('noPacks', l), style: text.headlineMedium, textAlign: TextAlign.center));
    final sub = bySubject.containsKey(subject) ? subject! : bySubject.keys.first;
    final list = bySubject[sub]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            style: SegmentedButton.styleFrom(minimumSize: const Size(180, Z.tap - 8), textStyle: zText(context.narrow ? 26 : 30)),
            segments: [for (final x in bySubject.keys) ButtonSegment(value: x, label: Text(subjectName(x, l)))],
            selected: {sub},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => subject = v.first),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          children: [
            Text(ltr('testSize', l), style: text.bodyLarge),
            IconButton.filledTonal(key: const ValueKey('countMinus'), iconSize: 48, onPressed: count > 5 ? () => setState(() => count -= 5) : null, icon: const Icon(Icons.remove)),
            Text('$count', key: const ValueKey('testCount'), style: text.headlineLarge),
            IconButton.filledTonal(key: const ValueKey('countPlus'), iconSize: 48, onPressed: count < 30 ? () => setState(() => count += 5) : null, icon: const Icon(Icons.add)),
          ],
        ),
        const SizedBox(height: 12),
        Text(ltr('chooseTest', l), style: text.bodyLarge?.copyWith(color: Z.muted)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final p in list)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                    key: ValueKey('chapter:${p.chapter.id}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => widget.onPick(p, chapterQuestions(p, count: count)),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: Z.tap),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${yearLabel(p.chapter.year, s.config.board, l)} · ${p.chapter.number}. ${p.chapter.title.t(l)}', style: text.headlineMedium?.copyWith(fontSize: 34), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 12),
                            Text('${p.questions.length < count ? p.questions.length : count} ${ltr('questionsCount', l)}', style: text.bodyMedium),
                            const SizedBox(width: 12),
                            const Icon(Icons.play_circle_fill, size: 56, color: Z.accent),
                          ],
                        ),
                      ),
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
