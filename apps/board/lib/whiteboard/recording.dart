import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kinetix_ink/kinetix_ink.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../engine/model.dart';
import '../features/simple/kit.dart';
import 'wb_widgets.dart' show WbTag;

/// Lesson recording, as KINETIX TeachBoard does it: what the board showed, with times, and the
/// teacher's voice beside it. No camera, and no student is ever recorded (only the board and the
/// teacher's microphone). Recordings stay on the board.

/// The teacher's voice while a lesson is recorded (tests swap in a fake).
abstract class MicTrack {
  static MicTrack Function() make = RecordMicTrack.new;

  /// False when the microphone is not allowed or not there: the lesson is then recorded
  /// without the voice.
  Future<bool> start(String path);
  Future<void> stop();
}

class RecordMicTrack implements MicTrack {
  AudioRecorder? _rec;

  @override
  Future<bool> start(String path) async {
    try {
      final rec = _rec = AudioRecorder();
      if (!await rec.hasPermission()) return false;
      // Speech: mono AAC, about 20 MB for an hour.
      await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 48000, sampleRate: 22050, numChannels: 1, autoGain: true, noiseSuppress: true), path: path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _rec?.stop();
      await _rec?.dispose();
    } catch (_) {}
    _rec = null;
  }
}

/// One moment of the board: the open page as it looked.
class BoardFrame {
  const BoardFrame(this.ms, this.page, this.pages, this.background, this.elements);
  final int ms, page, pages;
  final BoardBackground background;
  final List<Map<String, dynamic>> elements;

  Map<String, dynamic> toJson() => {'t': ms, 'p': page, 'n': pages, 'bg': background.name, 'e': elements};
  static BoardFrame fromJson(Map<String, dynamic> j) => BoardFrame(
    j['t'] as int? ?? 0,
    j['p'] as int? ?? 0,
    j['n'] as int? ?? 1,
    BoardBackground.values.asNameMap()[j['bg']] ?? BoardBackground.plain,
    [for (final e in (j['e'] as List? ?? const [])) (e as Map).cast<String, dynamic>()],
  );
}

/// A recorded lesson.
class LessonRecording {
  LessonRecording({required this.id, required this.title, required this.at, required this.durationMs, required this.frames, required this.images, this.voice});
  final String id, title;
  final DateTime at;
  final int durationMs;
  final List<BoardFrame> frames;

  /// Pictures by hash (base64), each kept once.
  final Map<String, String> images;

  /// The voice file beside the recording, if the voice was recorded.
  final String? voice;

  Map<String, dynamic> toJson() => {
    'v': 1,
    'id': id,
    'title': title,
    'at': at.millisecondsSinceEpoch,
    'ms': durationMs,
    'voice': voice,
    'img': images,
    'frames': [for (final f in frames) f.toJson()],
  };

  static LessonRecording fromJson(Map<String, dynamic> j) => LessonRecording(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int? ?? 0),
    durationMs: j['ms'] as int? ?? 0,
    voice: j['voice'] as String?,
    images: (j['img'] as Map? ?? const {}).cast<String, String>(),
    frames: [for (final f in (j['frames'] as List? ?? const [])) BoardFrame.fromJson((f as Map).cast<String, dynamic>())],
  );

  /// The frame showing at [ms].
  BoardFrame? frameAt(int ms) {
    BoardFrame? out;
    for (final f in frames) {
      if (f.ms > ms) break;
      out = f;
    }
    return out ?? frames.firstOrNull;
  }

  /// The elements of [f], decoded.
  List<BoardElement> elementsOf(BoardFrame f) {
    final out = <BoardElement>[];
    for (var i = 0; i < f.elements.length; i++) {
      final e = decodeElement(f.elements[i], 'r$i', image: (ref) => ref is String && images[ref] != null ? base64Decode(images[ref]!) : null);
      if (e != null) out.add(e);
    }
    return out;
  }
}

/// Where recordings are kept (app support `recordings/`).
class RecordingStore {
  RecordingStore({Directory? dir}) : _dir = dir;
  static RecordingStore instance = RecordingStore();
  Directory? _dir;

