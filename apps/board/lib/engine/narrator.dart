import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'model.dart';

/// Reads text aloud. Self-Learning waits for [speak] to finish before moving on.
abstract class Narrator {
  Future<void> speak(String text, Lang lang);
  Future<void> stop();
}

/// The board's own offline TTS voice (Android: Google TTS with the en-IN / kn-IN voice packs
/// installed at setup).
class DeviceNarrator implements Narrator {
  final _tts = FlutterTts();
  bool _ready = false;

  @override
  Future<void> speak(String text, Lang lang) async {
    if (!_ready) {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.45); // slower: a classroom, not a phone
      _ready = true;
    }
    await _tts.setLanguage(lang == Lang.kn ? 'kn-IN' : 'en-IN');
    try {
      await _tts.speak(text);
    } catch (_) {
      // No voice: Self-Learning falls back to timed reading (see PeriodRunner).
    }
  }

  @override
  Future<void> stop() async => _tts.stop();
}

/// Silent narrator: takes a reading-time pause instead of speaking (tests, muted boards).
class TimedNarrator implements Narrator {
  TimedNarrator({this.perWord = const Duration(milliseconds: 350)});
  final Duration perWord;
  Completer<void>? _c;
  Timer? _t;
  final spoken = <String>[];

  @override
  Future<void> speak(String text, Lang lang) {
    spoken.add(text);
    _c = Completer<void>();
    _t = Timer(perWord * text.split(' ').length, () => _c?.complete());
    return _c!.future;
  }

  @override
  Future<void> stop() async {
    _t?.cancel();
    if (!(_c?.isCompleted ?? true)) _c!.complete();
  }
}
