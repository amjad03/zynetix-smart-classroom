import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/strings.dart' show subjectName;
import '../../engine/model.dart';
import 'help.dart';
import 'kit.dart';
import 'lesson.dart';
import 'shell.dart';
import 'today.dart' show blockIcon, blockTitle;

enum LibKind { model, lab, sim, explorer }

/// One thing in the library: a block of a lesson that can go on the board by itself.
class LibItem {
  LibItem(this.kind, this.pack, this.lesson, this.block);
  final LibKind kind;
  final InstalledPack pack;
  final Lesson lesson;
  final Block block;
}

LibKind? libKind(BlockType t) => switch (t) {
  BlockType.model3d => LibKind.model,
  BlockType.virtualLab => LibKind.lab,
  BlockType.simulation => LibKind.sim,
  BlockType.interactive => LibKind.explorer,
  _ => null,
};

/// Every 3D model, virtual lab, simulation and interactive explainer in the installed lessons.
List<LibItem> libraryItems(Services s) => [
  for (final p in s.store.packs)
    for (final lesson in p.lessons.values)
      for (final b in lesson.blocks)
        if (libKind(b.type) case final k? when b.forBoard(s.config.board)) LibItem(k, p, lesson, b),
];

/// Puts one item on the board, full screen, on its own.
Future<void> putOnBoard(BuildContext context, LibItem it) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => SimpleLessonScreen(
      pack: it.pack,
      lesson: Lesson(id: '${it.lesson.id}#${it.block.id}', chapterId: it.lesson.chapterId, topicId: it.lesson.topicId, title: it.lesson.title, minutes: 5, blocks: [it.block]),
      preview: true,
    ),
  ),
);

