import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zynetix_board/blocks/embeds.dart';
import 'package:zynetix_board/core/config.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/narrator.dart';
import 'package:zynetix_board/engine/pack_store.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/main.dart';

final seedIndex = jsonDecode(File('assets/packs/index.json').readAsStringSync()) as List;
final trusted = parseTrustedKey(File('assets/packs/trusted-key.json').readAsStringSync());
List<int> seedBytes(int i) => File('assets/packs/${seedIndex[i]['file']}').readAsBytesSync();

/// All seed packs installed once per test file (installing 270 packs per test was slow and left
/// ~80 MB behind each time). Each file uses its own folder, keyed by process id, and folders left
/// by earlier runs whose process has ended are removed.
PackStore? _seeded;

Future<PackStore> seededStore() async {
  if (_seeded != null) return _seeded!;
  final root = Directory.systemTemp;
  for (final d in root.listSync().whereType<Directory>()) {
    final m = RegExp(r'zx-board-test-(\d+)$').firstMatch(d.path);
    if (m != null && int.parse(m[1]!) != pid && !Directory('/proc/${m[1]}').existsSync()) {
      try {
        d.deleteSync(recursive: true);
      } on FileSystemException {
        // Another test process tidied it first.
      }
    }
  }
  final dir = Directory('${root.path}/zx-board-test-$pid');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync();
  final store = PackStore(dir, trustedKeys: {trusted.key: trusted.value});
  for (var i = 0; i < seedIndex.length; i++) {
    await store.install(seedBytes(i) as dynamic);
  }
  return _seeded = store;
}

Map<String, Map<String, List<Chapter>>> fileSyllabus() {
  final out = <String, Map<String, List<Chapter>>>{};
  final index = jsonDecode(File('assets/syllabus/index.json').readAsStringSync()) as Map<String, dynamic>;
  for (final s in (index['subjects'] as List).cast<Map<String, dynamic>>()) {
    final list = jsonDecode(File('assets/syllabus/${s['file']}').readAsStringSync()) as List;
    (out[s['subject'] as String] ??= {})[s['year'] as String] = [for (final c in list) Chapter.fromJson(c as Map<String, dynamic>)];
  }
  return out;
}

Future<Services> testServices({Map<String, Object> prefs = const {}, DateTime? now}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await seededStore();
  return Services(
    config: await BoardConfig.load(),
    store: store,
    outbox: Outbox(File('${Directory.systemTemp.createTempSync('outbox').path}/outbox.jsonl')),
    narrator: TimedNarrator(perWord: Duration.zero),
    syllabus: fileSyllabus(),
    embeds: PlaceholderEmbeds(),
    clock: now == null ? null : () => now,
  );
}

/// A 75" board in landscape.
Future<void> pumpBoard(WidgetTester t, Services s, {Widget? home}) async {
  t.view.physicalSize = const Size(1920, 1080);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(home == null ? ZynetixBoardApp(services: s) : ZynetixBoardApp(services: s, home: home));
  await t.pump();
}

/// A temporary folder that is deleted when the current test ends.
Directory tmpDir(String prefix) {
  final d = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (d.existsSync()) d.deleteSync(recursive: true);
  });
  return d;
}
