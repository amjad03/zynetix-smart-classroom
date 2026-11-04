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
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/features/exam_practice.dart';
import 'package:zynetix_board/features/participation.dart';
import 'package:zynetix_board/features/pin.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/features/self_learning.dart';
import 'package:zynetix_board/features/smartboard.dart';
import 'package:zynetix_board/features/teacher_mode.dart';

import 'dart:math';

import 'package:zynetix_board/engine/mastery.dart';
import 'package:zynetix_board/features/game/game_hub.dart';
import 'package:zynetix_board/features/home.dart';
import 'package:zynetix_board/features/insight/mastery_map.dart';
import 'package:zynetix_board/features/live/live_quiz_screen.dart';
import 'package:zynetix_board/features/live/live_server.dart';
import 'package:zynetix_board/features/live/paper_marks.dart';

import '../test/fixtures.dart';
import '../test/helpers.dart';

const kx = '/root/.pub-cache/git/Kinetix-6db5f65a84c0b30f227fa9d5929db3e169ad2ffb/packages/kinetix_ui/fonts';

const katexDir = '/root/.pub-cache/hosted/pub.dev/flutter_math_fork-0.7.4/lib/katex_fonts/fonts';

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
  // flutter_math_fork's KaTeX fonts, so formulas render as on the board.
  final katex = Directory(katexDir).listSync().whereType<File>().map((f) => f.path).toList();
  for (final fam in {for (final p in katex) base(p).split('-').first}) {
    await family('packages/flutter_math_fork/$fam', katex.where((p) => base(p).startsWith('$fam-')).toList());
  }
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

