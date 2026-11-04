// Design sweep: every block of every lesson in the seeded packs (built from content/packs), drawn
// in the lesson player on a classroom board (1920 × 1080, classroom scale) and on a phone
// (390 × 844). Fails on any Flutter error: overflow, layout or paint exceptions, thrown errors.
// Problems are collected so one run lists everything to fix.
//
// Tagged `sweep`. It is part of the full run; on its own: flutter test -t sweep
// ZX_SWEEP=puc1-physics-02,puc2-chemistry limits it to lessons whose id starts with one of those.
@Tags(['sweep'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/block_view.dart';
import 'package:zynetix_board/blocks/embeds.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/main.dart';

import 'helpers.dart';

/// The real Kinetix labs, animations and CS players; a placeholder only for the WebView pieces
/// (3D models, PhET pages), which the test engine cannot draw.
class SweepEmbeds extends KinetixEmbeds {
  final _stub = PlaceholderEmbeds();
  @override
  Widget model3d(Block b, Lang lang) => _stub.model3d(b, lang);
  @override
  Widget simulation(Block b, InstalledPack pack, Lang lang) => b.s('source') == 'phet' ? _stub.simulation(b, pack, lang) : super.simulation(b, pack, lang);
}

const sizes = <String, (Size, String)>{
  'classroom 1920x1080': (Size(1920, 1080), 'classroom'),
  'phone 390x844': (Size(390, 844), 'normal'),
};

void main() {
  final verbose = Platform.environment['ZX_SWEEP_VERBOSE'] != null;
  final only = (Platform.environment['ZX_SWEEP'] ?? '').split(',').where((s) => s.isNotEmpty).toList();
  for (final e in sizes.entries) {
    testWidgets('every block renders cleanly: ${e.key}', (t) async {
      final (size, display) = e.value;
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final base = await testServices(prefs: {'displaySize': display});
      final s = Services(config: base.config, store: base.store, outbox: base.outbox, narrator: base.narrator, syllabus: base.syllabus, embeds: SweepEmbeds(), clock: base.clock);
      final problems = <String>{};
      var where = '';
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        final p = '$where: ${d.exceptionAsString().split('\n').first}';
        if (problems.add(p)) debugPrint('PROBLEM ${e.key} $p');
        if (verbose) debugPrint(d.toString());
      };
      var blocks = 0;
      try {
        final packs = s.store.packs.toList()..sort((a, b) => a.id.compareTo(b.id));
        for (final pack in packs) {
          for (final lesson in pack.lessons.values) {
            if (only.isNotEmpty && !only.any(lesson.id.startsWith)) continue;
            where = '${lesson.id} (open)';
            await t.pumpWidget(ZynetixBoardApp(key: UniqueKey(), services: s, home: LessonPlayerScreen(pack: pack, lesson: lesson)));
            await t.pump(const Duration(milliseconds: 100));
            final c = t.widget<BlockView>(find.byType(BlockView)).c;
            for (var i = 0; i < c.blocks.length; i++) {
              final b = c.blocks[i];
              where = '${lesson.id} #$i ${b.id} (${b.type.wire})';
              c.goTo(i);
              await t.pump();
              await t.pump(const Duration(milliseconds: 600));
              blocks++;
              final x = t.takeException();
              if (x != null && problems.add('$where: ${x.toString().split('\n').first}')) debugPrint('PROBLEM ${e.key} $where: $x');
            }
          }
        }
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      } finally {
        FlutterError.onError = old;
      }
      debugPrint('${e.key}: $blocks blocks, ${problems.length} problems');
      expect(blocks, greaterThan(0));
      expect(problems, isEmpty, reason: problems.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 60)));
  }
}
