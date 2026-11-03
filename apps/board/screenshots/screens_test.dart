// Renders the board's main screens at 1920×1080 with the real fonts, into screenshots/png/.
// Run: flutter test --update-goldens screenshots/
// The WebView pieces (3D models, PhET pages) cannot render in the test engine and show a labelled
// card instead; everything else, including Kinetix labs, is the real widget.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetix_ui/kinetix_ui.dart';
import 'package:zynetix_board/blocks/embeds.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/pin.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/features/self_learning.dart';
import 'package:zynetix_board/features/teacher_mode.dart';

import '../test/helpers.dart';

const kx = '/root/.pub-cache/git/Kinetix-6db5f65a84c0b30f227fa9d5929db3e169ad2ffb/packages/kinetix_ui/fonts';

Future<void> loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final l = FontLoader(name);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await l.load();
  }

  String base(String n) => n.split('/').last;
  final all = Directory(kx).listSync().whereType<File>().map((f) => f.path).where((p) => p.endsWith('.ttf') || p.endsWith('.otf')).toList();
  for (final n in {KxFonts.family, KxFonts.display, ...KxFonts.fallback}) {
    final files = all.where((p) => p.split('/').last.startsWith('${base(n)}-')).toList();
    if (files.isNotEmpty) await family(n, files);
  }
  await family('MaterialIcons', ['/home/user/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

/// Real labs; a labelled card for WebView content.
class ShotEmbeds extends KinetixEmbeds {
  Widget _card(IconData i, String t, String s) => Container(
        color: const Color(0xFF0F2A22),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 160, color: const Color(0xFF7FD8B0)),
          const SizedBox(height: 16),
          Text(t, style: const TextStyle(fontSize: 40, color: Colors.white)),
          Text(s, style: const TextStyle(fontSize: 24, color: Colors.white70)),
        ]),
      );
  @override
  Widget model3d(Block b, Lang lang) => _card(Icons.view_in_ar, 'Kinetix 3D model: ${b.s('modelId')}${b.s('variant') != null ? ' (${b.s('variant')})' : ''}', 'Rotates, zooms and labels parts on the board (WebView)');
  @override
  Widget simulation(Block b, InstalledPack pack, Lang lang) => b.s('source') == 'phet'
      ? _card(Icons.science_outlined, 'PhET simulation: ${b.s('simId')}', 'Runs offline from the content pack (WebView)')
      : super.simulation(b, pack, lang);
}

Future<Services> shotServices({List<String> taught = const []}) async {
  final s = await testServices(prefs: {'taught': taught, 'collegeName': 'Govt. PU College, Malleshwaram', 'sectionLabel': '1st PUC · A · PCMB'});
  return Services(config: s.config, store: s.store, outbox: s.outbox, narrator: s.narrator, syllabus: s.syllabus, embeds: ShotEmbeds(), clock: () => DateTime(2026, 11, 4, 10, 5));
}

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 400));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('png/$name.png'));
}

void main() {
  setUpAll(loadFonts);
  const motion = 'puc1-physics-02-motion-in-a-straight-line';

  testWidgets('01 home', (t) async {
    await pumpBoard(t, await shotServices(taught: ['$motion.t1']));
    await shot(t, '01-home');
  });

  testWidgets('02 home kannada', (t) async {
    final s = await shotServices(taught: ['$motion.t1']);
    await s.config.setLang(Lang.kn);
    await pumpBoard(t, s);
    await shot(t, '02-home-kannada');
  });

  testWidgets('03 teacher mode', (t) async {
    await pumpBoard(t, await shotServices(taught: ['$motion.t1', '$motion.t2']), home: const TeacherModeScreen());
    await shot(t, '03-teacher-mode');
  });

  Future<void> player(WidgetTester t, String topic, bool Function(String) stopAt, String name, {Future<void> Function()? then}) async {
    final s = await shotServices();
    final hit = s.lessonFor('$motion.$topic') ?? s.lessonFor(topic)!;
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: hit.pack, lesson: hit.lesson));
    for (var i = 0; i < 20 && !stopAt(hit.lesson.blocks[_index(t)].type.wire); i++) {
      await t.tap(find.byKey(const ValueKey('next')));
      await t.pump(const Duration(milliseconds: 300));
    }
    if (then != null) await then();
    await shot(t, name);
  }

  testWidgets('04 intro', (t) => player(t, 't4', (b) => b == 'intro', '04-player-intro'));
  testWidgets('05 concept', (t) => player(t, 't4', (b) => b == 'concept', '05-player-concept-formula'));
  testWidgets('06 virtual lab', (t) => player(t, 't3', (b) => b == 'virtual_lab', '06-player-virtual-lab'));
  testWidgets('07 example', (t) => player(t, 't4', (b) => b == 'example', '07-player-example', then: () async {
        for (var i = 0; i < 3; i++) {
          await t.tap(find.text('Show next step'));
          await t.pump();
        }
      }));
  testWidgets('08 roll call', (t) => player(t, 't3', (b) => b == 'class_quiz', '08-quiz-roll-call', then: () async {
        await t.tap(find.text('Pick a roll number'));
        await t.pump();
      }));
  testWidgets('09 team', (t) => player(t, 't4', (b) => b == 'class_quiz', '09-quiz-team-challenge', then: () async {
        await t.tap(find.byKey(const ValueKey('option-1')));
        await t.pump();
      }));
  testWidgets('10 pen', (t) => player(t, 't4', (b) => b == 'concept', '10-player-pen', then: () async {
        await t.tap(find.byKey(const ValueKey('pen')));
        await t.pump();
        final g = await t.startGesture(const Offset(500, 700), kind: PointerDeviceKind.stylus);
        for (var x = 0; x < 40; x++) {
          await g.moveBy(const Offset(18, -4));
        }
        await g.up();
      }));

  testWidgets('11 self-learning', (t) async {
    final s = await shotServices();
    final p = s.store.byChapter('puc2-chemistry-01-solutions')!;
    await pumpBoard(t, s, home: SelfLearningScreen(pack: p, lesson: p.lessons['puc2-chemistry-01-solutions.t4']!, periodSeconds: 37 * 60 + 12, autoTick: false));
    await shot(t, '11-self-learning');
  });

  testWidgets('12 pin', (t) async {
    final s = await shotServices();
    await pumpBoard(t, s, home: Builder(builder: (c) => Scaffold(body: Center(child: FilledButton(onPressed: () => askPin(c, s.config), child: const Text('x'))))));
    await t.tap(find.text('x'));
    await t.pump(const Duration(milliseconds: 400));
    for (final k in ['1', '2']) {
      await t.tap(find.byKey(ValueKey('pin-$k')));
    }
    await shot(t, '12-teacher-pin');
  });
}

int _index(WidgetTester t) {
  final txt = (find.textContaining(RegExp(r'^\d+ / \d+$')).evaluate().first.widget as Text).data!;
  return int.parse(txt.split(' / ').first) - 1;
}