Future<Services> shotServices({List<String> taught = const [], Map<String, Object> prefs = const {}}) async {
  final s = await testServices(prefs: {'taught': taught, 'collegeName': 'Govt. PU College, Malleshwaram', 'sectionLabel': '1st PUC · A · PCMB', ...prefs});
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

  testWidgets('13 smartboard with insert panel', (t) async {
    final s = await shotServices();
    await pumpBoard(t, s, home: SmartboardScreen(controller: SmartboardScreen.newBoard()));
    await t.pump();
    final st = t.state<SmartboardScreenState>(find.byType(SmartboardScreen));
    // A little teaching on the board: a parabola sketch, its equation, and a highlighted root.
    Future<void> stroke(List<Offset> pts) async {
      final g = await t.startGesture(pts.first, kind: PointerDeviceKind.stylus);
      for (final p in pts.skip(1)) {
        await g.moveTo(p);
      }
      await g.up();
      await t.pump();
    }

    await stroke([for (var i = 0; i <= 40; i++) Offset(160 + i * 16.0, 300 + 0.9 * (i - 20) * (i - 20))]);
    await stroke([const Offset(120, 660), const Offset(860, 660)]);
    await stroke([const Offset(480, 820), const Offset(480, 180)]);
    st.insertMath(r'y = x^2 - 4');
    await t.tap(find.byKey(const ValueKey('insert')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await shot(t, '13-smartboard-insert');
  });

  testWidgets('14 whiteboard block', (t) async {
    final s = await shotServices();
    final p = s.store.byChapter('puc1-maths-05-complex-numbers-and-quadratic-equations') ?? s.store.byChapter(motion)!;
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: p, lesson: lessonWith(p, [whiteboardBlock()])));
    await t.pump(const Duration(seconds: 3));
    await t.tap(find.byKey(const ValueKey('wbNext')));
    await t.pump(const Duration(seconds: 3));
    await t.tap(find.byKey(const ValueKey('wbNext')));
    await t.pump(const Duration(milliseconds: 500)); // mid-way through drawing step 3
    await shot(t, '14-player-whiteboard');
  });

  testWidgets('15 function plot interactive', (t) async {
    final s = await shotServices();
    final p = s.store.byChapter(motion)!;
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: p, lesson: lessonWith(p, [interactiveBlock('function_plot')])));
    await t.drag(find.byKey(const ValueKey('slider-a')), const Offset(-120, 0));
    await shot(t, '15-player-interactive-plot');
  });

  testWidgets('16 exam practice', (t) async {
    await pumpBoard(t, await shotServices(), home: const ExamPracticeScreen());
    await shot(t, '16-exam-practice');
  });

  testWidgets('17 numeric question', (t) async {
    final s = await shotServices();
    final rec = SessionRecorder.raw(outbox: s.outbox, sectionId: 's', mode: 'teacher', chapterId: 'c', topicId: 't', lessonId: 'l', packVersion: '1');
    await pumpBoard(t, s, home: Scaffold(
      appBar: AppBar(toolbarHeight: 112, title: const Text('JEE Main · Mock test', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700))),
      body: Padding(padding: const EdgeInsets.all(40), child: QuizRunner(questions: [numericQuestion(), multiQuestion()], mode: QuizMode.monitor, lang: Lang.en, recorder: rec, room: ClassRoom(rollCount: 60), showExams: true)),
    ));
    for (final k in ['2', '.', '5']) {
      await t.tap(find.byKey(ValueKey('key-$k')));
    }
    await t.pump(const Duration(seconds: 1));
    await shot(t, '17-quiz-numeric-keypad');
  });

  // Real content from the packs: a CBSE commerce section, an Accountancy whiteboard, an Economics interactive.
  const commerce = {'board': 'cbse', 'year': 'puc2', 'sectionLabel': 'Class 12 · B · Commerce', 'subjects': ['accountancy', 'business_studies', 'economics', 'english']};

  testWidgets('18 teacher mode cbse commerce', (t) async {
    await pumpBoard(t, await shotServices(prefs: commerce), home: const TeacherModeScreen());
    await shot(t, '18-teacher-mode-cbse-commerce');
  });

  Future<void> realBlock(WidgetTester t, String topicId, String blockId, String name, {int steps = 0}) async {
    final s = await shotServices(prefs: commerce);
    final hit = s.lessonFor(topicId)!;
    final b = hit.lesson.blocks.firstWhere((b) => b.id == blockId);
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: hit.pack, lesson: lessonWith(hit.pack, [b])));
    await t.pump(const Duration(seconds: 3));
    for (var i = 0; i < steps; i++) {
      await t.tap(find.byKey(const ValueKey('wbNext')));
      await t.pump(const Duration(seconds: 3));
    }
    await shot(t, name);
  }

  testWidgets('19 accountancy whiteboard', (t) => realBlock(t, 'puc2-accountancy-09-accounting-ratios.t2', 'wb1', '19-accountancy-whiteboard', steps: 3));
  testWidgets('20 economics interactive', (t) => realBlock(t, 'puc2-economics-02-theory-of-consumer-behaviour.t3', 'int1', '20-economics-interactive'));

  // Version 2: what the board knows about each roll number, and the game layer. Demo answers.
  Future<Services> v2Services() async {
    final s = await shotServices(prefs: {'displaySize': 'classroom', 'rollCount': 40}, taught: ['$motion.t1', '$motion.t2', '$motion.t3']);
    final rnd = Random(7);
    final rs = <Response>[];
    for (final ch in ['puc1-physics-02-motion-in-a-straight-line', 'puc1-physics-03-motion-in-a-plane', 'puc1-physics-04-laws-of-motion']) {
      final p = s.store.byChapter(ch);
      if (p == null) continue;
      for (final (ti, t) in p.chapter.topics.indexed) {
        for (var roll = 1; roll <= 40; roll++) {
          final skill = 0.35 + 0.6 * ((roll * 37) % 40) / 40 - 0.08 * ti;
          for (var k = 0; k < 3; k++) {
            rs.add(Response(roll: roll, questionId: 'q$k', topicId: t.id, chapterId: ch, correct: rnd.nextDouble() < skill, source: 'hands', at: DateTime(2026, 11, 1 + k)));
          }
        }
      }
    }
    s.mastery.recordAll(rs);
    return s;
  }

  testWidgets('21 home with v2 tools', (t) async {
    await pumpBoard(t, await v2Services(), home: const HomeScreen());
    await shot(t, '21-home-v2');
  });

  testWidgets('22 mastery map', (t) async {
    await pumpBoard(t, await v2Services(), home: const MasteryMapScreen());
    await t.pump(const Duration(seconds: 1));
    await shot(t, '22-mastery-map');
  });

  testWidgets('23 challenge', (t) async {
    final s = await v2Services();
    final hit = s.lessonFor('puc1-physics-03-motion-in-a-plane.t4')!;
    final b = hit.lesson.blocks.firstWhere((b) => b.type == BlockType.challenge);
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: hit.pack, lesson: lessonWith(hit.pack, [b])));
    await t.pump(const Duration(seconds: 1));
    await shot(t, '23-challenge');
  });

  testWidgets('24 game zone', (t) async {
    await pumpBoard(t, await v2Services(), home: const GameHubScreen());
    await t.pump(const Duration(seconds: 1));
    await shot(t, '24-game-zone');
  });

  testWidgets('25 phone quiz', (t) async {
    final s = await v2Services();
    final p = s.store.byChapter(motion)!;
    await pumpBoard(t, s, home: LiveQuizScreen(questions: p.questions.values.where((q) => q.format == 'mcq').take(5).toList(), pack: p, server: LiveServer(rollCount: 40), listen: false));
    await t.pump(const Duration(seconds: 1));
    await shot(t, '25-phone-quiz');
  });

  testWidgets('26 paper marks', (t) async {
    final s = await v2Services();
    final p = s.store.byChapter(motion)!;
    await pumpBoard(t, s, home: PaperMarksScreen(pack: p, questions: p.questions.values.take(10).toList()));
    await t.pump(const Duration(seconds: 1));
    await shot(t, '26-paper-marks');
  });
}

int _index(WidgetTester t) {
  final txt = (find.textContaining(RegExp(r'^\d+ / \d+$')).evaluate().first.widget as Text).data!;
  return int.parse(txt.split(' / ').first) - 1;

}
