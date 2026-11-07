import 'package:flutter/material.dart';

import '../engine/model.dart';
import '../features/simple/kit.dart';
import 'lesson_steps.dart';
import 'live_objects.dart';

enum KitKind { model3d, lab, sim, explainer, video, exam }

/// One thing in the chapter's subject kit, with what "Put on board" does.
class KitItem {
  const KitItem(this.kind, this.ref, this.title, {this.topicId, this.block, this.questions = const [], this.online = false});
  final KitKind kind;

  /// The model, lab or simulation id ([simRef] for a simulation).
  final String ref;
  final L10n title;
  final String? topicId;
  final Block? block;
  final List<Question> questions;

  /// Needs the internet (concept videos stream from Zynetix School).
  final bool online;

  String get key => '${kind.name}:$ref';
}

L10n kitKindName(KitKind k) => switch (k) {
  KitKind.model3d => const L10n('3D model', '3D ಮಾದರಿ'),
  KitKind.lab => const L10n('Virtual lab', 'ವರ್ಚುವಲ್ ಲ್ಯಾಬ್'),
  KitKind.sim => const L10n('Simulation', 'ಸಿಮ್ಯುಲೇಶನ್'),
  KitKind.explainer => const L10n('Explainer', 'ವಿವರಣೆ'),
  KitKind.video => const L10n('Concept video · needs internet', 'ಪರಿಕಲ್ಪನಾ ವೀಡಿಯೊ · ಇಂಟರ್ನೆಟ್ ಬೇಕು'),
  KitKind.exam => const L10n('Exam questions', 'ಪರೀಕ್ಷಾ ಪ್ರಶ್ನೆಗಳು'),
};

IconData kitIcon(KitKind k) => switch (k) {
  KitKind.model3d => Icons.view_in_ar_rounded,
  KitKind.lab => Icons.science_outlined,
  KitKind.sim => Icons.play_circle_outline_rounded,
  KitKind.explainer => Icons.menu_book_rounded,
  KitKind.video => Icons.movie_outlined,
  KitKind.exam => Icons.quiz_outlined,
};

Color kitColor(KitKind k) => switch (k) {
  KitKind.model3d => S.lavender,
  KitKind.lab => S.mint,
  KitKind.sim => S.sky,
  KitKind.explainer => S.peach,
  KitKind.video => S.butter,
  KitKind.exam => S.pink,
};

/// The chapter's kit, read from its installed pack: every 3D model, lab and simulation its
/// lessons use, the concept explainers, and the board-exam questions. All offline except the
/// concept videos, which are labelled as needing the internet.
List<KitItem> subjectKit(InstalledPack pack, {String board = 'kar_pu'}) {
  final out = <KitItem>[];
  final seen = <String>{};
  void add(KitItem i) {
    if (seen.add(i.key)) out.add(i);
  }

  final lessons = pack.lessons.values.toList()..sort((a, b) => a.topicId.compareTo(b.topicId));
  for (final lesson in lessons) {
    for (final b in lesson.blocks.where((b) => b.forBoard(board))) {
      final name = b.title ?? b.maybe('heading') ?? b.maybe('caption');
      switch (b.type) {
        case BlockType.model3d when b.s('modelId') != null:
          add(KitItem(KitKind.model3d, b.s('modelId')!, name ?? L10n(_pretty(b.s('modelId')!)), topicId: lesson.topicId, block: b));
        case BlockType.virtualLab when b.s('labId') != null:
          add(KitItem(KitKind.lab, b.s('labId')!, name ?? L10n(_pretty(b.s('labId')!)), topicId: lesson.topicId, block: b));
        case BlockType.simulation when b.s('simId') != null:
          add(KitItem(KitKind.sim, simRef(pack.chapter.id, lesson.topicId, b.id), name ?? L10n(_pretty(b.s('simId')!)), topicId: lesson.topicId, block: b));
        case BlockType.concept:
          add(KitItem(KitKind.explainer, '${lesson.topicId}|${b.id}', name ?? lesson.title, topicId: lesson.topicId, block: b));
        default:
      }
    }
  }
  final exam = [
    for (final q in pack.questions.values)
      if (q.exams.isNotEmpty || q.pyqYear != null) q,
  ];
  if (exam.isNotEmpty) {
    final n = exam.length.clamp(1, 6);
    add(KitItem(KitKind.exam, 'exam', L10n('$n board-exam questions', '$n ಬೋರ್ಡ್ ಪರೀಕ್ಷಾ ಪ್ರಶ್ನೆಗಳು'), questions: exam.take(6).toList()));
  }
  add(KitItem(KitKind.video, 'video', L10n('${pack.chapter.title.en} · Zynetix School', '${pack.chapter.title.t(Lang.kn)} · ಜೈನೆಟಿಕ್ಸ್ ಸ್ಕೂಲ್'), online: true));
  return out;
}

String _pretty(String id) {
  final s = id.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  return s.isEmpty ? id : s[0].toUpperCase() + s.substring(1);
}

/// The step for a kit explainer (a concept block shown as a page).
LessonStep? explainerStep(InstalledPack pack, KitItem i) {
  final parts = i.ref.split('|');
  final lesson = pack.lessons[parts.first];
  final idx = lesson?.blocks.indexWhere((b) => b.id == parts.last) ?? -1;
  if (lesson == null || idx < 0) return null;
  return LessonStep(idx, lesson.blocks[idx], i.title, 5);
}