  Future<Directory?> folder() async {
    if (_dir == null && Platform.environment.containsKey('FLUTTER_TEST')) return null;
    try {
      _dir ??= Directory('${(await getApplicationSupportDirectory()).path}/recordings');
      if (!_dir!.existsSync()) _dir!.createSync(recursive: true);
      return _dir;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(LessonRecording r) async {
    final d = await folder();
    if (d == null) return;
    await File('${d.path}/${r.id}.json').writeAsString(jsonEncode(r.toJson()));
  }

  /// Saved recordings, newest first.
  Future<List<LessonRecording>> list() async {
    final d = await folder();
    if (d == null) return const [];
    final out = <LessonRecording>[];
    for (final f in d.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      try {
        out.add(LessonRecording.fromJson((jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>()));
      } catch (_) {}
    }
    return out..sort((a, b) => b.at.compareTo(a.at));
  }

  Future<String?> voicePath(LessonRecording r) async {
    final d = await folder();
    return d == null || r.voice == null ? null : '${d.path}/${r.voice}';
  }

  Future<void> delete(LessonRecording r) async {
    final d = await folder();
    if (d == null) return;
    for (final f in [File('${d.path}/${r.id}.json'), if (r.voice != null) File('${d.path}/${r.voice}')]) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }
}

/// Records [board] from [start] to [stop]: a frame each time the board changes (at most a few
/// a second), and the teacher's voice.
class BoardRecorder extends ChangeNotifier {
  BoardRecorder(this.board, {required this.title, RecordingStore? store, DateTime Function()? clock}) : store = store ?? RecordingStore.instance, _clock = clock ?? DateTime.now;

  final WhiteboardController board;
  final String title;
  final RecordingStore store;
  final DateTime Function() _clock;

  final _frames = <BoardFrame>[];
  final _images = <String, String>{};
  DateTime? _started;
  Timer? _pending, _tick;
  MicTrack? _voice;
  String? _voiceFile;
  int _lastAt = -1000;

  bool get recording => _started != null;
  Duration get elapsed => _started == null ? Duration.zero : _clock().difference(_started!);
  bool get hasVoice => _voiceFile != null;

  String _id() => 'rec-${_clock().millisecondsSinceEpoch}';

  Future<void> start({bool voice = true}) async {
    if (recording) return;
    _started = _clock();
    _frames.clear();
    _images.clear();
    _snap();
    board.addListener(_changed);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
    if (voice) {
      final d = await store.folder();
      if (d != null) {
        final name = '${_id()}.m4a';
        final v = MicTrack.make();
        if (await v.start('${d.path}/$name')) {
          _voice = v;
          _voiceFile = name;
          notifyListeners();
        }
      }
    }
  }

  void _changed() {
    // At most about three frames a second while ink flows; the last change always lands.
    final now = elapsed.inMilliseconds;
    if (now - _lastAt >= 330) {
      _snap();
    } else {
      _pending?.cancel();
      _pending = Timer(const Duration(milliseconds: 340), _snap);
    }
  }

  void _snap() {
    if (_started == null) return;
    _pending?.cancel();
    final ms = elapsed.inMilliseconds;
    _lastAt = ms;
    final els = [
      for (final e in board.elements)
        encodeElement(
          e,
          imageRef: (Uint8List bytes) {
            final h = md5.convert(bytes).toString();
            _images.putIfAbsent(h, () => base64Encode(bytes));
            return h;
          },
        ),
    ];
    final f = BoardFrame(ms, board.pageIndex, board.pageCount, board.background, els);
    // The same picture twice in a row is one frame.
    if (_frames.isNotEmpty && jsonEncode(_frames.last.elements) == jsonEncode(els) && _frames.last.page == f.page && _frames.last.background == f.background) return;
    _frames.add(f);
  }

  /// Stops and saves; returns the recording.
  Future<LessonRecording?> stop() async {
    if (_started == null) return null;
    _snap();
    board.removeListener(_changed);
    _pending?.cancel();
    _tick?.cancel();
    final dur = elapsed.inMilliseconds;
    final at = _started!;
    _started = null;
    await _voice?.stop();
    _voice = null;
    final r = LessonRecording(id: 'rec-${at.millisecondsSinceEpoch}', title: title, at: at, durationMs: dur, frames: List.of(_frames), images: Map.of(_images), voice: _voiceFile);
    _voiceFile = null;
    await store.save(r);
    notifyListeners();
    return r;
  }

  @override
  void dispose() {
    board.removeListener(_changed);
    _pending?.cancel();
    _tick?.cancel();
    unawaited(_voice?.stop());
    super.dispose();
  }
}

String mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Plays a recording back: the board as it was, with the teacher's voice.
class RecordingPlayer extends StatefulWidget {
  const RecordingPlayer({super.key, required this.recording, required this.lang, this.store});
  final LessonRecording recording;
  final Lang lang;
  final RecordingStore? store;
  @override
  State<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<RecordingPlayer> {
  AudioPlayer? _audio;
  Timer? _timer;
  int _ms = 0;
  bool _playing = false;
  BoardFrame? _frame;
  SavedBoard? _shown;

  LessonRecording get r => widget.recording;

  @override
  void initState() {
    super.initState();
    _show(0);
    unawaited(_loadVoice());
  }

  Future<void> _loadVoice() async {
    final path = await (widget.store ?? RecordingStore.instance).voicePath(r);
    if (path == null || !File(path).existsSync()) return;
    try {
      final a = AudioPlayer();
      await a.setFilePath(path);
      if (mounted) _audio = a;
    } catch (_) {}
  }

  void _show(int ms) {
    final f = r.frameAt(ms);
    if (f != null && !identical(f, _frame)) {
      _frame = f;
      _shown = SavedBoard(background: f.background, canvas: const Size(2400, 1350), pages: [r.elementsOf(f)]);
    }
    _ms = ms;
  }

  void _play() {
    if (_playing) {
      _timer?.cancel();
      unawaited(_audio?.pause());
      setState(() => _playing = false);
      return;
    }
    if (_ms >= r.durationMs) _show(0);
    final from = DateTime.now().subtract(Duration(milliseconds: _ms));
    unawaited(_audio?.seek(Duration(milliseconds: _ms)));
    unawaited(_audio?.play());
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final ms = DateTime.now().difference(from).inMilliseconds;
      if (ms >= r.durationMs) {
        _timer?.cancel();
        unawaited(_audio?.pause());
        setState(() {
          _show(r.durationMs);
          _playing = false;
        });
        return;
      }
      setState(() => _show(ms));
    });
    setState(() => _playing = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audio?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang;
    return Scaffold(
      backgroundColor: S.mist,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('closePlayer'),
                    onTap: () => Navigator.pop(context),
                    child: BigButton(tr(l, 'Back to the board', 'ಬೋರ್ಡ್‌ಗೆ ಹಿಂತಿರುಗಿ'), icon: Icons.arrow_back_rounded, height: 120, size: 36),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hd(56, l: l),
                    ),
                  ),
                  if (r.voice == null) WbTag(tr(l, 'No voice', 'ಧ್ವನಿ ಇಲ್ಲ'), icon: Icons.mic_off_rounded, bg: Colors.white, size: 30),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(48),
                    border: Border.all(color: S.line, width: 3),
                  ),
                  child: _shown == null ? const SizedBox.shrink() : WhiteboardView(key: ValueKey(_frame), board: _shown!),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('playRecording'),
                    onTap: _play,
                    child: BigButton(_playing ? tr(l, 'Pause', 'ವಿರಾಮ') : tr(l, 'Play', 'ಪ್ಲೇ'), icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded, bg: S.violet, height: 130, size: 40),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Slider(
                      value: _ms.clamp(0, r.durationMs).toDouble(),
                      max: r.durationMs <= 0 ? 1 : r.durationMs.toDouble(),
                      onChanged: (v) {
                        setState(() => _show(v.round()));
                        unawaited(_audio?.seek(Duration(milliseconds: v.round())));
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    '${mmss(Duration(milliseconds: _ms))} / ${mmss(Duration(milliseconds: r.durationMs))}',
                    style: tx(36, c: S.ink, w: FontWeight.w700),
                  ),
                  if (_frame != null) ...[const SizedBox(width: 24), WbTag(tr(l, 'Page ${_frame!.page + 1}', 'ಪುಟ ${_frame!.page + 1}'), bg: Colors.white, size: 30)],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
