import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'model.dart';

/// A teaching session (one topic, one section), logged with roll numbers only, never names.
/// Mirrors SessionLog in packages/lesson-schema.
class SessionRecorder {
  SessionRecorder({required Outbox outbox, required String sectionId, required String mode, required InstalledPack pack, required Lesson lesson, DateTime Function()? now})
    : this.raw(outbox: outbox, sectionId: sectionId, mode: mode, chapterId: lesson.chapterId, topicId: lesson.topicId, lessonId: lesson.id, packVersion: pack.version, now: now);

  /// A session that is not one lesson (Exam Practice): the caller names the chapter and topic.
  SessionRecorder.raw({
    required this.outbox,
    required this.sectionId,
    required this.mode,
    required String chapterId,
    required String topicId,
    required String lessonId,
    required String packVersion,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _log = {
         'id': const Uuid().v4(),
         'sectionId': sectionId,
         'mode': mode,
         'chapterId': chapterId,
         'topicId': topicId,
         'lessonId': lessonId,
         'packVersion': packVersion,
         'startedAt': (now ?? DateTime.now)().toUtc().toIso8601String(),
         'endedAt': null,
         'blocksShown': <String>[],
         'completed': false,
         'answers': <Map<String, dynamic>>[],
       };

  final Outbox outbox;
  final String sectionId, mode;
  final DateTime Function() _now;
  final Map<String, dynamic> _log;
  bool _closed = false;

  Map<String, dynamic> get log => _log;

  void shown(String blockId) {
    final l = _log['blocksShown'] as List<String>;
    if (!l.contains(blockId)) l.add(blockId);
  }

  void answer({required String questionId, required QuizMode mode, int? roll, int? team, required int? chosen, required bool correct}) {
    (_log['answers'] as List).add({
      'questionId': questionId,
      'mode': switch (mode) {
        QuizMode.monitor => 'monitor',
        QuizMode.rollCall => 'roll_call',
        QuizMode.team => 'team',
      },
      'roll': ?roll,
      'team': ?team,
      'chosen': chosen,
      'correct': correct,
      'at': _now().toUtc().toIso8601String(),
    });
  }

  void setPresent(int n) => _log['present'] = n;

  /// Writes the log to the outbox; safe to call more than once.
  void close({required bool completed}) {
    if (_closed) return;
    _closed = true;
    _log['endedAt'] = _now().toUtc().toIso8601String();
    _log['completed'] = completed;
    outbox.add(_log);
  }
}

/// Session logs waiting to be sent (one JSON per line). Sync removes the ones the API accepted.
class Outbox {
  Outbox(this.file);
  final File file;

  void add(Map<String, dynamic> log) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('${jsonEncode(log)}\n', mode: FileMode.append, flush: true);
  }

  List<Map<String, dynamic>> pending() => !file.existsSync()
      ? []
      : [
          for (final l in file.readAsLinesSync())
            if (l.trim().isNotEmpty) jsonDecode(l) as Map<String, dynamic>,
        ];

  void remove(Set<String> ids) {
    final keep = pending().where((l) => !ids.contains(l['id'])).toList();
    file.writeAsStringSync(keep.map((l) => '${jsonEncode(l)}\n').join(), flush: true);
  }
}
