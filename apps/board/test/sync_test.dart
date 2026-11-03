import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zynetix_board/core/config.dart';
import 'package:zynetix_board/engine/pack_store.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/engine/sync.dart';

import 'helpers.dart';

void main() {
  test('activate, then sync: logs leave the outbox, PIN/schedule apply, newer packs install', () async {
    SharedPreferences.setMockInitialValues({});
    final config = await BoardConfig.load();
    final store = PackStore(Directory.systemTemp.createTempSync('p'), trustedKeys: {trusted.key: trusted.value});
    final outbox = Outbox(File('${Directory.systemTemp.createTempSync('o').path}/o.jsonl'))..add({'id': 'a'})..add({'id': 'b'})..add({'id': 'c'});
    final salt = 'x1', cfg = {'sectionId': 's9', 'sectionLabel': '2nd PUC · B', 'year': 'puc2', 'rollCount': 48, 'pinHash': BoardConfig.hashPin('2468', salt), 'pinSalt': salt, 'licence': {'validUntil': '2027-06-30'}};
    final mock = MockClient((req) async {
      if (req.url.path == '/v1/devices/activate') return http.Response(jsonEncode({'deviceToken': 'tok', 'config': cfg}), 201);
      if (req.url.path == '/v1/board/sync') {
        expect(req.headers['authorization'], 'Bearer tok');
        expect((jsonDecode(req.body)['outbox'] as List).length, 3);
        return http.Response(jsonEncode({
          'accepted': ['a', 'b'], 'rejected': [{'id': 'c'}], 'config': cfg, 'timetable': [],
          'schedule': [{'date': '2026-11-05', 'start': '10:00', 'end': '10:40', 'topicId': 't'}],
          'packs': [{'id': seedIndex[0]['id'], 'version': '1.0.0', 'url': 'http://api/pack'}],
        }), 201);
      }
      return http.Response.bytes(seedBytes(0), 200);
    });
    final sync = SyncClient(config: config, store: store, outbox: outbox, client: mock);
    expect(await sync.sync(), 0, reason: 'not activated yet');
    await sync.activate(apiBase: 'http://api', code: 'demo1puc', name: 'Room 4', pin: '2468');
    expect(config.rollCount, 48);
    expect(await sync.sync(), 1);
    expect(outbox.pending(), isEmpty);
    expect(config.checkPin('2468'), isTrue);
    expect(config.checkPin('1234'), isFalse);
    expect(config.schedule.single.start, '10:00');
    expect(store.packs.single.id, seedIndex[0]['id']);
  });
}
