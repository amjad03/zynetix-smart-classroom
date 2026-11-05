// Video-style narration: the AutoPlayer shows each step as its clip starts and moves on when the
// clip ends; asking steps wait for the teacher; Pause, Manual and missing audio behave.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/auto_play.dart';
import 'package:zynetix_board/engine/lesson_controller.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/narrator.dart';
import 'package:zynetix_board/engine/pack_store.dart';
import 'package:zynetix_board/engine/period.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/engine/voice.dart';

/// A player the test drives: each clip plays until [finish].
class FakePlayer implements VoicePlayer {
  final played = <String>[];
  Completer<bool>? _cur;
  bool paused = false;
  int resumes = 0;
  bool get playing => _cur != null && !_cur!.isCompleted;

  @override
  Future<bool> play(VoiceClip clip) {
    played.add(clip.path.split('/').last);
    return (_cur = Completer<bool>()).future;
  }

  void finish() {
    if (playing) _cur!.complete(true);
  }

  @override
  Future<void> pause() async => paused = true;
  @override
  Future<void> resume() async {
    paused = false;
    resumes++;
  }

  @override
  Future<void> stop() async {
    if (playing) _cur!.complete(false);
  }

  @override
  Future<void> dispose() async {}
}

Map<String, dynamic> line(String en, {int? ms}) => {
  'say': {'en': en, 'kn': 'ಕ $en'},
  'ms': ?(ms == null ? null : {'en': ms}),
};

final lessonJson = {
  'id': 'ch.t1.lesson',
  'chapterId': 'ch',
  'topicId': 'ch.t1',
  'title': {'en': 'T'},
  'minutes': 40,
  'blocks': [
    {
      'id': 'hook',
      'type': 'intro',
      'reveal': true,
      'heading': {'en': 'H'},
      'hook': {'en': 'h'},
      'cards': [
        {'title': {'en': 'A'}},
        {'title': {'en': 'B'}},
      ],
      'voice': [line('one', ms: 20), line('two', ms: 20)],
    },
    {
      'id': 'think',
      'type': 'class_quiz',
      'style': 'pause',
      'questionIds': ['q1'],
      'voice': [line('pause and think', ms: 20), line('the answer', ms: 20)],
    },
    {
      'id': 'rule',
      'type': 'concept',
      'body': {'en': 'b'},
      'voice': [line('remember this', ms: 20)],
    },
  ],
};

final question = Question.fromJson({
  'id': 'q1',
  'chapterId': 'ch',
  'topicId': 'ch.t1',
  'stem': {'en': 'Which?'},
  'options': [
    {'en': 'a'},
    {'en': 'b'},
  ],
  'answer': 0,
  'exams': ['PUC'],
  'difficulty': 'easy',
  'format': 'either_or',
});

final lesson = Lesson.fromJson(lessonJson);
final pack = InstalledPack(
  id: 'pk',
  version: '1.0.0',
  chapter: Chapter(id: 'ch', subject: 'physics', year: 'puc1', number: 1, title: const L10n('C'), topics: [Topic('ch.t1', const L10n('T'), null)]),
  lessons: {'ch.t1': lesson},
  questions: {'q1': question},
  mediaDir: '/nowhere',
);

/// A voice pack with a clip for every line, except [skip] (block.step), and [stale] said for older text.
VoicePack voicePack({Set<String> skip = const {}, Set<String> stale = const {}}) => VoicePack(
  id: 'pk-audio-en',
  packId: 'pk',
  lang: Lang.en,
  version: '1.0.0',
  dir: '/voice',
  voice: const {},
  clips: {
    for (final b in lesson.blocks)
      for (var k = 1; k <= (b.raw['voice'] as List).length; k++)
        if (!skip.contains('${b.id}.$k'))
          'ch.t1.lesson/${b.id}.$k': (file: '${b.id}.$k.opus', ms: 20, sha: lineSha(stale.contains('${b.id}.$k') ? 'old words' : voiceLine(b, k, Lang.en)!)),
  },
);

LessonController controller({List<Block>? blocks}) => LessonController(
  pack: pack,
  lesson: lesson,
  blocks: blocks,
  narrator: TimedNarrator(perWord: Duration.zero),
  lang: Lang.en,
  recorder: SessionRecorder.raw(outbox: Outbox(File('${Directory.systemTemp.createTempSync('ap').path}/o.jsonl')), sectionId: 's', mode: 'teacher', chapterId: 'ch', topicId: 'ch.t1', lessonId: lesson.id, packVersion: '1'),
);

