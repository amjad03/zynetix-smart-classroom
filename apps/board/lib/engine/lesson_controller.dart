import 'package:flutter/foundation.dart';

import 'model.dart';
import 'narrator.dart';
import 'session_log.dart';

/// The lesson player's state: which block, paused or not, pen on or off.
/// Teacher Mode drives it with Back/Next; Self-Learning drives it from the PeriodRunner.
class LessonController extends ChangeNotifier {
  LessonController({required this.pack, required this.lesson, required this.narrator, required this.recorder, required Lang lang, List<Block>? blocks})
    : _lang = lang,
      blocks = blocks ?? lesson.blocks {
    recorder.shown(current.id);
  }

  final InstalledPack pack;
  final Lesson lesson;
  final Narrator narrator;
  final SessionRecorder recorder;
  final List<Block> blocks;

  int _index = 0;
  bool _paused = false, _pen = false, _speaking = false;
  Lang _lang;

  int get index => _index;
  Block get current => blocks[_index];
  bool get isFirst => _index == 0;
  bool get isLast => _index == blocks.length - 1;
  bool get paused => _paused;
  bool get pen => _pen;
  bool get speaking => _speaking;
  Lang get lang => _lang;
  double get progress => (_index + 1) / blocks.length;

  /// One idea at a time: how much of the current block is shown (1 … [revealTotal]).
  int _revealed = 1;
  int get revealed => _revealed;
  int get revealTotal => current.revealSteps(pack);
  bool get revealDone => _revealed >= revealTotal;

  /// Shows the next card or step of this block; false when all are shown.
  bool revealMore() {
    if (revealDone) return false;
    _revealed++;
    notifyListeners();
    return true;
  }

  /// Shows this block up to step [n] (an answer tapped reveals it at once).
  void revealTo(int n) {
    final v = n.clamp(1, revealTotal);
    if (v == _revealed) return;
    _revealed = v;
    notifyListeners();
  }

  void goTo(int i, {bool whole = false}) {
    if (i < 0 || i >= blocks.length || i == _index) return;
    stopSpeech();
    _speaking = false;
    _index = i;
    _revealed = whole ? revealTotal : 1;
    stepLine = null;
    _pen = false; // ink belongs to one block
    recorder.shown(current.id);
    notifyListeners();
  }

  /// Next: the next card or step of this block, then the next block.
  void next() {
    if (!revealMore()) goTo(_index + 1);
  }

  /// Back: the previous block, shown whole.
  void back() => goTo(_index - 1, whole: true);

  void setPaused(bool p) {
    if (p == _paused) return;
    _paused = p;
    if (p) {
      stopSpeech();
      _speaking = false;
    }
    notifyListeners();
  }

  // Speech is queued, so a block's narration and its whiteboard steps' lines never talk over
  // each other; stopping drops everything queued.
  Future<void> _speech = Future.value();
  int _speechGen = 0;

  /// Reads [text] aloud after whatever is being read now. Completes when it has been read
  /// (or dropped by [stopSpeech]).
  Future<void> speak(L10n text) {
    final gen = _speechGen;
    final f = _speech.then((_) async {
      if (gen == _speechGen) await narrator.speak(text.t(_lang), _lang);
    });
    _speech = f.catchError((Object _) {});
    return _speech;
  }

  void stopSpeech() {
    _speechGen++;
    narrator.stop();
  }

  /// Teacher Mode: once the teacher has asked for Read aloud, whiteboard steps read their lines
  /// as they appear. A step's line is what the 🔊 button reads on a block with no narration.
  bool readAloudOn = false;
  L10n? stepLine;

  void togglePen() {
    _pen = !_pen;
    notifyListeners();
  }

  void setLang(Lang l) {
    _lang = l;
    notifyListeners();
  }

  /// Reads the current block's narration aloud (the 🔊 button in Teacher Mode).
  Future<void> readAloud() async {
    readAloudOn = true;
    final lines = [?current.narration, if (current.type == BlockType.whiteboard) ?stepLine];
    if (lines.isEmpty) return;
    _speaking = true;
    notifyListeners();
    for (final n in lines) {
      await speak(n);
    }
    _speaking = false;
    notifyListeners();
  }

  /// Whether the 🔊 button applies to this block.
  bool get canReadAloud => current.narration != null || current.type == BlockType.whiteboard;

  void finish({required bool completed}) {
    stopSpeech();
    recorder.close(completed: completed);
  }
}
