import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../engine/mastery.dart';

/// One play of a challenge block: how many stars it earned and who played (a roll number, a
/// team, or the whole class). Roll numbers only, never names.
class ChallengeResult {
  ChallengeResult({
    required this.blockId,
    required this.lessonId,
    required this.topicId,
    required this.chapterId,
    required this.stars,
    required this.tries,
    required this.solved,
    required this.mode,
    this.roll,
    this.team,
    required this.at,
  });
  final String blockId, lessonId, topicId, chapterId;

  /// 0 (not solved) to 3.
  final int stars;
  final int tries;
  final bool solved;

  /// monitor, team or roll_call.
  final String mode;
  final int? roll, team;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'k': 'challenge',
    'b': blockId,
    'l': lessonId,
    't': topicId,
    'c': chapterId,
    'stars': stars,
    'tries': tries,
    'ok': solved,
    'm': mode,
    'roll': ?roll,
    'team': ?team,
    'at': at.toUtc().toIso8601String(),
  };

  factory ChallengeResult.fromJson(Map<String, dynamic> j) => ChallengeResult(
    blockId: j['b'] as String,
    lessonId: j['l'] as String,
    topicId: j['t'] as String,
    chapterId: j['c'] as String,
    stars: j['stars'] as int,
    tries: j['tries'] as int,
    solved: j['ok'] as bool,
    mode: j['m'] as String,
    roll: j['roll'] as int?,
    team: j['team'] as int?,
    at: DateTime.parse(j['at'] as String),
  );
}

/// One boss battle (a chapter test played as a game).
class BossResult {
  BossResult({required this.chapterId, required this.won, required this.correct, required this.asked, required this.at});
  final String chapterId;
  final bool won;
  final int correct, asked;
  final DateTime at;

  Map<String, dynamic> toJson() => {'k': 'boss', 'c': chapterId, 'won': won, 'ok': correct, 'n': asked, 'at': at.toUtc().toIso8601String()};

  factory BossResult.fromJson(Map<String, dynamic> j) =>
      BossResult(chapterId: j['c'] as String, won: j['won'] as bool, correct: j['ok'] as int, asked: j['n'] as int, at: DateTime.parse(j['at'] as String));
}

/// The section's game record (challenge results and boss battles), kept on the board in one
/// JSON-lines file next to the mastery store's, so it works offline and survives restarts.
/// Badges, streaks and points are computed from it and the mastery store (game_stats.dart).
class GameStore extends ChangeNotifier {
  GameStore({this.file}) {
    _load();
  }

  /// Where results are kept; null keeps them in memory (tests, previews).
  final File? file;

  final List<ChallengeResult> _challenges = [];
  final List<BossResult> _bosses = [];
  List<ChallengeResult> get challenges => List.unmodifiable(_challenges);
  List<BossResult> get bosses => List.unmodifiable(_bosses);

  static final _byMastery = Expando<GameStore>('game');

  /// The game store that belongs with [m]: `game.jsonl` beside its file (in memory when it has
  /// none). One per mastery store, so every screen sees the same results.
  static GameStore of(MasteryStore m) => _byMastery[m] ??= GameStore(file: m.file == null ? null : File('${m.file!.parent.path}/game.jsonl'));

  void _load() {
    final f = file;
    if (f == null || !f.existsSync()) return;
    for (final line in f.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final j = jsonDecode(line) as Map<String, dynamic>;
        if (j['k'] == 'challenge') _challenges.add(ChallengeResult.fromJson(j));
        if (j['k'] == 'boss') _bosses.add(BossResult.fromJson(j));
      } catch (_) {} // a torn last line after a power cut: skip it
    }
  }

  void _save(Map<String, dynamic> j) {
    final f = file;
    if (f == null) return;
    f.parent.createSync(recursive: true);
    f.writeAsStringSync('${jsonEncode(j)}\n', mode: FileMode.append, flush: true);
  }

  void recordChallenge(ChallengeResult r) {
    _challenges.add(r);
    _save(r.toJson());
    notifyListeners();
  }

  void recordBoss(BossResult r) {
    _bosses.add(r);
    _save(r.toJson());
    notifyListeners();
  }

  /// Best stars the class has earned on one challenge block (0 when never solved).
  int bestStars(String lessonId, String blockId) => _challenges.where((c) => c.lessonId == lessonId && c.blockId == blockId).fold(0, (a, c) => c.stars > a ? c.stars : a);

  /// Best challenge stars per topic.
  Map<String, int> get topicStars {
    final out = <String, int>{};
    for (final c in _challenges) {
      if (c.stars > (out[c.topicId] ?? 0)) out[c.topicId] = c.stars;
    }
    return out;
  }

  bool bossBeaten(String chapterId) => _bosses.any((b) => b.chapterId == chapterId && b.won);
}
