import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;

import 'model.dart';
import 'pack_store.dart';

/// One rendered narration clip on disk.
class VoiceClip {
  const VoiceClip(this.path, this.ms);
  final String path;
  final int ms;
}

/// A chapter's narration in one language (`<packId>-audio-<lang>`), installed from a signed
/// audio pack (packages/lesson-schema AudioPackManifest).
class VoicePack {
  VoicePack({required this.id, required this.packId, required this.lang, required this.version, required this.dir, required this.clips, required this.voice});
  final String id, packId, version, dir;
  final Lang lang;

  /// `<lessonId>/<clip>` → (file inside the pack, ms, sha of the line it says).
  final Map<String, ({String file, int ms, String sha})> clips;

  /// {model, voice, licence}: shown in Settings → About.
  final Map<String, dynamic> voice;

  static VoicePack fromManifest(Map<String, dynamic> m, String dir) => VoicePack(
    id: m['id'] as String,
    packId: m['packId'] as String,
    lang: m['lang'] == 'kn' ? Lang.kn : Lang.en,
    version: m['version'] as String,
    dir: dir,
    voice: (m['voice'] as Map?)?.cast<String, dynamic>() ?? const {},
    clips: {
      for (final e in (m['clips'] as List).cast<Map<String, dynamic>>())
        '${e['lessonId']}/${e['clip']}': (file: e['file'] as String, ms: e['ms'] as int, sha: e['sha'] as String),
    },
  );
}

/// The first 16 hex of SHA-256 of a voice line (as tools/voice and the pack builder write it).
String lineSha(String text) => c.sha256.convert(utf8.encode(text)).toString().substring(0, 16);

/// The clip id of a block's step: its voice line's `clip`, else `<blockId>.<step>`.
String clipIdOf(Block b, int step) {
  final v = b.raw['voice'];
  final line = v is List && step >= 1 && step <= v.length ? v[step - 1] : null;
  return (line is Map ? line['clip'] as String? : null) ?? '${b.id}.$step';
}

/// A block step's voice line in [lang] (null when the block has no line for it).
String? voiceLine(Block b, int step, Lang lang) {
  final v = b.raw['voice'];
  // An explainer without voice lines reads its watch steps.
  if (v is! List && b.type == BlockType.explainer) {
    final w = b.raw['watch'];
    final s = w is List && step >= 1 && step <= w.length && w[step - 1] is Map ? L10n.maybe((w[step - 1] as Map)['say'])?.t(lang) : null;
    return (s?.isNotEmpty ?? false) ? s : null;
  }
  if (v is! List || step < 1 || step > v.length) return null;
  final line = v[step - 1];
  if (line is! Map) return null;
  final say = line['say'];
  final t = say is Map ? say[lang.name] as String? : null;
  return (t?.isNotEmpty ?? false) ? t : null;
}

/// A lesson's narration in one language: the clip for each block step, if it is there and still
/// says today's line (a clip rendered for older text is treated as missing: that step is silent).
class VoiceTrack {
  VoiceTrack(this.pack, this.lessonId, this.lang);
  final VoicePack pack;
  final String lessonId;
  final Lang lang;

  VoiceClip? clip(Block b, int step) {
    final line = voiceLine(b, step, lang);
    final e = pack.clips['$lessonId/${clipIdOf(b, step)}'];
    if (line == null || e == null || e.sha != lineSha(line)) return null;
    return VoiceClip('${pack.dir}/${e.file}', e.ms);
  }

  /// How many of the lesson's voice lines have a current clip (0 … total).
  int coverage(Lesson l) {
    var n = 0;
    for (final b in l.blocks) {
      final v = b.raw['voice'];
      for (var k = 1; v is List && k <= v.length; k++) {
        if (clip(b, k) != null) n++;
      }
    }
    return n;
  }
}

/// Installed audio packs: `<root>/<audioId>/<version>/…` plus `<root>/installed.json`, installed
/// the same way as content packs (a fresh directory, then the index rewritten).
class VoiceStore {
  VoiceStore(this.root, {required this.trustedKeys});
  final Directory root;
  final Map<String, List<int>> trustedKeys;
  final Map<String, VoicePack> _packs = {};

  File get _index => File('${root.path}/installed.json');
  Map<String, String> installed() => _index.existsSync() ? (jsonDecode(_index.readAsStringSync()) as Map).cast<String, String>() : {};

  static String audioId(String packId, Lang lang) => '$packId-audio-${lang.name}';

  VoicePack? forPack(String packId, Lang lang) => _packs[audioId(packId, lang)];

  /// The lesson's narration in [lang], or null (no audio pack downloaded: the lesson is silent).
  VoiceTrack? track(InstalledPack pack, Lesson lesson, Lang lang) {
    final p = forPack(pack.id, lang);
    return p == null ? null : VoiceTrack(p, lesson.id, lang);
  }

  /// Verifies and installs an audio pack. False when the same or a newer version is installed.
  Future<bool> install(Uint8List bytes) async {
    final (:manifest, :read) = await openSignedZip(bytes, trustedKeys);
    if (manifest['kind'] != 'audio') throw PackError('not an audio pack');
    final id = manifest['id'] as String, version = manifest['version'] as String;
    final current = installed()[id];
    if (current != null && PackStore.compareVersions(current, version) >= 0) return false;
    final dir = Directory('${root.path}/$id/$version');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    writeVerifiedFiles(manifest, read, dir);
    File('${dir.path}/manifest.json').writeAsStringSync(jsonEncode(manifest));
    root.createSync(recursive: true);
    final idx = installed()..[id] = version;
    final tmp = File('${_index.path}.tmp')..writeAsStringSync(jsonEncode(idx));
    tmp.renameSync(_index.path);
    if (current != null) {
      final old = Directory('${root.path}/$id/$current');
      if (old.existsSync()) old.deleteSync(recursive: true);
    }
    _packs[id] = VoicePack.fromManifest(manifest, dir.path);
    return true;
  }

  void loadAll() {
    _packs.clear();
    for (final e in installed().entries) {
      try {
        final dir = '${root.path}/${e.key}/${e.value}';
        _packs[e.key] = VoicePack.fromManifest(jsonDecode(File('$dir/manifest.json').readAsStringSync()) as Map<String, dynamic>, dir);
      } catch (_) {
        // A damaged audio pack is skipped: the lessons play silently until it is downloaded again.
      }
    }
  }
}
