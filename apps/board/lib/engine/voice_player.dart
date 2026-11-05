import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'auto_play.dart';
import 'voice.dart';

/// The board's narration player: just_audio (ExoPlayer on Android), playing the Opus clips of an
/// installed audio pack from disk, with no network.
class JustAudioVoicePlayer implements VoicePlayer {
  final _p = AudioPlayer();
  Completer<bool>? _done;
  StreamSubscription<ProcessingState>? _sub;

  @override
  Future<bool> play(VoiceClip clip) async {
    await stop();
    final done = _done = Completer<bool>();
    try {
      await _p.setFilePath(clip.path);
    } catch (_) {
      // A clip the device cannot decode: the step is silent, as if it had no clip.
      if (!done.isCompleted) done.complete(true);
      return done.future;
    }
    _sub = _p.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && !done.isCompleted) done.complete(true);
    });
    unawaited(_p.play());
    return done.future;
  }

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> resume() async => unawaited(_p.play());

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (!(_done?.isCompleted ?? true)) _done!.complete(false);
    await _p.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _p.dispose();
  }
}
