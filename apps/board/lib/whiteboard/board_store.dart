import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:kinetix_ink/kinetix_ink.dart';
import 'package:path_provider/path_provider.dart';

/// Which board: one per class (section) and chapter, so the teacher finds last period's work
/// when the class comes back to the chapter. `free` is the board opened outside a chapter.
@immutable
class BoardKey {
  const BoardKey(this.classId, [this.chapterId = 'free']);
  final String classId, chapterId;

  /// A safe file name.
  String get file => '${_safe(classId)}__${_safe(chapterId)}.json';
  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  @override
  bool operator ==(Object other) => other is BoardKey && other.classId == classId && other.chapterId == chapterId;
  @override
  int get hashCode => Object.hash(classId, chapterId);
  @override
  String toString() => '$classId/$chapterId';
}

/// An open board and what the board screen keeps beside the kinetix_ink pages: which lesson
/// step a page was made from (by page id), so the step opens its own page again.
class OpenBoard {
  OpenBoard(this.key, this.controller);
  final BoardKey key;
  final WhiteboardController controller;

  /// Page id → lesson block id, for pages made from a lesson step ("From lesson step 3").
  final Map<String, String> stepPages = {};

  /// The page made from [blockId], if there is one.
  int? pageForStep(String blockId) {
    final pages = controller.pages;
    for (var i = 0; i < pages.length; i++) {
      if (stepPages[pages[i].id] == blockId) return i;
    }
    return null;
  }
}

/// Saves boards on the board itself (app support folder, `boards/`), never on the network.
/// Each board is the KINETIX saved-board JSON plus the lesson step of each page.
class BoardStore {
  BoardStore({Directory? dir}) : _dir = dir;

  /// The app's store; tests put one on a temporary folder.
  static BoardStore instance = BoardStore();

  Directory? _dir;
  bool _noDisk = false;
  final Map<BoardKey, OpenBoard> _open = {};
  final Map<BoardKey, Timer> _timers = {};

  /// How long after the last change a board is written.
  static Duration saveDelay = const Duration(milliseconds: 800);

  /// Under `flutter test` without a folder, boards stay in memory (never in the developer's home).
  static final bool _testing = Platform.environment.containsKey('FLUTTER_TEST');

  Future<Directory?> _folder() async {
    if (_noDisk || (_dir == null && _testing)) return null;
    try {
      _dir ??= Directory('${(await getApplicationSupportDirectory()).path}/boards');
      if (!_dir!.existsSync()) _dir!.createSync(recursive: true);
      return _dir;
    } catch (_) {
      _noDisk = true; // no app folder (a test without one): boards live while the app runs
      return null;
    }
  }

  File? _fileSync(BoardKey k) => _dir == null ? null : File('${_dir!.path}/${k.file}');

  /// A new, empty board in the board's look: white paper, a dark pen with smoothing.
  static WhiteboardController newController() {
    final c = WhiteboardController()
      ..background = BoardBackground.plain
      ..penSmoothing = 0.55
      ..penPressure = true
      ..eraserRadius = 26;
    c.setPen(color: const Color(0xFF1B1D2E), width: 9);
    c.setHighlighter(color: const Color(0x80FFE45C), width: 9);
    c.tool = BoardTool.pen;
    return c;
  }

  /// The board already open in this app run, if any.
  OpenBoard? openNow(BoardKey k) => _open[k];

  /// The board for [k]: the one open in this run (with its undo), else the saved one, else new.
  Future<OpenBoard> open(BoardKey k) {
    final now = _open[k];
    if (now != null) return Future.value(now);
    return _loading[k] ??= _load(k).whenComplete(() {
      _loading.remove(k); // (a block body: returning the removed future would wait on itself)
    });
  }

  final Map<BoardKey, Future<OpenBoard>> _loading = {};

  Future<OpenBoard> _load(BoardKey k) async {
    final board = OpenBoard(k, newController());
    final dir = _dir ?? await _folder();
    final f = dir == null ? null : File('${dir.path}/${k.file}');
    if (f != null && f.existsSync()) {
      try {
        final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        restore(board, j);
      } catch (_) {
        // A damaged file: keep it aside and start clean rather than lose the class's board.
        try {
          f.renameSync('${f.path}.bad');
        } catch (_) {}
      }
    }
    _open[k] = board;
    board.controller.committed.addListener(() => scheduleSave(board));
    return board;
  }

  /// Puts saved JSON on [board] (pages, papers and the lesson step of each page).
  static void restore(OpenBoard board, Map<String, dynamic> j) {
    final saved = SavedBoard.fromJson((j['board'] as Map).cast<String, dynamic>());
    board.controller.load(saved);
    final steps = (j['steps'] as List?) ?? const [];
    final pages = board.controller.pages;
    board.stepPages.clear();
    for (var i = 0; i < pages.length && i < steps.length; i++) {
      if (steps[i] is String) board.stepPages[pages[i].id] = steps[i] as String;
    }
    final at = j['page'];
    if (at is int && at > 0 && at < pages.length) board.controller.goToPage(at);
  }

  /// The JSON written for [board].
  static Map<String, dynamic> encode(OpenBoard board) {
    final c = board.controller;
    return {
      'v': 1,
      'class': board.key.classId,
      'chapter': board.key.chapterId,
      'savedAt': DateTime.now().toIso8601String(),
      'page': c.pageIndex,
      'steps': [for (final p in c.pages) board.stepPages[p.id]],
      'board': c.toSaved(const Size(2400, 1350)).toJson(),
    };
  }

  /// Saves soon (after [saveDelay] without changes).
  void scheduleSave(OpenBoard board) {
    _timers[board.key]?.cancel();
    _timers[board.key] = Timer(saveDelay, () => save(board));
  }

  /// Writes [board] now.
  Future<void> save(OpenBoard board) async {
    _timers.remove(board.key)?.cancel();
    final dir = _dir ?? await _folder();
    if (dir == null) return;
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final f = File('${dir.path}/${board.key.file}');
    final tmp = File('${f.path}.tmp');
    try {
      // Written whole, then swapped in, so a power cut never leaves half a board.
      tmp.writeAsStringSync(jsonEncode(encode(board)), flush: true);
      tmp.renameSync(f.path);
    } catch (_) {
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } catch (_) {}
    }
  }

  /// Saves every open board now (closing the board screen, leaving the app).
  Future<void> saveAll() async {
    for (final b in _open.values.toList()) {
      if (_timers.containsKey(b.key)) await save(b);
    }
  }

  /// True when a saved board exists for [k].
  bool hasSaved(BoardKey k) => _open.containsKey(k) || (_fileSync(k)?.existsSync() ?? false);

  /// Forgets the boards open in this run (tests; a new day).
  void forgetOpen() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _open.clear();
  }
}
