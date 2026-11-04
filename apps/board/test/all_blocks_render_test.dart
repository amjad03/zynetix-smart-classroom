// Design sweep: every block of every lesson in the seeded packs (built from content/packs), drawn
// in the lesson player on a classroom board (1920 × 1080, classroom scale) and on a phone
// (390 × 844). Fails on any Flutter error: overflow, layout or paint exceptions, thrown errors.
// Problems are collected so one run lists everything to fix.
//
// It runs once per curriculum. A Karnataka PU section draws every lesson of every pack; a CBSE
// and an ISC section draw the lessons that section can open (its chapters and topics), with the
// blocks for that board, so CBSE-only and ISC-only blocks and chapters (ISC Commerce) are covered.
//
// Tagged `sweep`. It is part of the full run; on its own: flutter test -t sweep
// ZX_SWEEP=puc1-physics-02,puc2-chemistry limits it to lessons whose id starts with one of those;
// ZX_SWEEP_BOARD=isc (or kar_pu,cbse) limits it to those boards.
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

/// The section each curriculum's sweep runs as: its subjects, so the board shows every chapter.
const boards = <String, Map<String, Object>>{
  'kar_pu': {'sectionLabel': '1st PUC · A · PCMB'},
  'cbse': {
    'sectionLabel': 'Class 11 · A',
    'subjects': ['physics', 'chemistry', 'maths', 'biology', 'computer_science', 'accountancy', 'business_studies', 'economics', 'english'],
  },
  'isc': {
    'sectionLabel': 'Class XI · A',
    'subjects': ['physics', 'chemistry', 'maths', 'biology', 'computer_science', 'accountancy', 'business_studies', 'commerce', 'economics', 'english'],
  },
};

/// The lessons a section on [board] can open, by pack: the packs of its chapters, the topics it
/// teaches. Karnataka PU draws every lesson of every pack.
List<(InstalledPack, Lesson)> lessonsFor(Services s, String board) {
  final packs = s.store.packs.toList()..sort((a, b) => a.id.compareTo(b.id));
  if (board == 'kar_pu') {
    return [
      for (final p in packs)
        for (final l in p.lessons.values) (p, l),
    ];
  }
  final chapters = {
    for (final sub in s.subjects)
      for (final y in const ['puc1', 'puc2']) ...s.chapters(sub, y).map((c) => c.id),
  };
  return [
    for (final p in packs)
      if (chapters.contains(p.chapter.id))
        for (final t in p.chapter.topicsFor(board))
          if (p.lessons[t.id] case final l?) (p, l),
  ];
}

void main() {
  final verbose = Platform.environment['ZX_SWEEP_VERBOSE'] != null;
  final only = (Platform.environment['ZX_SWEEP'] ?? '').split(',').where((s) => s.isNotEmpty).toList();
  final onlyBoards = (Platform.environment['ZX_SWEEP_BOARD'] ?? '').split(',').where((s) => s.isNotEmpty).toSet();
  for (final board in boards.entries) {
    if (onlyBoards.isNotEmpty && !onlyBoards.contains(board.key)) continue;
    for (final e in sizes.entries) {
      testWidgets('every block renders cleanly: ${board.key} ${e.key}', (t) async {
        final (size, display) = e.value;
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final base = await testServices(prefs: {'displaySize': display, 'board': board.key, ...board.value});
        expect(base.config.board, board.key);
        final s = Services(config: base.config, store: base.store, outbox: base.outbox, narrator: base.narrator, syllabus: base.syllabus, embeds: SweepEmbeds(), clock: base.clock);
        final problems = <String>{};
        var where = '';
        final old = FlutterError.onError;
        FlutterError.onError = (d) {
          final p = '$where: ${d.exceptionAsString().split('\n').first}';
          if (problems.add(p)) debugPrint('PROBLEM ${board.key} ${e.key} $p');
          if (verbose) debugPrint(d.toString());
        };
        if (board.key != 'kar_pu') {
          // Every pack written for this board is reachable from its subject tabs.
          final reached = {for (final (p, _) in lessonsFor(s, board.key)) p.chapter.id};
          final unreached = [
            for (final p in s.store.packs)
              if (p.chapter.forBoard(board.key) && !reached.contains(p.chapter.id)) p.chapter.id,
          ];
          expect(unreached, isEmpty, reason: 'packs for ${board.key} the section cannot open');
          if (board.key == 'isc') expect(reached.where((c) => c.contains('-commerce-')), isNotEmpty, reason: 'ISC Commerce');
        }
        var blocks = 0, lessons = 0;
        final chapters = <String>{};
        try {
          for (final (pack, lesson) in lessonsFor(s, board.key)) {
            if (only.isNotEmpty && !only.any(lesson.id.startsWith)) continue;
            lessons++;
            chapters.add(pack.chapter.id);
            where = '${lesson.id} (open)';
            await t.pumpWidget(ZynetixBoardApp(key: UniqueKey(), services: s, home: LessonPlayerScreen(pack: pack, lesson: lesson)));
            await t.pump(const Duration(milliseconds: 100));
            final c = t.widget<BlockView>(find.byType(BlockView)).c;
            expect(c.blocks.length, pack.lessonFor(lesson, board.key).blocks.length, reason: '${lesson.id}: the player shows the ${board.key} blocks');
            for (var i = 0; i < c.blocks.length; i++) {
              final b = c.blocks[i];
              where = '${lesson.id} #$i ${b.id} (${b.type.wire})';
              c.goTo(i);
              await t.pump();
              await t.pump(const Duration(milliseconds: 600));
              blocks++;
              final x = t.takeException();
              if (x != null && problems.add('$where: ${x.toString().split('\n').first}')) debugPrint('PROBLEM ${board.key} ${e.key} $where: $x');
            }
          }
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        } finally {
          FlutterError.onError = old;
        }
        debugPrint('${board.key} ${e.key}: ${chapters.length} chapters, $lessons lessons, $blocks blocks, ${problems.length} problems');
        expect(blocks, greaterThan(0));
        expect(problems, isEmpty, reason: problems.join('\n'));
      }, timeout: const Timeout(Duration(minutes: 60)));
    }
  }
}
