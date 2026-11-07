import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';

import 'model.dart';

class PackError implements Exception {
  PackError(this.message);
  final String message;
  @override
  String toString() => 'PackError: $message';
}

/// Installed content packs on the board's disk (docs/architecture.md → Content packs).
///
/// Layout: `<root>/<packId>/<version>/…` plus `<root>/installed.json` = {packId: version}.
/// A pack is unpacked into a fresh version directory and only then made current by rewriting
/// installed.json, so a power cut mid-install leaves the old version in use.
class PackStore {
  PackStore(this.root, {required this.trustedKeys});

  final Directory root;

  /// keyId → raw 32-byte Ed25519 public key.
  final Map<String, List<int>> trustedKeys;

  final Map<String, InstalledPack> _packs = {};
  Iterable<InstalledPack> get packs => _packs.values;
  InstalledPack? byChapter(String chapterId) => _packs.values.where((p) => p.chapter.id == chapterId).firstOrNull;

  File get _index => File('${root.path}/installed.json');

  Map<String, String> installed() => _index.existsSync() ? (jsonDecode(_index.readAsStringSync()) as Map).cast<String, String>() : {};

  static int compareVersions(String a, String b) {
    final x = a.split('.').map(int.parse).toList(), y = b.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if (x[i] != y[i]) return x[i].compareTo(y[i]);
    }
    return 0;
  }

  /// Verifies and installs a .zpack. Returns false when the same or a newer version is installed.
  Future<bool> install(Uint8List bytes) async {
    final (:manifest, :read) = await openSignedZip(bytes, trustedKeys);
    if (manifest['kind'] != null) throw PackError('not a content pack (${manifest['kind']})');

    final id = manifest['id'] as String, version = manifest['version'] as String;
    final current = installed()[id];
    if (current != null && compareVersions(current, version) >= 0) return false;

    final dir = Directory('${root.path}/$id/$version');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    writeVerifiedFiles(manifest, read, dir);
    final idx = installed()..[id] = version;
    final tmp = File('${_index.path}.tmp')..writeAsStringSync(jsonEncode(idx));
    tmp.renameSync(_index.path);
    if (current != null) {
      final old = Directory('${root.path}/$id/$current');
      if (old.existsSync()) old.deleteSync(recursive: true);
    }
    _packs[id] = _load(id, version);
    return true;
  }

  /// Loads every installed pack from disk.
  void loadAll() {
    _packs.clear();
    for (final e in installed().entries) {
      try {
        _packs[e.key] = _load(e.key, e.value);
      } catch (_) {
        // A damaged pack is skipped; the next sync reinstalls it.
      }
    }
  }

  InstalledPack _load(String id, String version) {
    final dir = '${root.path}/$id/$version';
    Map<String, dynamic> j(String p) => jsonDecode(File('$dir/$p').readAsStringSync()) as Map<String, dynamic>;
    final lessons = <String, Lesson>{};
    for (final f in Directory('$dir/lessons').listSync().whereType<File>()) {
      final l = Lesson.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
      lessons[l.topicId] = l;
    }
    final qs = jsonDecode(File('$dir/questions.json').readAsStringSync()) as List;
    // Optional: the chapter's formula sheet (packs from before the school import have none).
    final ff = File('$dir/formulas.json');
    List<SheetFormula> formulas = const [];
    try {
      if (ff.existsSync()) formulas = SheetFormula.sheet(jsonDecode(ff.readAsStringSync()));
    } catch (_) {}
    return InstalledPack(
      id: id,
      version: version,
      chapter: Chapter.fromJson(j('chapter.json')),
      lessons: lessons,
      questions: {for (final q in qs) (q['id'] as String): Question.fromJson(q as Map<String, dynamic>)},
      mediaDir: '$dir/media',
      formulas: formulas,
    );
  }
}

/// Opens a signed zip (a content or audio pack): checks manifest.sig, Ed25519 over the exact
/// manifest bytes, against [trustedKeys]. The manifest lists the SHA-256 of every other file, so
/// [writeVerifiedFiles] then checks each file as it is written.
Future<({Map<String, dynamic> manifest, Uint8List? Function(String) read})> openSignedZip(Uint8List bytes, Map<String, List<int>> trustedKeys) async {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw PackError('not a pack file');
  }
  Uint8List? read(String name) {
    final f = zip.findFile(name);
    return f == null ? null : Uint8List.fromList(f.readBytes()!);
  }

  final manifestBytes = read('manifest.json'), sig = read('manifest.sig');
  if (manifestBytes == null || sig == null) throw PackError('manifest or signature missing');
  final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
  final key = trustedKeys[manifest['keyId']];
  if (key == null) throw PackError('signed with an unknown key ${manifest['keyId']}');
  final ok = await Ed25519().verify(
    manifestBytes,
    signature: Signature(sig, publicKey: SimplePublicKey(key, type: KeyPairType.ed25519)),
  );
  if (!ok) throw PackError('signature does not match');
  return (manifest: manifest, read: read);
}

/// Writes every file the manifest lists into [dir], refusing a bad path or a changed file.
void writeVerifiedFiles(Map<String, dynamic> manifest, Uint8List? Function(String) read, Directory dir) {
  for (final f in (manifest['files'] as List).cast<Map<String, dynamic>>()) {
    final path = f['path'] as String;
    if (path.contains('..') || path.startsWith('/')) throw PackError('bad path $path');
    final data = read(path);
    if (data == null) throw PackError('$path missing');
    if (c.sha256.convert(data).toString() != f['sha256']) throw PackError('$path is corrupted');
    final out = File('${dir.path}/$path');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(data);
  }
}

/// Parses `trusted-key.json` ({keyId, ed25519: hex}).
MapEntry<String, List<int>> parseTrustedKey(String json) {
  final j = jsonDecode(json) as Map<String, dynamic>;
  final hex = j['ed25519'] as String;
  return MapEntry(j['keyId'] as String, [for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);
}
