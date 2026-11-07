// Screens of the Zynetix School import (tools/school-import), with the real fonts, into
// screenshots/v10-school/: the explainer block (watch, try it, story, it's like; board, phone,
// Kannada), the concept video offline ("Needs internet") and the class tools fed from the packs.
// Run: flutter test --update-goldens screenshots/school_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/concept_video_view.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/app/class_content.dart';
import 'package:zynetix_board/features/classroom/class_data.dart';
import 'package:zynetix_board/features/classroom/explainer_screen.dart';
import 'package:zynetix_board/features/classroom/formula_drill_screen.dart';
import 'package:zynetix_board/features/player.dart';

import '../test/fixtures.dart';
import '../test/helpers.dart';
import 'screens_test.dart' show loadFonts, shotServices;

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 400));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('v10-school/$name.png'));
}

Future<(Services, InstalledPack, Lesson)> load(String topic, String dir, {Map<String, Object> prefs = const {}}) async {
  final s = await shotServices(prefs: prefs);
  final pack = sourcePack(s.lessonFor(topic)!.pack, dir);
  return (s, pack, pack.lessons[topic]!);
}

Future<void> size(WidgetTester t, Size s) async {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

ClassSamples withFormulas(ClassSamples d, List<FormulaSheetData> f) =>
    ClassSamples(subject: d.subject, year: d.year, explainers: d.explainers, questions: d.questions, formulas: f, mocks: d.mocks, code: d.code, plan: d.plan, teams: d.teams, mastery: d.mastery);

void main() {
  setUpAll(loadFonts);
  const gravity = 'puc1-physics-02-motion-in-a-straight-line.t5', motionDir = 'puc1-physics-motion-in-a-straight-line';
  Block ex(Lesson l) => l.blocks.firstWhere((b) => b.type == BlockType.explainer);

  for (final (tab, key) in [('watch', null), ('try', 'tryIt'), ('story', 'story'), ('like', 'like')]) {
    testWidgets('explainer $tab', (t) async {
      final (s, pack, lesson) = await load(gravity, motionDir, prefs: {'displaySize': 'classroom'});
      await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [ex(lesson)])));
      if (key != null) {
        await t.tap(find.byKey(ValueKey('ex-tab-$key')));
        await t.pump(const Duration(milliseconds: 300));
        if (key == 'tryIt') {
          await t.tap(find.byKey(const ValueKey('try-0-opt-0')));
          await t.pump(const Duration(milliseconds: 300));
        }
      } else {
        await t.tap(find.byKey(const ValueKey('watch-next')));
      }
      await shot(t, '01-explainer-$tab');
    });
  }

  testWidgets('explainer kannada', (t) async {
    final (s, pack, lesson) = await load(gravity, motionDir, prefs: {'displaySize': 'classroom', 'lang': 'kn'});
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [ex(lesson)])));
    await shot(t, '02-explainer-kannada');
  });

  testWidgets('explainer imported from a course lesson', (t) async {
    const topic = 'puc2-physics-03-current-electricity.t1';
    final (s, pack, lesson) = await load(topic, 'puc2-physics-current-electricity', prefs: {'displaySize': 'classroom'});
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [ex(lesson)])));
    await shot(t, '03-explainer-course');
  });

  testWidgets('explainer phone', (t) async {
    final (s, pack, lesson) = await load(gravity, motionDir, prefs: {'displaySize': 'normal'});
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [ex(lesson)])));
    await size(t, const Size(390, 844));
    await shot(t, '04-explainer-phone');
  });

  testWidgets('concept video offline', (t) async {
    const topic = 'puc1-physics-01-units-and-measurement.t2';
    final (s, pack, lesson) = await load(topic, 'puc1-physics-units-and-measurement', prefs: {'displaySize': 'classroom'});
    boardOnline = () async => false;
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: pack, lesson: lessonWith(pack, [lesson.blocks.firstWhere((b) => b.type == BlockType.conceptVideo)])));
    await shot(t, '05-concept-video-offline');
  });

  testWidgets('class tools: explainer and formula drill from the packs', (t) async {
    const topic = 'puc2-physics-03-current-electricity.t1';
    final (s, pack, _) = await load(topic, 'puc2-physics-current-electricity', prefs: {'displaySize': 'classroom'});
    final data = buildSamples(s, ClassContent.empty, subject: 'physics');
    final exs = chapterExplainers(pack, 'kar_pu');
    await pumpBoard(t, s, home: ExplainerScreen(samples: data, explainer: exs.first));
    await shot(t, '06-class-explainer');
    final sheet = formulaSheet(pack, 'kar_pu');
    await pumpBoard(t, s, home: FormulaDrillScreen(samples: withFormulas(buildSamples(s, ClassContent.empty, subject: 'physics'), [sheet])));
    await shot(t, '07-formula-drill');
  });
}