Future<void> settle([int ms = 40]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('a step appears with its clip and the next one follows when the clip ends', () async {
    final c = controller(), p = FakePlayer();
    final vp = voicePack();
    final a = AutoPlayer(c: c, player: p, trackFor: (l) => VoiceTrack(vp, lesson.id, l), gap: const Duration(milliseconds: 5))..start();
    await settle();
    expect(p.played, ['hook.1.opus']);
    expect((c.index, c.revealed), (0, 1));
    expect(a.phase, PlayPhase.speaking);
    p.finish();
    await settle();
    expect((c.index, c.revealed), (0, 2), reason: 'the second card shows when its clip starts');
    expect(p.played.last, 'hook.2.opus');
    p.finish();
    await settle();
    expect(c.current.id, 'think');
    expect(p.played.last, 'think.1.opus');
    a.dispose();
  });

  test('a pause-and-think question waits for the teacher; the answer then plays and Auto carries on', () async {
    final c = controller(), p = FakePlayer();
    final vp = voicePack();
    final a = AutoPlayer(c: c, player: p, trackFor: (l) => VoiceTrack(vp, lesson.id, l), gap: const Duration(milliseconds: 5))..start();
    c.goTo(1);
    await settle();
    expect(p.played.last, 'think.1.opus');
    p.finish();
    await settle();
    expect(a.phase, PlayPhase.waiting);
    expect((c.index, c.revealed), (1, 1));
    await settle(60);
    expect((c.index, c.revealed), (1, 1), reason: 'still waiting');
    c.revealTo(2); // the class answered: the answer shows
    await settle();
    expect(p.played.last, 'think.2.opus');
    p.finish();
    await settle();
    expect(c.current.id, 'rule');
    p.finish();
    await settle();
    expect(a.phase, PlayPhase.done, reason: 'the last step of the lesson');
    a.dispose();
  });

  test('Pause pauses the clip and holds the lesson; Resume carries on from there', () async {
    final c = controller(), p = FakePlayer();
    final vp = voicePack();
    final a = AutoPlayer(c: c, player: p, trackFor: (l) => VoiceTrack(vp, lesson.id, l), gap: const Duration(milliseconds: 5))..start();
    await settle();
    c.setPaused(true);
    await settle();
    expect(p.paused, isTrue);
    expect(p.played, ['hook.1.opus']);
    c.setPaused(false);
    await settle();
    expect(p.paused, isFalse);
    expect(p.resumes, 1);
    expect(p.played, ['hook.1.opus'], reason: 'resumed, not restarted');
    p.finish();
    await settle();
    expect(c.revealed, 2);
    // Paused during the gap: nothing moves until Resume.
    p.finish();
    c.setPaused(true);
    await settle(60);
    expect(c.index, 0);
    c.setPaused(false);
    await settle();
    expect(c.current.id, 'think');
    a.dispose();
  });

  test('Manual: each step says its line, but only Next moves on; Back in Auto replays a block from its start', () async {
    final c = controller(), p = FakePlayer();
    final vp = voicePack();
    final a = AutoPlayer(c: c, player: p, trackFor: (l) => VoiceTrack(vp, lesson.id, l), mode: PlayMode.manual, gap: const Duration(milliseconds: 5))..start();
    await settle();
    p.finish();
    await settle(60);
    expect((c.index, c.revealed), (0, 1));
    expect(a.phase, PlayPhase.idle);
    c.next();
    await settle();
    expect(p.played, ['hook.1.opus', 'hook.2.opus']);
    // Switching to Auto on a step already said moves straight on.
    p.finish();
    await settle();
    a.setMode(PlayMode.auto);
    await settle();
    expect(c.current.id, 'think');
    a.back();
    await settle();
    expect((c.index, c.revealed), (0, 1));
    expect(p.played.last, 'hook.1.opus');
    a.dispose();
  });

  test('no audio pack: the lesson is silent, and Auto still moves on after each line\'s length', () async {
    final c = controller(), p = FakePlayer();
    final a = AutoPlayer(c: c, player: p, trackFor: (_) => null, gap: const Duration(milliseconds: 5))..start();
    expect(a.hasVoice, isFalse);
    await settle(80);
    expect(p.played, isEmpty);
    expect(c.index, 1, reason: 'both cards shown for their recorded 20 ms, then the next block');
    a.dispose();
  });

  test('a missing or stale clip is silent; the other steps still play', () async {
    final c = controller(), p = FakePlayer();
    final vp = voicePack(skip: {'hook.1'}, stale: {'hook.2'});
    final track = VoiceTrack(vp, lesson.id, Lang.en);
    expect(track.clip(lesson.blocks[0], 1), isNull);
    expect(track.clip(lesson.blocks[0], 2), isNull, reason: 'made for older text');
    expect(track.coverage(lesson), 3);
    final a = AutoPlayer(c: c, player: p, trackFor: (_) => track, gap: const Duration(milliseconds: 5))..start();
    await settle(100);
    expect(c.current.id, 'think');
    expect(p.played, ['think.1.opus']);
    a.dispose();
  });

  test('Self-Learning: asking steps carry on after their narration and the period moves blocks', () async {
    final plan = PeriodPlanner.plan(lesson, periodMinutes: 40);
    final c = controller(blocks: plan.blocks), p = FakePlayer();
    final vp = voicePack();
    final a = AutoPlayer(c: c, player: p, trackFor: (l) => VoiceTrack(vp, lesson.id, l), teacher: false, advanceBlocks: false, gap: const Duration(milliseconds: 5));
    final r = PeriodRunner(c: c, plan: plan, periodSeconds: 2400, autoTick: false, voice: a)..start();
    await settle();
    expect(c.voiceDriven, isTrue);
    p.finish();
    await settle();
    p.finish();
    await settle();
    expect(a.blockDone, isTrue);
    expect(c.current.id, 'hook', reason: 'the period decides when to move on');
    r.tick();
    await settle();
    expect(c.current.id, 'rule', reason: 'the period puts the lesson before the quiz');
    p.finish();
    await settle();
    r.tick();
    await settle();
    expect(c.current.id, 'think');
    p.finish();
    await settle();
    expect(c.revealed, 2, reason: 'no teacher: the answer follows the question');
    expect(a.phase, isNot(PlayPhase.waiting));
    p.finish();
    await settle();
    expect(a.blockDone, isTrue);
    r.tick();
    expect(r.homework, isTrue);
    r.dispose();
    a.dispose();
  });

  group('audio packs', () {
    late SimpleKeyPair kp;
    late List<int> pub;
    setUpAll(() async {
      kp = await Ed25519().newKeyPair();
      pub = (await kp.extractPublicKey()).bytes;
    });

    Future<Uint8List> build({String version = '1.0.0', bool tamper = false, String kind = 'audio'}) async {
      final clip = utf8.encode('OggS fake opus');
      final m = {
        'schemaVersion': 1,
        'kind': kind,
        'id': 'pk-audio-en',
        'packId': 'pk',
        'chapterId': 'ch',
        'lang': 'en',
        'version': version,
        'createdAt': '2026-11-05T00:00:00Z',
        'keyId': 'test',
        'voice': {'model': 'hexgrad/Kokoro-82M', 'voice': 'am_michael', 'licence': 'Apache-2.0'},
        'clips': [
          {'lessonId': 'ch.t1.lesson', 'blockId': 'rule', 'step': 1, 'clip': 'rule.1', 'file': 'audio/t1/rule.1.opus', 'ms': 1500, 'sha': lineSha('remember this')},
        ],
        'files': [
          {'path': 'audio/t1/rule.1.opus', 'sha256': c.sha256.convert(clip).toString(), 'bytes': clip.length},
        ],
      };
      final mb = utf8.encode(jsonEncode(m));
      final sig = await Ed25519().sign(mb, keyPair: kp);
      final zip = Archive()
        ..addFile(ArchiveFile.bytes('manifest.json', mb))
        ..addFile(ArchiveFile.bytes('manifest.sig', sig.bytes))
        ..addFile(ArchiveFile.bytes('audio/t1/rule.1.opus', tamper ? utf8.encode('changed') : clip));
      return Uint8List.fromList(ZipEncoder().encode(zip));
    }

    test('installs a signed audio pack and gives the lesson its clips', () async {
      final dir = Directory.systemTemp.createTempSync('voice');
      final store = VoiceStore(dir, trustedKeys: {'test': pub});
      expect(store.track(pack, lesson, Lang.en), isNull);
      expect(await store.install(await build()), isTrue);
      expect(await store.install(await build()), isFalse, reason: 'same version');
      final t = store.track(pack, lesson, Lang.en)!;
      final clip = t.clip(lesson.blocks[2], 1)!;
      expect(clip.ms, 1500);
      expect(File(clip.path).readAsStringSync(), 'OggS fake opus');
      expect(store.track(pack, lesson, Lang.kn), isNull, reason: 'Kannada not downloaded');
      // Survives a restart.
      final again = VoiceStore(dir, trustedKeys: {'test': pub})..loadAll();
      expect(again.track(pack, lesson, Lang.en)!.clip(lesson.blocks[2], 1), isNotNull);
    });

    test('refuses an unknown key, a changed clip, and a content pack', () async {
      final store = VoiceStore(Directory.systemTemp.createTempSync('voice'), trustedKeys: {'test': pub});
      final other = VoiceStore(Directory.systemTemp.createTempSync('voice'), trustedKeys: {'other': pub});
      await expectLater(other.install(await build()), throwsA(isA<PackError>()));
      await expectLater(store.install(await build(tamper: true)), throwsA(isA<PackError>()));
      await expectLater(store.install(await build(kind: 'content')), throwsA(isA<PackError>()));
    });
  });
}
