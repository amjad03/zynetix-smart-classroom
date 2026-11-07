import '../../core/services.dart';
import '../../core/strings.dart' show subjectName;
import '../../engine/model.dart';
import 'school.dart';

/// The class to teach now: the period from the timetable (when the school has set one), its
/// subject, and the lesson to open — the one left part-way, else the next untaught topic.
class ClassNow {
  ClassNow({required this.subject, this.period, this.pack, this.lesson, this.topicNo = 0, this.topicCount = 0, this.minutesLeft, this.lastStep = 0, this.isNow = false});
  final String subject;
  final Period? period;
  final InstalledPack? pack;
  final Lesson? lesson;
  final int topicNo, topicCount, lastStep;
  final int? minutesLeft;

  /// The period is on now (not later today).
  final bool isNow;

  bool get hasLesson => pack != null && lesson != null;
  Chapter? get chapter => pack?.chapter;
}

/// "1st PUC · A · PCMB" → "1st PUC A".
String shortSection(String label) {
  final p = label.split(' · ');
  return p.length >= 2 ? '${p[0]} ${p[1]}' : label;
}

/// "1st PUC A · Physics" for a period (its own class when it names one).
String classLine(Services s, String subject, Lang l, {Period? period}) {
  final cls = (period?.label.isNotEmpty ?? false) ? period!.label : shortSection(s.config.sectionLabel);
  return '$cls · ${subjectName(subject, l)}';
}

/// The lesson to continue in [subject]: a topic left part-way (its step saved, not finished),
/// else the next untaught topic after the one taught last, in syllabus order.
({InstalledPack pack, Lesson lesson})? nextInSubject(Services s, String subject) {
  final taught = s.config.taught.toSet();
  final years = [s.config.year, s.config.year == 'puc1' ? 'puc2' : 'puc1'];
  final order = [for (final y in years) ...s.chapters(subject, y)];
  // Left part-way in the last class of this subject.
  for (final r in s.school.history) {
    if (r.subject != subject) continue;
    if (!taught.contains(r.topicId)) {
      final hit = s.lessonFor(r.topicId);
      if (hit != null) return hit;
    }
    break;
  }
  var start = 0;
  for (final t in s.config.taught.reversed) {
    final i = order.indexWhere((c) => t.startsWith('${c.id}.'));
    if (i >= 0) {
      start = i;
      break;
    }
  }
  for (final ch in [...order.skip(start), ...order.take(start)]) {
    final p = s.store.byChapter(ch.id);
    if (p == null) continue;
    for (final t in p.chapter.topicsFor(s.config.board)) {
      final l = p.lessons[t.id];
      if (l != null && !taught.contains(t.id)) return (pack: p, lesson: l);
    }
  }
  // Everything taught: the first lesson of the subject, to revise.
  for (final ch in order) {
    final p = s.store.byChapter(ch.id);
    final t = p?.chapter.topicsFor(s.config.board).where((t) => p.lessons.containsKey(t.id)).firstOrNull;
    if (p != null && t != null) return (pack: p, lesson: p.lessons[t.id]!);
  }
  return null;
}

/// What Home's big card shows for the teacher signed in.
ClassNow classNow(Services s) {
  final now = s.clock();
  final school = s.school;
  final p = school.classNow(teacherId: school.current?.id, at: now);
  final mins = now.hour * 60 + now.minute;
  final isNow = p != null && p.startMin <= mins && mins < p.endMin;
  ({InstalledPack pack, Lesson lesson})? hit;
  String subject;
  if (p != null) {
    subject = p.subject;
    hit = nextInSubject(s, subject);
  } else {
    hit = s.nextTopic();
    subject = hit?.pack.chapter.subject ?? (s.subjects.isEmpty ? 'physics' : s.subjects.first);
    // The subject of the last class this teacher took, when there is one.
    final mine = school.history.where((r) => r.teacherId == school.current?.id).firstOrNull;
    if (mine != null && s.subjects.contains(mine.subject)) {
      subject = mine.subject;
      hit = nextInSubject(s, subject) ?? hit;
    }
  }
  final topics = hit?.pack.chapter.topicsFor(s.config.board) ?? const <Topic>[];
  final no = hit == null ? 0 : topics.indexWhere((t) => t.id == hit!.lesson.topicId) + 1;
  return ClassNow(
    subject: subject,
    period: p,
    pack: hit?.pack,
    lesson: hit?.lesson,
    topicNo: no,
    topicCount: topics.length,
    minutesLeft: isNow ? p.endMin - mins : null,
    lastStep: hit == null ? 0 : school.stepFor(hit.lesson.topicId),
    isNow: isNow,
  );
}
