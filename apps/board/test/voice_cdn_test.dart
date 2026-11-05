// A board without the API downloads chapter voices from the voice CDN: a signed index lists each
// audio pack's URL, SHA-256 and size, and the pack itself is still signature-checked on install.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zynetix_board/core/config.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/pack_store.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/engine/sync.dart';
import 'package:zynetix_board/engine/voice.dart';

void main() {
  late SimpleKeyPair kp, other;
  late List<int> pub;
  setUpAll(() async {
    kp = await Ed25519().newKeyPair();
    other = await Ed25519().newKeyPair();
    pub = (await kp.extractPublicKey()).bytes;
  });

  Future<Uint8List> audioPack() async {
    final clip = utf8.encode('OggS fake opus');
    final m = {
      'schemaVersion': 1, 'kind': 'audio', 'id': 'pk-audio-en', 'packId': 'pk', 'chapterId': 'ch', 'lang': 'en', 'version': '1.0.0',
      'createdAt': '2026-11-05T00:00:00Z', 'keyId': 'prod-test',
      'voice': {'model': 'hexgrad/Kokoro-82M', 'voice': 'am_michael', 'licence': 'Apache-2.0'},
      'clips': [{'lessonId': 'ch.t1.lesson', 'blockId': 'rule', 'step': 1, 'clip': 'rule.1', 'file': 'audio/t1/rule.1.opus', 'ms': 1500, 'sha': lineSha('x')}],
      'files': [{'path': 'audio/t1/rule.1.opus', 'sha256': c.sha256.convert(clip).toString(), 'bytes': clip.length}],
    };
    final mb = utf8.encode(jsonEncode(m));
    final sig = await Ed25519().sign(mb, keyPair: kp);
    final zip = Archive()
      ..addFile(ArchiveFile.bytes('manifest.json', mb))
      ..addFile(ArchiveFile.bytes('manifest.sig', sig.bytes))
      ..addFile(ArchiveFile.bytes('audio/t1/rule.1.opus', clip));
    return Uint8List.fromList(ZipEncoder().encode(zip));
  }

  Future<({SyncClient sync, VoiceStore voice, List<String> urls})> setup({bool badSig = false, bool badSha = false}) async {
    SharedPreferences.setMockInitialValues({});
    final config = await BoardConfig.load();
    expect(config.activated, isFalse);
    expect(config.voiceCdnBase, BoardConfig.defaultVoiceCdnBase);
    final pack = await audioPack();
    final index = utf8.encode(jsonEncode({
      'format': 1, 'keyId': 'prod-test',
      'packs': [{'packId': 'pk', 'lang': 'en', 'id': 'pk-audio-en', 'version': '1.0.0', 'url': 'pk-audio-en-1.0.0.zpack', 'sha256': badSha ? '0' * 64 : c.sha256.convert(pack).toString(), 'size': pack.length}],
    }));
    final sig = (await Ed25519().sign(index, keyPair: badSig ? other : kp)).bytes;
    final urls = <String>[];
    final mock = MockClient((req) async {
      urls.add(req.url.toString());
      expect(req.headers.containsKey('authorization'), isFalse, reason: 'the CDN gets no device token');
      final name = req.url.pathSegments.last;
      return switch (name) {
        'audio-index.json' => http.Response.bytes(index, 200),
        'audio-index.json.sig' => http.Response.bytes(sig, 200),
        'pk-audio-en-1.0.0.zpack' => http.Response.bytes(pack, 200),
        _ => http.Response('not found', 404),
      };
    });
    final voice = VoiceStore(Directory.systemTemp.createTempSync('vcdn'), trustedKeys: {'prod-test': pub});
    final sync = SyncClient(config: config, store: PackStore(Directory.systemTemp.createTempSync('p'), trustedKeys: const {}), outbox: Outbox(File('${Directory.systemTemp.createTempSync('o').path}/o.jsonl')), voice: voice, client: mock);
    return (sync: sync, voice: voice, urls: urls);
  }

  test('not activated: Download voice reads the signed CDN index and installs the verified pack', () async {
    final s = await setup();
    expect(await s.sync.downloadVoice('pk', Lang.en), isTrue);
    expect(s.voice.installed(), {'pk-audio-en': '1.0.0'});
    expect(s.urls.last, '${BoardConfig.defaultVoiceCdnBase}/pk-audio-en-1.0.0.zpack');
    expect(await s.sync.downloadVoice('pk', Lang.en), isFalse, reason: 'already the newest');
    await expectLater(s.sync.downloadVoice('pk', Lang.kn), throwsA(isA<SyncError>().having((e) => e.message, 'message', contains('no voice'))));
  });

  test('an index signed with an untrusted key, or a pack that does not match it, is refused', () async {
    final a = await setup(badSig: true);
    await expectLater(a.sync.downloadVoice('pk', Lang.en), throwsA(isA<PackError>()));
    expect(a.voice.installed(), isEmpty);
    final b = await setup(badSha: true);
    await expectLater(b.sync.downloadVoice('pk', Lang.en), throwsA(isA<PackError>()));
    expect(b.voice.installed(), isEmpty);
  });
}
