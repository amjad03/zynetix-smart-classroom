import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/narrator.dart';
import 'package:zynetix_board/engine/pack_store.dart';
import 'package:zynetix_board/engine/period.dart';
import 'package:zynetix_board/engine/lesson_controller.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/features/participation.dart';
import 'dart:io';

import 'helpers.dart';

void main() {
  group('PackStore', () {
    test('installs every seed pack, with all lessons and questions', () async {
      final store = await seededStore();
      expect(store.packs.length, 270); // every chapter of every subject, both years
      final motion = store.byChapter('puc1-physics-02-motion-in-a-straight-line')!;
      expect(motion.lessons.length, 5);
      expect(motion.questions.length, 19);
      expect(File('${motion.mediaDir}/phet/projectile-motion.html').existsSync(), isTrue);
    });

    test('does not reinstall the same version', () async {
      final store = await seededStore();
      expect(await store.install(Uint8List.fromList(seedBytes(0))), isFalse);
    });

    test('rejects a pack whose manifest was tampered with', () async {
      final store = PackStore(Directory.systemTemp.createTempSync('p'), trustedKeys: {trusted.key: trusted.value});
      // Re-zip the pack with the manifest's version bumped: the signature no longer matches.
      final zip = ZipDecoder().decodeBytes(seedBytes(1));
      final out = Archive();
      for (final f in zip.files) {
        var data = f.readBytes()!;
        if (f.name == 'manifest.json') data = Uint8List.fromList(utf8.encode(utf8.decode(data).replaceFirst('"1.0.0"', '"9.0.0"')));
        out.addFile(ArchiveFile.bytes(f.name, data));
      }
      await expectLater(store.install(Uint8List.fromList(ZipEncoder().encodeBytes(out))), throwsA(isA<PackError>()));
      expect(store.packs, isEmpty);
    });

    test('rejects a pack signed with an unknown key', () async {
      final store = PackStore(Directory.systemTemp.createTempSync('p'), trustedKeys: {'other': List.filled(32, 1)});
      await expectLater(store.install(Uint8List.fromList(seedBytes(0))), throwsA(isA<PackError>()));
    });

    test('compares versions', () {
      expect(PackStore.compareVersions('1.10.0', '1.9.3'), greaterThan(0));
      expect(PackStore.compareVersions('1.0.0', '1.0.0'), 0);
    });
  });

  group('PeriodPlanner', () {
    late InstalledPack pack;
    setUpAll(() async => pack = (await seededStore()).byChapter('puc2-chemistry-01-solutions')!);

    test('orders lesson → examples → quiz → recap and fits a 40-minute period', () {
      for (final l in pack.lessons.values) {
        final p = PeriodPlanner.plan(l, periodMinutes: 40);
        final phases = [for (final s in p.steps) s.phase.index];
        expect(phases, [...phases]..sort(), reason: l.id);
        expect(p.steps.last.phase, Phase.recap);
        expect(p.steps.any((s) => s.phase == Phase.quiz), isTrue);
        expect(p.plannedSeconds, lessThanOrEqualTo(p.budgetSeconds), reason: l.id);
      }
    });

    test('drops optional blocks first in a short period, never the quiz or recap', () {
      final l = pack.lessons['puc2-chemistry-01-solutions.t1']!; // has a 3D model, a sim, a lab and a trick
      final p = PeriodPlanner.plan(l, periodMinutes: 10);
      expect(p.dropped, isNotEmpty);
      expect(p.steps.map((s) => s.block.type), containsAll([BlockType.classQuiz, BlockType.recap, BlockType.intro]));
    });
  });

  group('PeriodRunner', () {
    test('runs a whole period by itself, logs the session and ends on homework', () async {
      final store = await seededStore();
      final pack = store.byChapter('puc1-physics-02-motion-in-a-straight-line')!;
      final lesson = pack.lessons.values.first;
      final outbox = Outbox(File('${Directory.systemTemp.createTempSync('o').path}/o.jsonl'));
      final plan = PeriodPlanner.plan(lesson, periodMinutes: 40);
      final c = LessonController(pack: pack, lesson: lesson, blocks: plan.blocks, narrator: TimedNarrator(perWord: Duration.zero), lang: Lang.en,
          recorder: SessionRecorder(outbox: outbox, sectionId: 's1', mode: 'self_learning', pack: pack, lesson: lesson));
      final r = PeriodRunner(c: c, plan: plan, periodSeconds: 40 * 60, autoTick: false)..start();
      final seen = <Phase>{};
      for (var i = 0; i < 40 * 60 && !r.homework; i++) {
        await Future<void>.delayed(Duration.zero); // let narration complete
        if (r.current.phase == Phase.quiz && r.elapsed > 5) r.onQuizFinished();
        r.tick();
        seen.add(r.phase);
      }
      expect(r.homework, isTrue);
      expect(seen, containsAll(Phase.values));
      expect(r.secondsLeft, greaterThan(0), reason: 'homework time is left at the end');
      final log = outbox.pending().single;
      expect(log['mode'], 'self_learning');
      expect(log['completed'], isTrue);
      expect((log['blocksShown'] as List).length, plan.steps.length);
    });

    test('pause stops the clock for the step', () async {
      final store = await seededStore();
      final pack = store.packs.first;
      final lesson = pack.lessons.values.first;
      final plan = PeriodPlanner.plan(lesson, periodMinutes: 40);
      final c = LessonController(pack: pack, lesson: lesson, blocks: plan.blocks, narrator: TimedNarrator(perWord: Duration.zero), lang: Lang.en,
          recorder: SessionRecorder(outbox: Outbox(File('${Directory.systemTemp.createTempSync('o').path}/o')), sectionId: 's', mode: 'self_learning', pack: pack, lesson: lesson));
      final r = PeriodRunner(c: c, plan: plan, periodSeconds: 2400, autoTick: false)..start();
      r.setPaused(true);
      for (var i = 0; i < 100; i++) {
        r.tick();
      }
      expect(r.step, 0);
      expect(r.elapsed, 0);
    });
  });

  group('participation', () {
    test('pickRoll never picks an excluded roll and returns null when none are left', () {
      final rnd = Random(1);
      for (var i = 0; i < 200; i++) {
        expect({3, 5}.contains(pickRoll(rnd, 6, {3, 5})), isFalse);
      }
      expect(pickRoll(rnd, 2, {1, 2}), isNull);
    });

    test('ClassRoom calls every present roll once before repeating', () {
      final room = ClassRoom(rollCount: 10, random: Random(7))..absent.add(4);
      final first = [for (var i = 0; i < 9; i++) room.nextRoll()!];
      expect(first.toSet().length, 9);
      expect(first, isNot(contains(4)));
      expect(room.nextRoll(), isNot(4));
    });

    test('teams split rolls evenly', () {
      expect([for (var r = 1; r <= 6; r++) teamOf(r, 2)], [0, 1, 0, 1, 0, 1]);
      expect([for (var r = 1; r <= 6; r++) teamOf(r, 3)], [0, 1, 2, 0, 1, 2]);
    });
  });
}
