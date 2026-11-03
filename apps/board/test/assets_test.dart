import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/pack_store.dart';

/// Start-up reads these through the asset bundle (main.dart); this fails if pubspec stops
/// declaring them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seed packs, trusted key and syllabus are bundled and install from the asset bundle', () async {
    final key = parseTrustedKey(await rootBundle.loadString('assets/packs/trusted-key.json'));
    final store = PackStore(Directory.systemTemp.createTempSync('p'), trustedKeys: {key.key: key.value});
    await Services.installSeedPacks(store, rootBundle);
    expect(store.packs.length, 106);
    final syllabus = await Services.loadSyllabus(rootBundle);
    final index = jsonDecode(await rootBundle.loadString('assets/syllabus/index.json')) as Map<String, dynamic>;
    final expected = (index['subjects'] as List).fold<int>(0, (a, s) => a + (s['chapters'] as int));
    expect(syllabus.values.expand((y) => y.values).expand((c) => c).length, expected);
    expect(syllabus.keys, containsAll(['physics', 'computer_science', 'accountancy', 'english']));
  });
}
