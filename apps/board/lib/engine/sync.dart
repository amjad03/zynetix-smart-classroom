import 'dart:convert';

import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'model.dart';
import 'pack_store.dart';
import 'session_log.dart';
import 'voice.dart';

/// Talks to services/api when there is a connection. Everything it does is optional: the board
/// teaches from what it has. Logs are only removed from the outbox once the API has them.
class SyncClient {
  SyncClient({required this.config, required this.store, required this.outbox, this.voice, http.Client? client}) : _http = client ?? http.Client();
  final BoardConfig config;
  final PackStore store;

  /// Narration audio packs (null on a board built without voice).
  final VoiceStore? voice;
  final Outbox outbox;
  final http.Client _http;

  Map<String, String> get _auth => {'authorization': 'Bearer ${config.deviceToken}', 'content-type': 'application/json'};

  /// Registers this board with the code from Admin → Boards and the PIN chosen here.
  Future<void> activate({required String apiBase, required String code, required String name, required String pin}) async {
    final r = await _http.post(
      Uri.parse('$apiBase/v1/devices/activate'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'code': code.trim().toUpperCase(), 'name': name, 'pin': pin}),
    );
    if (r.statusCode != 201) throw SyncError('activation failed (${r.statusCode})');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    await config.apply({'apiBase': apiBase, 'deviceToken': j['deviceToken'] as String});
    await _applyConfig(j['config'] as Map<String, dynamic>);
  }

  /// One round: send logs, apply config/schedule, download newer packs. Returns packs installed.
  Future<int> sync() async {
    if (!config.activated) {
      // A board without the API still fetches the voices asked for offline, from the voice CDN.
      await _retryWantedVoices();
      return 0;
    }
    final pending = outbox.pending();
    final r = await _http.post(Uri.parse('${config.apiBase}/v1/board/sync'), headers: _auth, body: jsonEncode({'installed': store.installed(), 'installedAudio': ?voice?.installed(), 'outbox': pending}));
    if (r.statusCode != 201) throw SyncError('sync failed (${r.statusCode})');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    // Rejected logs can never be accepted (a newer schema, a bug): drop them too, so they don't block the queue.
    outbox.remove({...(j['accepted'] as List).cast<String>(), for (final x in j['rejected'] as List) ?(x['id'] as String?)});
    await _applyConfig(j['config'] as Map<String, dynamic>);
    await config.apply({'schedule': jsonEncode(j['schedule']), 'timetable': jsonEncode(j['timetable'])});
    var installed = 0;
    for (final p in (j['packs'] as List).cast<Map<String, dynamic>>()) {
      final res = await _http.get(Uri.parse(p['url'] as String));
      if (res.statusCode == 200 && await store.install(res.bodyBytes)) installed++;
    }
    // Newer versions of the chapter voices this board already has.
    for (final a in ((j['audio'] as List?) ?? const []).cast<Map<String, dynamic>>()) {
      final res = await _http.get(Uri.parse(a['url'] as String));
      if (res.statusCode == 200) await voice?.install(res.bodyBytes);
    }
    await _retryWantedVoices();
    return installed;
  }

  /// Voices the teacher asked for while offline ("Download voice"), now that there is a connection.
  Future<void> _retryWantedVoices() async {
    for (final w in config.voiceWanted) {
      final [packId, lang] = w.split('|');
      try {
        await downloadVoice(packId, lang == 'kn' ? Lang.kn : Lang.en);
      } catch (_) {}
    }
  }

  /// Downloads a chapter's narration (one signed audio pack per chapter and language, a few MB)
  /// once, over the college Wi-Fi; afterwards it plays offline. True when a newer one was installed.
  /// Offline, the request is remembered and the next sync fetches it.
  Future<bool> downloadVoice(String packId, Lang lang) async {
    final v = voice;
    if (v == null) return false;
    final want = '$packId|${lang.name}';
    try {
      final j = config.activated ? await _voiceFromApi(packId, lang) : await _voiceFromCdn(packId, lang);
      final have = v.installed()[j['id']];
      if (have != null && PackStore.compareVersions(have, j['version'] as String) >= 0) {
        await config.setVoiceWanted(want, false);
        return false;
      }
      final res = await _http.get(Uri.parse(j['url'] as String));
      if (res.statusCode != 200) throw SyncError('voice download failed (${res.statusCode})');
      // The CDN index names each file's SHA-256 and size; the pack's own signature is checked on install.
      if (j['sha256'] case final String sha when c.sha256.convert(res.bodyBytes).toString() != sha) throw PackError('voice download is corrupted');
      if (j['size'] case final int size when res.bodyBytes.length != size) throw PackError('voice download is incomplete');
      final ok = await v.install(res.bodyBytes);
      await config.setVoiceWanted(want, false);
      return ok;
    } on SyncError catch (e) {
      if (!e.message.startsWith('no voice')) await config.setVoiceWanted(want, true);
      rethrow;
    } catch (e) {
      await config.setVoiceWanted(want, true);
      if (e is PackError) rethrow;
      throw SyncError('no connection: the voice downloads at the next sync');
    }
  }

  /// The API's entry for a chapter voice: {id, version, url} (an activated board).
  Future<Map<String, dynamic>> _voiceFromApi(String packId, Lang lang) async {
    final r = await _http.get(Uri.parse('${config.apiBase}/v1/board/audio/$packId/${lang.name}'), headers: _auth);
    if (r.statusCode == 404) throw SyncError('no voice for this chapter yet');
    if (r.statusCode != 200) throw SyncError('voice download failed (${r.statusCode})');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// A board without the API (not activated) reads the voice CDN's index instead:
  /// `<voiceCdnBase>/audio-index.json`, signed (audio-index.json.sig, Ed25519 over the exact bytes)
  /// with a key the board trusts, listing {packId, lang, id, version, url, sha256, size} per pack.
  Future<Map<String, dynamic>> _voiceFromCdn(String packId, Lang lang) async {
    final base = config.voiceCdnBase;
    final r = await _http.get(Uri.parse('$base/audio-index.json'));
    if (r.statusCode != 200) throw SyncError('voice download failed (${r.statusCode})');
    final s = await _http.get(Uri.parse('$base/audio-index.json.sig'));
    if (s.statusCode != 200) throw SyncError('voice download failed (${s.statusCode})');
    final index = await verifyAudioIndex(r.bodyBytes, s.bodyBytes, voice!.trustedKeys);
    final e = (index['packs'] as List).cast<Map<String, dynamic>>().where((p) => p['packId'] == packId && p['lang'] == lang.name).firstOrNull;
    if (e == null) throw SyncError('no voice for this chapter yet');
    final url = e['url'] as String;
    return {...e, 'url': Uri.parse(base.endsWith('/') ? base : '$base/').resolve(url).toString()};
  }

  Future<void> _applyConfig(Map<String, dynamic> c) => config.apply({
    for (final k in ['sectionId', 'sectionLabel', 'year', 'rollCount', 'periodMinutes', 'collegeName', 'pinHash', 'pinSalt', 'licenceToken']) k: ?c[k],
    if (c['licence'] case {'validUntil': final String v}) 'licenceValidUntil': v,
  });
}

class SyncError implements Exception {
  SyncError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Checks the voice CDN's index: Ed25519 over the exact bytes of audio-index.json, by the key its
/// `keyId` names, which must be one the board trusts. Returns the parsed index.
Future<Map<String, dynamic>> verifyAudioIndex(List<int> bytes, List<int> sig, Map<String, List<int>> trustedKeys) async {
  final Map<String, dynamic> j;
  try {
    j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  } catch (_) {
    throw PackError('voice index is not JSON');
  }
  final key = trustedKeys[j['keyId']];
  if (key == null) throw PackError('voice index signed with an unknown key ${j['keyId']}');
  final ok = await Ed25519().verify(bytes, signature: Signature(sig, publicKey: SimplePublicKey(key, type: KeyPairType.ed25519)));
  if (!ok) throw PackError('voice index signature does not match');
  return j;
}