/// Library: 3D models, virtual labs, simulations and interactive explainers from every
/// installed chapter, with Put on board. All of it works offline.
class LibraryView extends StatefulWidget {
  const LibraryView({super.key});
  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  LibKind? kind = LibKind.model;
  String? subject;
  final _q = TextEditingController();
  List<LibItem>? _all;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final s = ServicesScope.of(context);
      final phone = usePhoneLayout(context);
      final all = _all ??= libraryItems(s);
      final q = _q.text.trim().toLowerCase();
      final items = [
        for (final it in all)
          if ((kind == null || it.kind == kind) && (subject == null || it.pack.chapter.subject == subject) && (q.isEmpty || '${blockTitle(it.block, Lang.en)} ${blockTitle(it.block, Lang.kn)} ${it.pack.chapter.title.en} ${it.lesson.title.en}'.toLowerCase().contains(q))) it,
      ];
      int count(LibKind k) => all.where((it) => it.kind == k).length;
      final kinds = [
        (LibKind.model, Icons.view_in_ar_rounded, tr(l, '3D models', '3D ಮಾದರಿಗಳು'), S.butter),
        (LibKind.lab, Icons.science_rounded, tr(l, 'Virtual labs', 'ವರ್ಚುವಲ್ ಲ್ಯಾಬ್'), S.mint),
        (LibKind.sim, Icons.animation_rounded, tr(l, 'Simulations', 'ಸಿಮ್ಯುಲೇಶನ್'), S.sky),
        (LibKind.explorer, Icons.touch_app_rounded, tr(l, 'Interactive explainers', 'ಸಂವಾದಾತ್ಮಕ ವಿವರಣೆ'), S.lavender),
      ];
      final bg = {for (final k in kinds) k.$1: k.$4};
      final cols = phone ? 1 : 3;
      return CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader(
              crumb: tr(l, '${all.length} things to put on the board', 'ಬೋರ್ಡ್‌ಗೆ ${all.length} ವಸ್ತುಗಳು'),
              title: tr(l, 'Library', 'ಗ್ರಂಥಾಲಯ'),
              help: () => const HelpInfo(next: L10n('Pick a kind, find what you want, then tap Put on board.', 'ಪ್ರಕಾರ ಆರಿಸಿ, ಬೇಕಾದದ್ದನ್ನು ಹುಡುಕಿ, “ಬೋರ್ಡ್‌ಗೆ ಹಾಕಿ” ಒತ್ತಿ.')),
              trailing: [if (!phone) offlineTag(l)],
            ),
            const SizedBox(height: 28),
            Wrap(spacing: 16, runSpacing: 16, children: [
              for (final (k, ic, t, _) in kinds)
                Press(key: ValueKey('kind-${k.name}'), onTap: () => setState(() => kind = kind == k ? null : k), child: Tag('$t · ${count(k)}', icon: ic, bg: kind == k ? S.ink : S.mist, fg: kind == k ? Colors.white : S.ink, size: 30)),
            ]),
            const SizedBox(height: 20),
            Wrap(spacing: 14, runSpacing: 14, children: [
              Press(onTap: () => setState(() => subject = null), child: Tag(tr(l, 'All subjects', 'ಎಲ್ಲಾ ವಿಷಯಗಳು'), bg: subject == null ? S.violet : S.soft, fg: subject == null ? Colors.white : S.violet, size: 26)),
              for (final sub in {for (final it in all) it.pack.chapter.subject})
                Press(key: ValueKey('libsub-$sub'), onTap: () => setState(() => subject = sub), child: Tag(subjectName(sub, l), bg: subject == sub ? S.violet : S.soft, fg: subject == sub ? Colors.white : S.violet, size: 26)),
            ]),
            const SizedBox(height: 24),
            SizedBox(width: phone ? double.infinity : 1200, child: TextField(
              key: const ValueKey('libSearch'),
              controller: _q,
              onChanged: (_) => setState(() {}),
              style: tx(36, c: S.ink),
              decoration: InputDecoration(
                hintText: tr(l, 'Search: pendulum, heart, prism…', 'ಹುಡುಕಿ: ಲೋಲಕ, ಹೃದಯ…'),
                hintStyle: tx(36, c: S.muted),
                prefixIcon: const Icon(Icons.search_rounded, size: 48, color: S.muted),
                filled: true,
                fillColor: S.mist,
                contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
              ),
            )),
            const SizedBox(height: 36),
            if (items.isEmpty) Text(tr(l, 'Nothing found. Try another word or kind.', 'ಏನೂ ಸಿಗಲಿಲ್ಲ. ಬೇರೆ ಪದ ಪ್ರಯತ್ನಿಸಿ.'), style: tx(36, c: S.muted)),
          ]),
        ),
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 32, crossAxisSpacing: 32, mainAxisExtent: phone ? 380 : 440),
          delegate: SliverChildBuilderDelegate(
            childCount: items.length,
            (context, i) {
              final it = items[i];
              return Container(
                key: ValueKey('lib-${it.lesson.id}-${it.block.id}'),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(color: bg[it.kind], borderRadius: BorderRadius.circular(44)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 96, height: 96, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)), child: Icon(blockIcon(it.block.type), size: 54, color: S.ink)),
                    const SizedBox(width: 20),
                    Expanded(child: Text('${subjectName(it.pack.chapter.subject, l)} · ${it.pack.chapter.title.t(l)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(26, c: S.cardText, w: FontWeight.w500))),
                  ]),
                  const Spacer(),
                  Flexible(child: Text(blockTitle(it.block, l), maxLines: 2, overflow: TextOverflow.ellipsis, style: hd(46, l: l))),
                  const SizedBox(height: 20),
                  ZxButton(tr(l, 'Put on board', 'ಬೋರ್ಡ್‌ಗೆ ಹಾಕಿ'), key: ValueKey('put-${it.block.id}'), icon: Icons.cast_rounded, bg: S.ink, height: 100, size: 30, onTap: () => putOnBoard(context, it)),
                ]),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ]);
    },
  );
}
