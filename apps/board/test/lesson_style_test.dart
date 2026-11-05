// The "one idea at a time" lesson style (Physical quantities, puc1 physics t1, read from its
// source in content/packs): Next reveals a block's cards before moving on, Back shows a block
// whole, Pause and think answers on a tap, and every block fits a phone and a board in English
// and Kannada.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/lesson_controller.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/narrator.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/engine/voice.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/main.dart';

import 'helpers.dart';

const topic = 'puc1-physics-01-units-and-measurement.t1';

Future<(Services, InstalledPack, Lesson)> load({Map<String, Object> prefs = const {}}) async {
  final s = await testServices(prefs: prefs);
  final pack = sourcePack(s.lessonFor(topic)!.pack, 'puc1-physics-units-and-measurement');
  return (s, pack, pack.lessons[topic]!);
}

void main() {
  test('the lesson uses the new styles and every question it names exists', () async {
    final (_, pack, lesson) = await load();
    final styles = {for (final b in lesson.blocks) ?b.style};
    expect(styles, containsAll(['pause', 'solve', 'rule', 'trap', 'recall']));
    expect(lesson.blocks.where((b) => b.speaker != null), isNotEmpty);
    for (final b in lesson.blocks) {
      for (final id in [...b.ids('questionIds'), ...b.ids('homeworkQuestionIds')]) {
        expect(pack.questions[id], isNotNull, reason: '${b.id} → $id');
      }
    }
    final either = pack.questions['1p01-q32']!;
    expect(either.format, 'either_or');
    expect(either.options, hasLength(2));
    expect(pack.questions['1p01-q31']!.solution, hasLength(4));
  });

  test('Next reveals a block one idea at a time, then moves on; Back shows a block whole', () async {
    final (s, pack, lesson) = await load();
    final rec = SessionRecorder.raw(outbox: s.outbox, sectionId: 's', mode: 'teacher', chapterId: lesson.chapterId, topicId: lesson.topicId, lessonId: lesson.id, packVersion: '1');
    final c = LessonController(pack: pack, lesson: lesson, narrator: TimedNarrator(perWord: Duration.zero), recorder: rec, lang: Lang.en);
    expect(c.current.id, 'hook');
    expect(c.revealTotal, 3); // three cards
    expect(c.revealed, 1);
    c.next();
    c.next();
    expect((c.index, c.revealed), (0, 3));
    c.next();
    expect(c.current.id, 'number-alone');
    expect(c.revealed, 1);
    c.back();
    expect(c.current.id, 'hook');
    expect(c.revealed, 3);
    // Pause and think: the question, then its answer.
    c.goTo(lesson.blocks.indexWhere((b) => b.style == 'pause'));
    expect(c.revealTotal, 2);
    // The exam-pattern question: the question, then one step per solution line.
    c.goTo(lesson.blocks.indexWhere((b) => b.style == 'solve'));
    expect(c.revealTotal, 5);
    c.dispose();
  });

  testWidgets('Pause and think: a tap shows the right answer and why, and is recorded', (t) async {
    final (s, pack, lesson) = await load(prefs: {'displaySize': 'classroom'});
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [lesson.blocks.firstWhere((b) => b.id == 'think-temperature')])));
    expect(find.text('Tap the class answer'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('think-1'))); // "Derived": wrong
    await t.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('A thermometer reads it directly'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  group('chapter voice in Teacher Mode', () {
    /// A signed audio pack with clips for the hook's three lines (1 s each).
    Future<(Uint8List, List<int>)> audioPack(Lesson lesson) async {
      final kp = await Ed25519().newKeyPair();
      final hook = lesson.blocks.first;
      final clips = [
        for (var k = 1; k <= 3; k++)
          {'lessonId': lesson.id, 'blockId': hook.id, 'step': k, 'clip': '${hook.id}.$k', 'file': 'audio/t1/${hook.id}.$k.opus', 'ms': 1000, 'sha': lineSha(voiceLine(hook, k, Lang.en)!)},
      ];
      final data = utf8.encode('OggS');
      final m = utf8.encode(jsonEncode({
        'schemaVersion': 1, 'kind': 'audio', 'id': 'puc1-physics-units-and-measurement-audio-en', 'packId': 'puc1-physics-units-and-measurement',
        'chapterId': lesson.chapterId, 'lang': 'en', 'version': '1.0.0', 'createdAt': '2026-11-05T00:00:00Z', 'keyId': 't',
        'voice': {'model': 'hexgrad/Kokoro-82M', 'licence': 'Apache-2.0'}, 'clips': clips,
        'files': [for (final c in clips) {'path': c['file'], 'sha256': crypto.sha256.convert(data).toString(), 'bytes': data.length}],
      }));
      final zip = Archive()
        ..addFile(ArchiveFile.bytes('manifest.json', m))
        ..addFile(ArchiveFile.bytes('manifest.sig', (await Ed25519().sign(m, keyPair: kp)).bytes));
      for (final c in clips) {
        zip.addFile(ArchiveFile.bytes(c['file'] as String, data));
      }
      return (Uint8List.fromList(ZipEncoder().encode(zip)), (await kp.extractPublicKey()).bytes);
    }

    Future<Services> withVoice(Services s, VoiceStore v) async =>
        Services(config: s.config, store: s.store, outbox: s.outbox, narrator: s.narrator, syllabus: s.syllabus, embeds: s.embeds, voice: v);

    testWidgets('no voice downloaded: the lesson is silent, in Manual, with a Download voice chip', (t) async {
      final (s, pack, lesson) = await load(prefs: {'displaySize': 'classroom'});
      final v = VoiceStore(Directory.systemTemp.createTempSync('voice'), trustedKeys: const {});
      await pumpBoard(t, await withVoice(s, v), home: LessonPlayerScreen(pack: pack, lesson: lesson));
      expect(find.byKey(const ValueKey('downloadVoice')), findsOneWidget);
      expect(find.byTooltip('Manual: tap Next'), findsOneWidget);
      await t.pump(const Duration(seconds: 10));
      expect(find.byKey(const ValueKey('block:hook')), findsOneWidget, reason: 'Manual: nothing moves by itself');
      // Not activated: the chip says why, and the board stays usable.
      await t.tap(find.byKey(const ValueKey('downloadVoice')));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(s.config.voiceWanted, contains('puc1-physics-units-and-measurement|en'));
    });

    testWidgets('with the voice: Auto plays each step as its clip ends and waits at an asking step', (t) async {
      final (s, pack, lesson) = await load(prefs: {'displaySize': 'classroom'});
      final (bytes, pub) = await audioPack(lesson);
      final v = VoiceStore(Directory.systemTemp.createTempSync('voice'), trustedKeys: {'t': pub});
      await t.runAsync(() => v.install(bytes));
      await pumpBoard(t, await withVoice(s, v), home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, lesson.blocks.take(5).toList())));
      expect(find.byKey(const ValueKey('downloadVoice')), findsNothing);
      expect(find.byTooltip('Auto: plays like a video'), findsOneWidget);
      // Three clips of 1 s and their gaps: then the next block, whose lines have no clip here and
      // are shown for their reading time.
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      expect(find.byKey(const ValueKey('block:hook')), findsOneWidget);
      await t.pump(const Duration(milliseconds: 2500)); // 3 × (1 s + 0.7 s gap)
      expect(find.byKey(const ValueKey('block:number-alone')), findsOneWidget);
      for (var i = 0; i < 120 && find.byKey(const ValueKey('yourTurn')).evaluate().isEmpty; i++) {
        await t.pump(const Duration(seconds: 1));
      }
      expect(find.byKey(const ValueKey('block:bench')), findsOneWidget, reason: 'the measuring bench waits for the class');
      expect(find.byKey(const ValueKey('yourTurn')), findsOneWidget);
      // Manual: the teacher takes over.
      await t.tap(find.byKey(const ValueKey('mode')));
      await t.pump();
      expect(find.byTooltip('Manual: tap Next'), findsOneWidget);
      expect(s.config.playMode, 'manual');
      await t.pumpWidget(const SizedBox());
    });
  });

  for (final lang in Lang.values) {
    for (final (name, size, display) in [('board', const Size(1920, 1080), 'classroom'), ('phone', const Size(390, 844), 'normal')]) {
      testWidgets('every block fits: $name, ${lang.name}', (t) async {
        final (s, pack, lesson) = await load(prefs: {'displaySize': display, 'lang': lang.name});
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(ZynetixBoardApp(services: s, home: LessonPlayerScreen(pack: pack, lesson: lesson)));
        await t.pump();
        final errors = <String>[];
        var seen = 0;
        for (var guard = 0; guard < 120; guard++) {
          await t.pump(const Duration(milliseconds: 300));
          final e = t.takeException();
          if (e != null) errors.add('step $guard: $e');
          if (find.byKey(const ValueKey('finish')).evaluate().isNotEmpty) break;
          await t.tap(find.byKey(const ValueKey('next')));
          seen++;
        }
        expect(errors, isEmpty);
        expect(find.byKey(const ValueKey('nextTeaser')), findsOneWidget);
        expect(seen, greaterThan(lesson.blocks.length));
      });
    }
  }
}

Lesson lessonWith(InstalledPack p, List<Block> blocks) {
  final l = p.lessons[topic]!;
  return Lesson(id: l.id, chapterId: l.chapterId, topicId: l.topicId, title: l.title, minutes: l.minutes, blocks: blocks);
}
