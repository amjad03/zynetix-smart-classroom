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

  void goTo(int i) {
    if (i < 0 || i >= blocks.length || i == _index) return;
    narrator.stop();
    _speaking = false;
    _index = i;
    _pen = false; // ink belongs to one block
    recorder.shown(current.id);
    notifyListeners();
  }

  void next() => goTo(_index + 1);
  void back() => goTo(_index - 1);

  void setPaused(bool p) {
    if (p == _paused) return;
    _paused = p;
    if (p) {
      narrator.stop();
      _speaking = false;
    }
    notifyListeners();
  }

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
    final n = current.narration;
    if (n == null) return;
    _speaking = true;
    notifyListeners();
    await narrator.speak(n.t(_lang), _lang);
    _speaking = false;
    notifyListeners();
  }

  void finish({required bool completed}) {
    narrator.stop();
    recorder.close(completed: completed);
  }
}
