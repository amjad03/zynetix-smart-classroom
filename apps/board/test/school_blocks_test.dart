// The Zynetix School import on the board: explainer and concept-video blocks (read from their
// source in content/packs, as tools/school-import wrote them), the formula sheet, and the class
// tools fed from them. Videos are streamed, never downloaded: offline the block says so.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/concept_video_view.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/auto_play.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/voice.dart';
import 'package:zynetix_board/features/app/class_content.dart';
import 'package:zynetix_board/features/player.dart';

import 'fixtures.dart';
import 'helpers.dart';

const gravity = 'puc1-physics-02-motion-in-a-straight-line.t5';
const units = 'puc1-physics-01-units-and-measurement.t2';

Future<(Services, InstalledPack, Lesson)> load(String topic, String dir, {Map<String, Object> prefs = const {}}) async {
  final s = await testServices(prefs: prefs);
  final pack = sourcePack(s.lessonFor(topic)!.pack, dir);
  return (s, pack, pack.lessons[topic]!);
}

Block blockOf(Lesson l, BlockType t) => l.blocks.firstWhere((b) => b.type == t);

void main() {
  test('the model reads explainers, videos and formula sheets', () async {
    final (_, pack, lesson) = await load(gravity, 'puc1-physics-motion-in-a-straight-line');
    final ex = blockOf(lesson, BlockType.explainer);
    expect(ex.reveal, isTrue);
    expect(ex.revealSteps(pack), (ex.raw['watch'] as List).length);
    // Without voice lines the watch steps are read aloud.
    expect(voiceLine(ex, 2, Lang.en), contains('hit the ground together'));
    expect(AutoPlayer.waitsForTeacher(ex, 1, pack), isFalse);
    expect(AutoPlayer.waitsForTeacher(ex, ex.revealSteps(pack), pack), isTrue);

    final v = VideoRef.maybe({'provider': 'youtube', 'id': 'dQw4w9WgXcQ', 'title': {'en': 'Ohm'}, 'chapters': [{'at': 75, 'label': {'en': 'V = IR'}}]})!;
    expect(v.embedUrl(start: 75).toString(), 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?rel=0&modestbranding=1&playsinline=1&start=75');
    expect(v.chapters.single.$1, 75);
    expect(VideoRef.maybe({'provider': 'drive', 'id': '1D3Yt_Q_KOPlAuSLySW4UNTydCQO8Q25b', 'title': {'en': 'Ep 1'}})!.embedUrl().host, 'drive.google.com');
    expect(VideoRef.maybe({'provider': 'youtube', 'id': 'bad id!'}), isNull);

    final ce = (await load('puc2-physics-03-current-electricity.t1', 'puc2-physics-current-electricity')).$2;
    expect(ce.formulas.length, greaterThan(5));
    expect(ce.formulas.first.tex, isNotEmpty);
    final sheet = formulaSheet(ce, 'kar_pu');
    expect(sheet.items.length, greaterThanOrEqualTo(ce.formulas.length));
    expect(chapterExplainers(ce, 'kar_pu'), isNotEmpty);
    expect(SheetFormula.sheet({'formulas': [{'id': 'f', 'name': {'en': 'x'}, 'tex': ''}]}), isEmpty);
  });

  for (final (name, size, display) in [('board', const Size(1920, 1080), 'classroom'), ('phone', const Size(390, 844), 'normal')]) {
    testWidgets('explainer: misconception, watch steps on Next, try it, story, it\'s like ($name)', (t) async {
      final (s, pack, lesson) = await load(gravity, 'puc1-physics-motion-in-a-straight-line', prefs: {'displaySize': display});
      final ex = blockOf(lesson, BlockType.explainer);
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [ex])));
      t.view.physicalSize = size;
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Many people think'), findsOneWidget);
      expect(find.text('Actually'), findsOneWidget);
      expect(find.text('Heavier objects fall faster than light ones.'), findsOneWidget);
      expect(find.text('Gravity pulls everything down'), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('watch-next')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('watch-next')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Heavy and light, dropped together'), findsOneWidget);

      await t.ensureVisible(find.byKey(const ValueKey('ex-tab-tryIt')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('ex-tab-tryIt')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('try-step-0')), findsOneWidget);
      final opt = find.byKey(const ValueKey('try-0-opt-0'));
      if (opt.evaluate().isNotEmpty) {
        await t.ensureVisible(opt);
        await t.tap(opt);
        await t.pump(const Duration(milliseconds: 300));
        expect(find.textContaining(RegExp(r'Right!|Many people think that|Not quite')), findsOneWidget);
      }

      await t.ensureVisible(find.byKey(const ValueKey('ex-tab-story')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('ex-tab-story')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('story-0')), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('ex-tab-like')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('ex-tab-like')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('like-pair-0')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('explainer in Kannada: the chrome is Kannada, English content stays readable', (t) async {
    final (s, pack, lesson) = await load(gravity, 'puc1-physics-motion-in-a-straight-line', prefs: {'displaySize': 'classroom', 'lang': 'kn'});
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [blockOf(lesson, BlockType.explainer)])));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('ಹಲವರು ಹೀಗೆ ಭಾವಿಸುತ್ತಾರೆ'), findsOneWidget);
    expect(find.text('ವಾಸ್ತವವಾಗಿ'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('concept video: offline it says Needs internet; online it streams in the player', (t) async {
    final (s, pack, lesson) = await load(units, 'puc1-physics-units-and-measurement', prefs: {'displaySize': 'classroom'});
    final vb = blockOf(lesson, BlockType.conceptVideo);
    final old = boardOnline;
    addTearDown(() => boardOnline = old);
    boardOnline = () async => false;
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [vb])));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('video-offline')), findsOneWidget);
    expect(find.text('Needs internet'), findsOneWidget);
    expect(find.byKey(const ValueKey('video-row-1')), findsOneWidget); // the chapter's other episodes

    boardOnline = () async => true;
    await t.tap(find.byKey(const ValueKey('video-retry')));
    await t.pump(const Duration(milliseconds: 300));
    final v = VideoRef.maybe(vb.raw['video'])!;
    expect(find.byKey(ValueKey('embed:video:drive:${v.id}@0')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('video-row-1')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(ValueKey('embed:video:drive:${v.id}@0')), findsNothing);
    expect(t.takeException(), isNull);
  });
}
