import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One answer from the class: a roll number's (or, when nobody is named, the whole class's)
/// response to one question. Roll numbers only, never names.
class Response {
  Response({this.roll, required this.questionId, required this.topicId, required this.chapterId, required this.correct, required this.source, required this.at});

  /// null when the class answered together (monitor taps, a show of hands without names).
  final int? roll;
  final String questionId, topicId, chapterId;
  final bool correct;

  /// Where it came from: roll_call, team, hands, phone, paper, monitor, exam.
  final String source;
  final DateTime at;

  Map<String, dynamic> toJson() => {'roll': ?roll, 'q': questionId, 't': topicId, 'c': chapterId, 'ok': correct, 's': source, 'at': at.toUtc().toIso8601String()};

  factory Response.fromJson(Map<String, dynamic> j) => Response(
    roll: j['roll'] as int?,
    questionId: j['q'] as String,
    topicId: j['t'] as String,
    chapterId: j['c'] as String,
    correct: j['ok'] as bool,
    source: j['s'] as String,
    at: DateTime.parse(j['at'] as String),
  );
}

/// How well something is known: an estimate in 0..1 and how many answers it rests on.
class Estimate {
  const Estimate(this.p, this.n);
  final double p;
  final int n;

  /// Mastered, learning or stuck, for colours and lists. With fewer than 2 answers: unknown.
  Level get level => n < 2 ? Level.unknown : (p >= 0.75 ? Level.mastered : (p >= 0.5 ? Level.learning : Level.stuck));
}

enum Level { unknown, stuck, learning, mastered }

/// What this section knows, topic by topic and roll number by roll number, built from every
/// answer given on this board. Kept on the board (works offline) in one JSON-lines file.
///
/// The estimate is a moving average that weights recent answers more (each answer moves it
/// [rate] of the way towards 1 or 0, starting from 0.5), so a student who has caught up is not
/// held back by old mistakes.
class MasteryStore extends ChangeNotifier {
  MasteryStore({this.file, DateTime Function()? now}) : now = now ?? DateTime.now {
    _load();
  }

  /// Where answers are kept; null keeps them in memory (tests, previews).
  final File? file;
  final DateTime Function() now;
  static const rate = 0.35;

  final List<Response> _all = [];
  final Map<int, Map<String, Estimate>> _byRoll = {};
  final Map<String, Estimate> _byTopic = {};

  List<Response> get responses => List.unmodifiable(_all);

  void _load() {
    final f = file;
    if (f == null || !f.existsSync()) return;
    for (final line in f.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        _apply(Response.fromJson(jsonDecode(line) as Map<String, dynamic>));
      } catch (_) {} // a torn last line after a power cut: skip it
    }
  }

  static Estimate _step(Estimate? e, bool ok) {
    final p = e?.p ?? 0.5;
    return Estimate(p + rate * ((ok ? 1 : 0) - p), (e?.n ?? 0) + 1);
  }

  void _apply(Response r) {
    _all.add(r);
    _byTopic[r.topicId] = _step(_byTopic[r.topicId], r.correct);
    if (r.roll != null) {
      final m = _byRoll.putIfAbsent(r.roll!, () => {});
      m[r.topicId] = _step(m[r.topicId], r.correct);
    }
  }

  /// Records answers and saves them.
  void recordAll(Iterable<Response> rs) {
    final list = rs.toList();
    if (list.isEmpty) return;
    list.forEach(_apply);
    file?.writeAsStringSync(list.map((r) => '${jsonEncode(r.toJson())}\n').join(), mode: FileMode.append, flush: true);
    notifyListeners();
  }

  void record(Response r) => recordAll([r]);

  /// The class on a topic (every answer, named or not); null if never asked.
  Estimate? classTopic(String topicId) => _byTopic[topicId];

  /// One roll number on one topic; null if they have never answered on it.
  Estimate? rollTopic(int roll, String topicId) => _byRoll[roll]?[topicId];

  /// Every topic a roll number has answered on.
  Map<String, Estimate> rollTopics(int roll) => Map.unmodifiable(_byRoll[roll] ?? const {});

  /// Roll numbers with at least one named answer, in order.
  List<int> get rolls => _byRoll.keys.toList()..sort();

  /// Topics with any answers.
  Iterable<String> get topics => _byTopic.keys;

  /// Roll numbers stuck on a topic (2+ answers, estimate under 0.5), weakest first.
  List<int> stuck(String topicId) => _rank(topicId, (e) => e.level == Level.stuck);

  /// Roll numbers who have mastered a topic, strongest first.
  List<int> strong(String topicId) => _rank(topicId, (e) => e.level == Level.mastered).reversed.toList();

  List<int> _rank(String topicId, bool Function(Estimate) keep) {
    final hits = [
      for (final e in _byRoll.entries)
        if (e.value[topicId] case final est? when keep(est)) (e.key, est.p),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final h in hits) h.$1];
  }

  /// Weakest topics for the class (2+ answers), weakest first; optionally within some topics.
  List<String> weakTopics({int n = 5, bool Function(String topicId)? where}) {
    final list = [
      for (final e in _byTopic.entries)
        if (e.value.n >= 2 && e.value.p < 0.75 && (where?.call(e.key) ?? true)) e,
    ]..sort((a, b) => a.value.p.compareTo(b.value.p));
    return [for (final e in list.take(n)) e.key];
  }

  /// A roll number's average over the topics they have answered (or over [topicIds]).
  double? rollOverall(int roll, {Iterable<String>? topicIds}) {
    final m = _byRoll[roll];
    if (m == null) return null;
    final vals = [
      for (final t in topicIds ?? m.keys)
        if (m[t] != null) m[t]!.p,
    ];
    return vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;
  }

  /// Pairs for peer teaching on a topic: each stuck roll number with a strong one.
  List<(int stuck, int buddy)> buddies(String topicId) {
    final s = stuck(topicId), g = strong(topicId);
    if (g.isEmpty) return const [];
    return [for (var i = 0; i < s.length; i++) (s[i], g[i % g.length])];
  }
}
