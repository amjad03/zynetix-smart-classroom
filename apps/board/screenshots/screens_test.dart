// Renders the board's main screens at 1920×1080 with the real fonts, into screenshots/png/.
// Run: flutter test --update-goldens screenshots/
// The WebView pieces (3D models, PhET pages) cannot render in the test engine and show a labelled
// card instead; everything else, including Kinetix labs, is the real widget.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetix_ui/kinetix_ui.dart';
import 'package:zynetix_board/blocks/embeds.dart';
import 'package:zynetix_board/core/services.dart';
import 'package:zynetix_board/engine/auto_play.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/engine/pack_store.dart';
import 'package:zynetix_board/engine/voice.dart';
import 'package:zynetix_board/engine/session_log.dart';
import 'package:zynetix_board/features/classroom/class_data.dart';
import 'package:zynetix_board/features/classroom/class_plan_screen.dart';
import 'package:zynetix_board/features/classroom/class_quiz_screen.dart';
import 'package:zynetix_board/features/classroom/coding_lab_screen.dart';
import 'package:zynetix_board/features/classroom/explainer_screen.dart';
import 'package:zynetix_board/features/classroom/formula_drill_screen.dart';
import 'package:zynetix_board/features/classroom/mastery_heatmap_screen.dart';
import 'package:zynetix_board/features/classroom/mock_test_screen.dart';
import 'package:zynetix_board/features/classroom/teams_screen.dart';
import 'package:zynetix_board/features/classroom/worksheet_export_screen.dart';
import 'package:zynetix_board/features/simple/whiteboard_screens.dart';
import 'package:zynetix_board/features/app/home.dart';
import 'package:zynetix_board/features/app/lesson.dart';
import 'package:zynetix_board/features/app/practice.dart';
import 'package:zynetix_board/features/app/quiz.dart';
import 'package:zynetix_board/features/app/school.dart';
import 'package:zynetix_board/features/app/shell.dart';
import 'package:zynetix_board/features/app/start.dart';
import 'package:zynetix_board/features/app/teach.dart';
import 'package:zynetix_board/features/exam_practice.dart';
import 'package:zynetix_board/features/participation.dart';
import 'package:zynetix_board/features/pin.dart';
import 'package:zynetix_board/features/player.dart';
import 'package:zynetix_board/features/self_learning.dart';
import 'package:zynetix_board/features/smartboard.dart';
import 'package:zynetix_board/features/teacher_mode.dart';
import 'package:zynetix_board/whiteboard/board_store.dart';

import 'dart:math';

import 'package:zynetix_board/engine/mastery.dart';
import 'package:zynetix_board/features/game/game_hub.dart';
import 'package:zynetix_board/main.dart';
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
  // The board's own fonts (assets/fonts): Inter, Poppins, Noto Sans Kannada.
  final own = Directory('assets/fonts').listSync().whereType<File>().map((f) => f.path).where((p) => p.endsWith('.ttf')).toList();
  for (final fam in {for (final p in own) base(p).split('-').first}) {
    await family(fam, own.where((p) => base(p).startsWith('$fam-')).toList());
  }
  // flutter_math_fork's KaTeX fonts, so formulas render as on the board.
  final katex = Directory(katexDir).listSync().whereType<File>().map((f) => f.path).toList();
  for (final fam in {for (final p in katex) base(p).split('-').first}) {
    await family('packages/flutter_math_fork/$fam', katex.where((p) => base(p).startsWith('$fam-')).toList());
  }
}

/// Real labs; a labelled card for WebView content, or, for the v4 shots, a real render of the
/// Kinetix 3D page made in headless Chromium (screenshots/renders/, see renders/render.js).
class ShotEmbeds extends KinetixEmbeds {
  static bool realRenders = false;
  Widget? _render(String name) {
    final f = File('screenshots/renders/$name.png');
    if (!realRenders || !f.existsSync()) return null;
    return Image.memory(f.readAsBytesSync(), fit: BoxFit.cover, gaplessPlayback: true);
  }

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
  Widget model3d(Block b, Lang lang) => _render('3d-${b.s('modelId')}-${b.s('variant') ?? 'default'}') ?? _card(Icons.view_in_ar, 'Kinetix 3D model: ${b.s('modelId')}${b.s('variant') != null ? ' (${b.s('variant')})' : ''}', 'Rotates, zooms and labels parts on the board (WebView)');
  @override
  Widget simulation(Block b, InstalledPack pack, Lang lang) => b.s('source') == 'phet'
      ? _card(Icons.science_outlined, 'PhET simulation: ${b.s('simId')}', 'Runs offline from the content pack (WebView)')
      : super.simulation(b, pack, lang);
}

Future<Services> shotServices({List<String> taught = const [], Map<String, Object> prefs = const {}}) async {
  final s = await testServices(prefs: {'taught': taught, 'collegeName': 'Govt. PU College, Malleshwaram', 'sectionLabel': '1st PUC · A · PCMB', ...prefs});
  DateTime clock() => DateTime(2026, 11, 4, 10, 5);
  return Services(config: s.config, store: s.store, outbox: s.outbox, narrator: s.narrator, syllabus: s.syllabus, embeds: ShotEmbeds(), clock: clock, school: shotSchool(clock));
}

/// The school on the sample board: five teachers, Wednesday's timetable (Meera's 1st PUC A
/// Physics is on now, 9:45–10:40), set up, with Meera signed in and the guide done.
SchoolStore shotSchool(DateTime Function() clock) {
  const days = [1, 2, 3, 4, 5, 6];
  return SchoolStore(now: clock)
    ..seed({
      'setUp': true,
      'tourDone': true,
      'current': 't1',
      'currentDay': '2026-11-04',
      'helpContact': 'School office · Mr. Ramesh, ext. 204',
      'teachers': [
        {'id': 't1', 'name': 'K. Meera', 'initials': 'KM', 'colour': 0},
        {'id': 't2', 'name': 'S. Prakash', 'initials': 'SP', 'colour': 1},
        {'id': 't3', 'name': 'A. Farah', 'initials': 'AF', 'colour': 2},
        {'id': 't4', 'name': 'R. Venkatesh', 'initials': 'RV', 'colour': 3},
        {'id': 't5', 'name': 'N. Kavya', 'initials': 'NK', 'colour': 4},
      ],
      'periods': [
        {'id': 'p1', 'start': '08:50', 'end': '09:40', 'subject': 'physics', 'days': days, 'teacher': 't1', 'label': '1st PUC C'},
        {'id': 'p2', 'start': '09:45', 'end': '10:40', 'subject': 'physics', 'days': days, 'teacher': 't1', 'label': ''},
        {'id': 'p3', 'start': '10:55', 'end': '11:50', 'subject': 'physics', 'days': days, 'teacher': 't1', 'label': '2nd PUC A'},
        {'id': 'p4', 'start': '12:00', 'end': '12:50', 'subject': 'physics', 'days': days, 'teacher': 't1', 'label': '1st PUC B'},
        {'id': 'p5', 'start': '09:45', 'end': '10:40', 'subject': 'chemistry', 'days': days, 'teacher': 't2', 'label': '1st PUC B'},
        {'id': 'p6', 'start': '10:55', 'end': '11:50', 'subject': 'maths', 'days': days, 'teacher': 't3', 'label': '2nd PUC A'},
        {'id': 'p7', 'start': '12:00', 'end': '12:50', 'subject': 'biology', 'days': days, 'teacher': 't4', 'label': '1st PUC A'},
        {'id': 'p8', 'start': '14:00', 'end': '14:50', 'subject': 'physics', 'days': days, 'teacher': 't5', 'label': '2nd PUC C'},
      ],
      'progress': {'puc1-physics-07-gravitation.t3': 1},
    });
}

const gravitation = ['puc1-physics-07-gravitation.t1', 'puc1-physics-07-gravitation.t2'];

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
    await pumpBoard(t, await v2Services(), home: const HomeScreen(tour: false));
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

  // Version 3: simulations and activities in every lesson.
  Future<void> sim(WidgetTester t, String topicId, String blockId, String name, {Duration play = Duration.zero}) async {
    final s = await shotServices(prefs: {'displaySize': 'classroom'});
    final hit = s.lessonFor(topicId)!;
    final b = hit.lesson.blocks.firstWhere((b) => b.id == blockId);
    await pumpBoard(t, s, home: LessonPlayerScreen(pack: hit.pack, lesson: lessonWith(hit.pack, [b])));
    await t.pump(const Duration(milliseconds: 500));
    final playBtn = find.byKey(const ValueKey('timePlay'));
    if (play > Duration.zero && playBtn.evaluate().isNotEmpty) {
      await t.tap(playBtn.first);
      for (var i = 0; i < play.inMilliseconds ~/ 100; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }
    await shot(t, name);
  }

  testWidgets('27 pendulum', (t) => sim(t, 'puc1-physics-13-oscillations.t5', 'scene-pendulum', '27-sim-pendulum', play: const Duration(milliseconds: 1600)));
  testWidgets('28 lens', (t) => sim(t, 'puc2-physics-09-ray-optics-and-optical-instruments.t4', 'scene-lens', '28-sim-lens'));
  testWidgets('29 cardiac cycle', (t) => sim(t, 'puc1-biology-15-body-fluids-and-circulation.t4', 'sim1', '29-sim-cardiac-cycle', play: const Duration(milliseconds: 1200)));
  testWidgets('30 label the heart', (t) => sim(t, 'puc1-biology-15-body-fluids-and-circulation.t3', 'act1', '30-activity-label-heart'));
  testWidgets('31 kinetics', (t) => sim(t, 'puc2-chemistry-03-chemical-kinetics.t5', 'sim1', '31-sim-arrhenius'));
  testWidgets('32 bubble sort', (t) => sim(t, 'puc2-computer-science-05-sorting.t1', 'sim1', '32-sim-bubble-sort'));
  // Version 4: the approved visual design ("Option B"), one sample of each kind of screen, on a
  // 1080p board at the classroom display size and on a 390 × 844 phone.
  group('v4', () {
    setUp(() => ShotEmbeds.realRenders = true);
    tearDown(() => ShotEmbeds.realRenders = false);
    const sizes = {'board': (Size(1920, 1080), 'classroom'), 'phone': (Size(390, 844), 'normal')};

    Future<Services> v4Services(String display, {Map<String, Object> prefs = const {}}) async {
      final s = await shotServices(prefs: {'displaySize': display, 'rollCount': 48, ...prefs}, taught: ['$motion.t1', '$motion.t2', 'puc1-physics-03-motion-in-a-plane.t1', 'puc1-physics-03-motion-in-a-plane.t2', 'puc1-physics-03-motion-in-a-plane.t3']);
      return s;
    }

    Future<void> pumpAt(WidgetTester t, Services s, Size size, Widget home) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ZynetixBoardApp(services: s, home: home));
      await t.pump();
    }

    /// Opens [topicId]'s lesson and steps forward to [blockId].
    Future<void> lessonAt(WidgetTester t, Services s, Size size, String topicId, String blockId) async {
      final hit = s.lessonFor(topicId)!;
      await pumpAt(t, s, size, LessonPlayerScreen(pack: hit.pack, lesson: hit.lesson));
      for (var i = 0; i < 30 && find.byKey(ValueKey('block:$blockId')).evaluate().isEmpty; i++) {
        await t.tap(find.byKey(const ValueKey('next')));
        await t.pump(const Duration(milliseconds: 300));
      }
      await t.pump(const Duration(milliseconds: 500));
    }

    Future<void> v4(WidgetTester t, String name) async {
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('v4/$name.png'));
    }

    for (final e in sizes.entries) {
      final (size, display) = e.value;
      final tag = e.key;

      testWidgets('a home $tag', (t) async {
        await pumpAt(t, await v4Services(display), size, const HomeScreen(tour: false));
        await v4(t, 'a-home-$tag');
      });

      testWidgets('b teacher mode $tag', (t) async {
        await pumpAt(t, await v4Services(display), size, const TeacherModeScreen());
        await t.pump(const Duration(seconds: 1));
        await v4(t, 'b-teacher-mode-$tag');
      });

      testWidgets('c projectile $tag', (t) async {
        final s = await v4Services(display);
        await lessonAt(t, s, size, 'puc1-physics-03-motion-in-a-plane.t4', 'scene-projectile');
        final play = find.byKey(const ValueKey('timePlay'));
        if (play.evaluate().isNotEmpty) {
          await t.tap(play.first);
          for (var i = 0; i < 12; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
        }
        await v4(t, 'c-projectile-$tag');
      });

      testWidgets('d 3d model $tag', (t) async {
        final s = await v4Services(display);
        await lessonAt(t, s, size, 'puc1-chemistry-04-chemical-bonding-and-molecular-structure.t4', '3d-hybridisation');
        // Decode the real render (image decoding runs outside the test's fake clock).
        await t.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await t.pump();
        await v4(t, 'd-3d-sp3-$tag');
      });

      testWidgets('e ohms law lab $tag', (t) async {
        final s = await v4Services(display, prefs: {'year': 'puc2'});
        await lessonAt(t, s, size, 'puc2-physics-03-current-electricity.t1', 'sim-lab.ohms-law');
        await t.pump(const Duration(seconds: 1));
        await v4(t, 'e-ohms-law-lab-$tag');
      });

      testWidgets('f jee mcq $tag', (t) async {
        final s = await v4Services(display);
        await lessonAt(t, s, size, 'puc1-physics-03-motion-in-a-plane.t4', 'exam');
        await t.tap(find.byKey(const ValueKey('option-0')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('hands')));
        await t.pumpAndSettle();
        for (final r in [3, 7, 11, 14, 19, 22, 26, 30, 33, 37, 41, 45, 47]) {
          await t.tap(find.byKey(ValueKey('roll-$r')));
        }
        await t.tap(find.byKey(const ValueKey('tapAbsent')));
        await t.pump();
        for (final r in [9, 28, 39, 44]) {
          await t.tap(find.byKey(ValueKey('roll-$r')));
        }
        await t.tap(find.byKey(const ValueKey('handsSave')));
        await t.pumpAndSettle();
        await v4(t, 'f-jee-mcq-results-$tag');
      });

      testWidgets('g accountancy sort $tag', (t) async {
        final s = await v4Services(display, prefs: {'subjects': ['accountancy', 'business_studies', 'economics', 'english']});
        await lessonAt(t, s, size, 'puc1-accountancy-01-introduction-to-accounting.t5', 'activity-sort-alc');
        await sortSome(t);
        await v4(t, 'g-accountancy-sort-$tag');
      });
    }
  });

  // Version 5: one lesson rebuilt to teach like the college's own videos (one idea at a time,
  // Aarav and Diya, Remember this, Pause and think, exam trap, exam pattern, recall): every step
  // on a 1080p board at the classroom size, and three on a phone. Run:
  //   flutter test --update-goldens screenshots/screens_test.dart --plain-name v5-lesson
  group('v5-lesson', () {
    const topic = 'puc1-physics-01-units-and-measurement.t1';
    // The 3D step shows the real Kinetix render (screenshots/renders/3d-lab_apparatus-default.png).
    setUp(() => ShotEmbeds.realRenders = true);
    tearDown(() => ShotEmbeds.realRenders = false);

    Future<void> pumpAt(WidgetTester t, Services s, Size size, Widget home) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ZynetixBoardApp(services: s, home: home));
      await t.pump();
    }

    /// Opens the lesson at [i] (0-based), with that block fully revealed, then runs [then].
    Future<void> step(WidgetTester t, int i, String name, String tag, {Size size = const Size(1920, 1080), String display = 'classroom', Future<void> Function(WidgetTester t, Block b, InstalledPack p)? then, bool whole = true, String lang = 'en'}) async {
      final s = await shotServices(prefs: {'displaySize': display, 'rollCount': 48, 'lang': lang});
      // The lesson as authored in content/packs (the seed pack is re-signed at release).
      final pack = sourcePack(s.lessonFor(topic)!.pack, 'puc1-physics-units-and-measurement');
      final hit = (pack: pack, lesson: pack.lessons[topic]!);
      await pumpAt(t, s, size, LessonPlayerScreen(pack: hit.pack, lesson: hit.lesson));
      final blocks = hit.lesson.blocks;
      for (var k = 0; k < i; k++) {
        while (find.byKey(ValueKey('block:${blocks[k + 1].id}')).evaluate().isEmpty) {
          await t.tap(find.byKey(const ValueKey('next')));
          await t.pump(const Duration(milliseconds: 300));
        }
      }
      final b = blocks[i];
      final pauseLike = b.style == 'pause' || b.style == 'solve';
      if (whole && !pauseLike) {
        for (var k = 1; k < b.revealSteps(hit.pack); k++) {
          await t.tap(find.byKey(const ValueKey('next')));
          await t.pump(const Duration(milliseconds: 300));
        }
      }
      if (then != null) await then(t, b, hit.pack);
      // Decode the avatars (image decoding runs outside the test's fake clock).
      await t.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await t.pump(const Duration(milliseconds: 600));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('v5/$name-$tag.png'));
    }

    Future<void> tapKey(WidgetTester t, String key) async {
      await t.tap(find.byKey(ValueKey(key)));
      await t.pump(const Duration(milliseconds: 300));
    }

    final steps = <(String, Future<void> Function(WidgetTester t, Block b, InstalledPack p)?)>[
      ('01-hook', null),
      ('02-number-alone', null),
      ('03-physical-quantity', null),
      ('04-two-parts', null),
      ('05-measuring-bench', (t, b, p) async => tapKey(t, 'choice-u-0')),
      ('06-n-vs-unit', null),
      ('07-rule-steps', null),
      ('08-remember-this', null),
      ('09-pause-think-unit', (t, b, p) async => tapKey(t, 'think-0')),
      ('10-base-seven', null),
      ('11-lab-pendulum', null),
      ('12-derived', null),
      ('13-3d-lab-apparatus', null),
      ('14-pause-think-temperature', (t, b, p) async => tapKey(t, 'think-1')),
      ('15-sort-base-derived', (t, b, p) async {
        for (final (item, bucket) in [(0, 'base'), (6, 'derived'), (1, 'base'), (9, 'derived'), (4, 'base')]) {
          final chip = find.byKey(ValueKey('item-$item'));
          if (chip.evaluate().isEmpty) continue;
          await t.tap(chip, warnIfMissed: false);
          await t.pump();
          await t.tap(find.byKey(ValueKey('bucket-$bucket')), warnIfMissed: false);
          await t.pump();
        }
      }),
      ('16-scalar-vector-push', (t, b, p) async {
        await tapKey(t, 'choice-d-1');
        final push = find.byKey(const ValueKey('button-0'));
        if (push.evaluate().isNotEmpty) await t.tap(push.first);
        for (var k = 0; k < 14; k++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }),
      ('17-worked-example', null),
      ('18-exam-trap', null),
      ('19-exam-pattern', (t, b, p) async {
        await tapKey(t, 'solve-0');
        for (var k = 2; k < b.revealSteps(p); k++) {
          await tapKey(t, 'next');
        }
      }),
      ('20-recall-next', (t, b, p) async => tapKey(t, 'recall-0')),
    ];
    for (final (i, (name, then)) in steps.indexed) {
      testWidgets('$name board', (t) => step(t, i, name, 'board', then: then));
    }
    // Phone: three key steps.
    const phone = Size(390, 844);
    testWidgets('01-hook phone', (t) => step(t, 0, '01-hook', 'phone', size: phone, display: 'normal'));
    testWidgets('05-measuring-bench phone', (t) => step(t, 4, '05-measuring-bench', 'phone', size: phone, display: 'normal'));
    testWidgets('09-pause-think-unit phone', (t) => step(t, 8, '09-pause-think-unit', 'phone', size: phone, display: 'normal', then: (t, b, p) async => tapKey(t, 'think-0')));
    // Kannada: the same lesson, every field translated.
    for (final i in [2, 4, 10, 12, 18]) {
      testWidgets('${steps[i].$1} board kn', (t) => step(t, i, steps[i].$1, 'board-kn', then: steps[i].$2, lang: 'kn'));
    }
  });

  // The lesson playing in Auto with its chapter voice, one frame per reveal step, for the demo
  // video (tools/voice/demo.py joins the frames with the clips):
  //   flutter test --update-goldens screenshots/screens_test.dart --plain-name v5-demo
  // Frames and timeline.json go to build/demo/<lang>/. Needs content/dist/audio/…zpack (build-audio).
  group('v5-demo', () {
    const topic = 'puc1-physics-01-units-and-measurement.t1';
    setUp(() => ShotEmbeds.realRenders = true);
    tearDown(() => ShotEmbeds.realRenders = false);
    for (final lang in ['en', 'kn']) {
      testWidgets('demo $lang', (t) async {
        final zpack = Directory('../../content/dist/audio').listSync().whereType<File>().where((f) => f.path.contains('units-and-measurement-audio-$lang-')).toList()..sort((a, b) => a.path.compareTo(b.path));
        if (zpack.isEmpty) return markTestSkipped('no $lang audio pack: run tools/voice/render.py and build-audio first');
        final base = await shotServices(prefs: {'displaySize': 'classroom', 'rollCount': 48, 'lang': lang});
        final dev = parseTrustedKey(File('assets/keys/dev-pack-key.json').readAsStringSync());
        final voice = VoiceStore(Directory.systemTemp.createTempSync('demo-voice'), trustedKeys: {dev.key: dev.value});
        await t.runAsync(() async => voice.install(zpack.last.readAsBytesSync()));
        final player = DemoPlayer();
        final s = Services(config: base.config, store: base.store, outbox: base.outbox, narrator: base.narrator, syllabus: base.syllabus, embeds: ShotEmbeds(), clock: base.clock, voice: voice, voicePlayer: () => player);
        final pack = sourcePack(s.lessonFor(topic)!.pack, 'puc1-physics-units-and-measurement');
        final lesson = pack.lessons[topic]!;
        final lines = [for (final b in lesson.blocks) for (var k = 1; k <= ((b.raw['voice'] as List?)?.length ?? 0); k++) (b, k)];
        final clips = voice.track(pack, lesson, lang == 'kn' ? Lang.kn : Lang.en)!;
        // Kannada may be partial (a slow CPU voice): the demo stops at the first line with no clip.
        final n = lines.indexWhere((e) => clips.clip(e.$1, e.$2) == null);
        final total = n < 0 ? lines.length : n;
        t.view.physicalSize = const Size(1920, 1080);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(ZynetixBoardApp(services: s, home: LessonPlayerScreen(pack: pack, lesson: lesson)));
        await t.pump();
        final frames = <Map<String, Object>>[];
        final out = Directory('build/demo/$lang')..createSync(recursive: true);
        for (final f in out.listSync().whereType<File>()) {
          f.deleteSync();
        }
        for (var i = 0; i < total; i++) {
          for (var k = 0; k < 40 && player.current == null; k++) {
            await t.pump(const Duration(milliseconds: 100));
          }
          final clip = player.current!;
          // The step's cards and bubbles fade in as the clip starts.
          await t.pump(const Duration(milliseconds: 500));
          await t.runAsync(() async {
            for (final e in find.byType(Image).evaluate()) {
              await precacheImage((e.widget as Image).image, e);
            }
          });
          await t.pump(const Duration(milliseconds: 400));
          final name = (i + 1).toString().padLeft(3, '0');
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/demo/$lang/$name.png'));
          final (b, step) = lines[i];
          player.finish();
          await t.pump(const Duration(milliseconds: 750)); // the gap after a line
          final waits = find.byKey(const ValueKey('yourTurn')).evaluate().isNotEmpty;
          // The teacher's moment: the same step with its "Your turn" label.
          if (waits) await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/demo/$lang/${name}w.png'));
          frames.add({'png': '$name.png', if (waits) 'wait': '${name}w.png', 'clip': clip.path, 'ms': clip.ms, 'block': b.id, 'step': step, 'waits': waits});
          if (i + 1 < total && waits) {
            await t.pump(const Duration(milliseconds: 300));
            // The teacher's turn: the class answers, or Next after trying the lab or the model.
            final answer = b.style == 'pause' ? find.byKey(ValueKey('think-${b.raw['questionIds'] is List ? (pack.questions[b.ids('questionIds').first]!.answer) : 0}')) : b.style == 'solve' ? find.byKey(ValueKey('solve-${pack.questions[b.ids('questionIds').first]!.answer}')) : find.byKey(const ValueKey('next'));
            await t.tap(answer.evaluate().isEmpty ? find.byKey(const ValueKey('next')) : answer.first, warnIfMissed: false);
            await t.pump(const Duration(milliseconds: 100));
          }
        }
        File('${out.path}/timeline.json').writeAsStringSync('${const JsonEncoder.withIndent(' ').convert({'lang': lang, 'gapMs': 700, 'frames': frames})}\n');
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      });
    }
  });

  // Version 6, samples for approval: Zynetix School content (quest-academy) as whole-class modes
  // on the board, PUC only, loaded from screenshots/fixtures/puc_class_samples.json. Board at the
  // classroom size, a few on a phone, two in Kannada. Run:
  //   flutter test --update-goldens screenshots/screens_test.dart --plain-name v6-class
  group('v6-class', () {
    late ClassSamples samples;
    setUpAll(() async {
      samples = ClassSamples.fromJson(jsonDecode(File('screenshots/fixtures/puc_class_samples.json').readAsStringSync()) as Map<String, dynamic>);
      // The coding lab's monospace face (kinetix_ui's JetBrains Mono).
      final mono = FontLoader(KxFonts.code);
      for (final f in Directory(kx).listSync().whereType<File>().where((f) => f.path.split('/').last.startsWith('JetBrainsMono-'))) {
        mono.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
      await mono.load();
    });
    const board = Size(1920, 1080), phone = Size(390, 844);

    Future<void> open(WidgetTester t, Widget home, {Size size = board, String lang = 'en'}) async {
      final s = await shotServices(prefs: {'displaySize': size == board ? 'classroom' : 'normal', 'rollCount': 40, 'lang': lang});
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ZynetixBoardApp(services: s, home: home));
      await t.pump();
    }

    Future<void> snap(WidgetTester t, String name) async {
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('v6-class/$name.png'));
    }

    Future<void> tap(WidgetTester t, String key, {int times = 1}) async {
      for (var i = 0; i < times; i++) {
        await t.tap(find.byKey(ValueKey(key)));
        await t.pump(const Duration(milliseconds: 120));
      }
    }

    testWidgets('00 home entry board', (t) async {
      await open(t, const HomeScreen(tour: false));
      await snap(t, '00-home-entry-board');
    });

    for (final (tag, size, lang) in [('board', board, 'en'), ('board-kn', board, 'kn'), ('phone', phone, 'en')]) {
      testWidgets('01 hub $tag', (t) async {
        await open(t, const ToolsShell(initial: Section.tools), size: size, lang: lang);
        await snap(t, '01-hub-$tag');
      });
    }

    for (final (tag, size, lang) in [('board', board, 'en'), ('board-kn', board, 'kn'), ('phone', phone, 'en')]) {
      testWidgets('02 explainer watch $tag', (t) async {
        await open(t, ExplainerScreen(samples: samples, explainer: samples.explainers.first, initialStep: 1), size: size, lang: lang);
        await snap(t, '02-explainer-watch-$tag');
      });
    }
    testWidgets('02 explainer its like board', (t) async {
      await open(t, ExplainerScreen(samples: samples, explainer: samples.explainers.first, initialStep: 1));
      await tap(t, 'tab-like');
      await snap(t, '02-explainer-its-like-board');
    });

    // The class answers question 1; the teacher marks rolls 1–24, then the rest, and reveals.
    const wrong = [3, 8, 12, 17, 21, 26, 29, 34, 38], unmarked = [15, 31];
    Future<void> markFirst(WidgetTester t) async {
      await tap(t, 'quizMark');
      for (var r = 1; r <= 24; r++) {
        await tap(t, 'roll-$r', times: wrong.contains(r) ? 2 : (unmarked.contains(r) ? 0 : 1));
      }
    }

    for (final (tag, size) in [('board', board), ('phone', phone)]) {
      testWidgets('03 quiz $tag', (t) async {
        await open(t, ClassQuizScreen(samples: samples), size: size);
        if (tag == 'board') await snap(t, '03-quiz-question-board');
        await markFirst(t);
        await snap(t, '03-quiz-mark-$tag');
        if (tag != 'board') return;
        for (final r in wrong.where((r) => r > 24)) {
          await tap(t, 'roll-$r', times: 2);
        }
        await tap(t, 'fillRest');
        for (final r in unmarked) {
          await tap(t, 'roll-$r', times: 2);
        }
        await tap(t, 'quizReveal');
        await snap(t, '03-quiz-reveal-board');
      });
    }

    testWidgets('04 mock test board', (t) async {
      await open(t, MockTestScreen(samples: samples));
      await snap(t, '04-mock-picker-board');
      await tap(t, 'mockStart');
      await t.pump(const Duration(seconds: 1968)); // 80:00 → 47:12
      await tap(t, 'mockNext', times: 3);
      await tap(t, 'mockFlag');
      await tap(t, 'mockNext', times: 3);
      await snap(t, '04-mock-running-board');
      await tap(t, 'mockEnd');
      final rnd = Random(3);
      for (var r = 1; r <= 36; r++) {
        if (r == 9 || r == 27) {
          await tap(t, 'key-A');
          continue;
        }
        for (final d in '${18 + rnd.nextInt(41)}'.split('')) {
          await tap(t, 'key-$d');
        }
        await tap(t, 'key-↵');
      }
      await tap(t, 'key-4');
      await snap(t, '04-mock-scores-board');
    });

    for (final (tag, size) in [('board', board), ('phone', phone)]) {
      testWidgets('05 formula drill $tag', (t) async {
        await open(t, FormulaDrillScreen(samples: samples), size: size);
        await tap(t, 'drillNext', times: 3);
        await snap(t, '05-formula-drill-$tag');
      });
    }

    testWidgets('06 teams board', (t) async {
      await open(t, TeamsScreen(samples: samples));
      await snap(t, '06-teams-board');
    });

    testWidgets('07 class plan board', (t) async {
      await open(t, ClassPlanScreen(samples: samples));
      await snap(t, '07-class-plan-board');
    });

    testWidgets('08 mastery board', (t) async {
      await open(t, MasteryHeatmapScreen(samples: samples));
      await snap(t, '08-mastery-skills-board');
      await tap(t, 'viewRolls');
      await snap(t, '08-mastery-rolls-board');
    });

    testWidgets('09 coding lab board', (t) async {
      await open(t, CodingLabScreen(samples: samples, ran: true, line: 6));
      await snap(t, '09-coding-lab-board');
    });

    testWidgets('10 worksheet board', (t) async {
      await open(t, WorksheetExportScreen(samples: samples));
      await snap(t, '10-worksheet-board');
    });
  });

  // The combined classroom (v7 structure) in the website style: Today, Teach, lesson, Library,
  // Class tools, quiz marking, end of class and Reports, all real screens on sample data.
  group('v7-combined', () {
    setUpAll(() async {
      Future<void> fam(String name, String prefix, String dir) async {
        final l = FontLoader(name);
        for (final f in Directory(dir).listSync().whereType<File>().where((f) => f.path.split('/').last.startsWith(prefix))) {
          l.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
        }
        await l.load();
      }
      await fam(KxFonts.kalam, 'Kalam-', kx);
      await fam(KxFonts.code, 'JetBrainsMono-', kx);
    });
    const board = Size(1920, 1080), phone = Size(390, 844);

    Future<void> shoot(WidgetTester t, Widget home, String name, {Size size = board, String lang = 'en', Future<void> Function(Services)? prep}) async {
      final s = await shotServices(taught: gravitation, prefs: {'displaySize': size == board ? 'classroom' : 'normal', 'rollCount': 40, 'lang': lang});
      await prep?.call(s);
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      debugDisableShadows = false;
      await t.pumpWidget(ZynetixBoardApp(services: s, home: home));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('v7-combined/$name.png'));
      debugDisableShadows = true;
    }

    Future<void> history(Services s) async {
      final hit = s.lessonFor('puc1-physics-07-gravitation.t2')!;
      s.school.addClass(ClassRecord(id: 'c1', at: DateTime(2026, 11, 2, 9, 50), subject: 'physics', topicId: hit.lesson.topicId, topic: hit.lesson.title, chapter: hit.pack.chapter.title, stepsSeen: 12, stepsTotal: 12, minutes: 41, teacherId: 't1', teacherName: 'K. Meera', homework: 'Two 1 kg spheres touch, radius 5 cm each: the force between them?', absent: const [7, 15, 22, 31], rollCount: 40));
      s.school.addQuiz(QuizResult(id: 'q1', at: DateTime(2026, 11, 2, 10, 20), questionId: 'x', topicId: hit.lesson.topicId, chapterId: hit.pack.chapter.id, right: [for (var r = 1; r <= 28; r++) r], wrong: [for (var r = 29; r <= 40; r++) r]));
    }

    testWidgets('01 who is teaching', (t) => shoot(t, const WhoTodayScreen(), '01-who-is-teaching', prep: (s) async => s.school.signIn(null)));
    testWidgets('02 today', (t) => shoot(t, const ToolsShell(initial: Section.today), '02-today', prep: history));
    testWidgets('02 today kn', (t) => shoot(t, const ToolsShell(initial: Section.today), '02-today-kn', lang: 'kn', prep: history));
    testWidgets('02 today phone', (t) => shoot(t, const ToolsShell(initial: Section.today), '02-today-phone', size: phone, prep: history));
    testWidgets('03 chapter', (t) async {
      late Services sv;
      await shoot(t, Builder(builder: (c) => ChapterPage(pack: sv.store.byChapter('puc1-physics-07-gravitation')!)), '03-teach-chapter', prep: (s) async => sv = s);
    });
    testWidgets('04 lesson', (t) async {
      late Services sv;
      await shoot(t, Builder(builder: (c) {
        final hit = sv.lessonFor('puc1-physics-07-gravitation.t3')!;
        return SimpleLessonScreen(pack: hit.pack, lesson: hit.lesson, startStep: 1);
      }), '04-lesson-concept', prep: (s) async => sv = s);
    });
    testWidgets('06 library', (t) => shoot(t, const ToolsShell(initial: Section.library), '06-library'));
    testWidgets('07 class tools', (t) => shoot(t, const ToolsShell(initial: Section.tools), '07-class-tools', prep: history));
    testWidgets('09 end class', (t) => shoot(t, const FinishClassScreen(recordId: 'c1'), '09-end-class-summary', prep: history));
    testWidgets('10 reports', (t) => shoot(t, const ToolsShell(initial: Section.reports), '10-reports', prep: history));
    testWidgets('12 settings', (t) => shoot(t, const ToolsShell(initial: Section.settings), '12-settings'));
  });

  // The simple-first app for a first-time teacher, in the Zynetix School website style: the real
  // screens on sample data (Wednesday 4 November, 10:05, Meera's 1st PUC A Physics on now).
  group('v8-simple', () {
    setUpAll(() async {
      final l = FontLoader(KxFonts.kalam);
      for (final f in Directory(kx).listSync().whereType<File>().where((f) => f.path.split('/').last.startsWith('Kalam-'))) {
        l.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
      await l.load();
    });
    const board = Size(1920, 1080), phone = Size(390, 844);

    Future<void> shoot(WidgetTester t, Widget home, String name, {Size size = board, String lang = 'en', Future<void> Function(Services)? prep, Future<void> Function()? act}) async {
      final s = await shotServices(taught: gravitation, prefs: {'displaySize': size == board ? 'classroom' : 'normal', 'rollCount': 40, 'lang': lang});
      await prep?.call(s);
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      debugDisableShadows = false;
      await t.pumpWidget(ZynetixBoardApp(services: s, home: home));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await act?.call();
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('v8-simple/$name.png'));
      debugDisableShadows = true;
    }

    Future<void> tap(WidgetTester t, String key) async {
      await t.tap(find.byKey(ValueKey(key)));
      await t.pump(const Duration(milliseconds: 300));
    }

    Widget lesson(Services Function() s, {int step = 1}) => Builder(builder: (c) {
      final hit = s().lessonFor('puc1-physics-07-gravitation.t3')!;
      return SimpleLessonScreen(pack: hit.pack, lesson: hit.lesson, period: s().school.periods.firstWhere((p) => p.id == 'p2'), startStep: step);
    });

    testWidgets('01 first open', (t) => shoot(t, const FirstOpenScreen(), '01-first-open-language'));
    testWidgets('02 who', (t) => shoot(t, const WhoTodayScreen(), '02-who-is-teaching-no-pin', prep: (s) async => s.school.signIn(null)));
    testWidgets('03 home', (t) => shoot(t, const HomeScreen(tour: false), '03-home-simple'));
    testWidgets('04 tour', (t) => shoot(t, const HomeScreen(tour: true), '04-voice-guided-first-use'));
    testWidgets('05 practice', (t) => shoot(t, const PracticeClassScreen(), '05-practice-class', act: () => tap(t, 'practiceNext')));
    testWidgets('06 lesson', (t) async {
      late Services sv;
      await shoot(t, lesson(() => sv), '06-lesson-simple-mode', prep: (s) async => sv = s);
    });
    testWidgets('07 help', (t) async {
      late Services sv;
      await shoot(t, lesson(() => sv), '07-what-do-i-do-now', prep: (s) async => sv = s, act: () => tap(t, 'lessonHelp'));
    });
    testWidgets('08 board', (t) => shoot(t, const BoardPage(), '08-simple-whiteboard'));
    testWidgets('09 quiz', (t) async {
      late Services sv;
      await shoot(t, Builder(builder: (c) {
        final p = sv.store.byChapter('puc1-physics-07-gravitation')!;
        return SimpleQuizScreen(pack: p, questions: quizQuestions(p, topicId: 'puc1-physics-07-gravitation.t3'));
      }), '09-quiz-tap-roll-numbers', prep: (s) async => sv = s, act: () async {
        for (final r in const [1, 2, 4, 5, 8, 9, 11, 12, 14, 17, 18, 21, 23, 26, 27, 30, 33, 36]) {
          await tap(t, 'roll-$r');
        }
      });
    });
    testWidgets('10 finish', (t) async {
      await shoot(t, const FinishClassScreen(recordId: 'c1'), '10-finish-class', prep: (s) async {
        final hit = s.lessonFor('puc1-physics-07-gravitation.t3')!;
        s.school.addClass(ClassRecord(id: 'c1', at: DateTime(2026, 11, 4, 10, 30), subject: 'physics', topicId: hit.lesson.topicId, topic: hit.lesson.title, chapter: hit.pack.chapter.title, stepsSeen: hit.lesson.blocks.length, stepsTotal: hit.lesson.blocks.length, minutes: 42, teacherId: 't1', teacherName: 'K. Meera', homework: 'Textbook questions 8.3 and 8.5', absent: const [7, 15, 22, 31], rollCount: 40));
      });
    });
    testWidgets('11 all tools', (t) => shoot(t, const HomeScreen(tour: false), '11-show-all-tools', prep: (s) async => s.school.setShowAll(true)));
    testWidgets('12 home kn', (t) => shoot(t, const HomeScreen(tour: false), '12-home-kannada', lang: 'kn'));
    testWidgets('13 home phone', (t) => shoot(t, const HomeScreen(tour: false), '13-home-phone', size: phone));
  });

  // The whiteboard in the simple-first (v8) design.
  group('v9-whiteboard', () {
    setUpAll(() async {
      Future<void> fam(String name, String prefix, String dir) async {
        final l = FontLoader(name);
        for (final f in Directory(dir).listSync().whereType<File>().where((f) => f.path.split('/').last.startsWith(prefix))) {
          l.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
        }
        await l.load();
      }
      await fam(KxFonts.kalam, 'Kalam-', kx);
    });
    const board = Size(1920, 1080), tablet = Size(820, 1180);

    Future<void> shoot(WidgetTester t, WbView v, String name, {Size size = board, String lang = 'en'}) async {
      final s = await shotServices(prefs: {'displaySize': size == board ? 'classroom' : 'normal', 'rollCount': 40, 'lang': lang});
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      debugDisableShadows = false;
      await t.pumpWidget(ZynetixBoardApp(services: s, home: WhiteboardScreen(view: v)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('v9-whiteboard/$name.png'));
      debugDisableShadows = true;
    }

    testWidgets('01 simple', (t) => shoot(t, WbView.simple, '01-whiteboard-simple'));
    testWidgets('02 all tools', (t) => shoot(t, WbView.allTools, '02-whiteboard-all-tools'));
    testWidgets('03 geometry', (t) => shoot(t, WbView.geometry, '03-geometry-tools'));
    testWidgets('04 kit', (t) => shoot(t, WbView.kit, '04-subject-kit-3d-model'));
    testWidgets('05 lesson page', (t) => shoot(t, WbView.lessonPage, '05-lesson-step-as-page'));
    testWidgets('06 insert', (t) => shoot(t, WbView.insert, '06-insert-menu'));
    testWidgets('07 projector', (t) => shoot(t, WbView.projector, '07-projector-view'));
    testWidgets('08 kannada', (t) => shoot(t, WbView.simple, '08-whiteboard-kannada', lang: 'kn'));
    testWidgets('09 tablet', (t) => shoot(t, WbView.simple, '09-whiteboard-tablet', size: tablet));
  });

  // Release 2.0: the approved v8 (simple-first) and v9 (whiteboard) screens, all from the real
  // widgets of the app, on the same sample day. v9 shots are prefixed wb-.
  group('v10-app', () {
    setUpAll(() async {
      final l = FontLoader(KxFonts.kalam);
      for (final f in Directory(kx).listSync().whereType<File>().where((f) => f.path.split('/').last.startsWith('Kalam-'))) {
        l.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
      await l.load();
    });
    const board = Size(1920, 1080), phone = Size(390, 844), tablet = Size(820, 1180);

    Future<void> shoot(WidgetTester t, Widget Function(Services) home, String name, {Size size = board, String lang = 'en', Map<String, Object> prefs = const {}, Future<void> Function(Services)? prep, Future<void> Function()? act}) async {
      BoardStore.instance = BoardStore();
      final s = await shotServices(taught: gravitation, prefs: {'displaySize': size == board ? 'classroom' : 'normal', 'rollCount': 40, 'lang': lang, ...prefs});
      await prep?.call(s);
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      debugDisableShadows = false;
      await t.pumpWidget(ZynetixBoardApp(services: s, home: Builder(builder: (_) => home(s))));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await act?.call();
      await t.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('v10-app/$name.png'));
      debugDisableShadows = true;
    }

    Future<void> tap(WidgetTester t, String key) async {
      await t.tap(find.byKey(ValueKey(key)).first);
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
    }

    /// A few lines of chalk-talk on the board: a boxed formula and an arrow.
    Future<void> scribble(WidgetTester t) async {
      final c = t.getCenter(find.byKey(const ValueKey('smartboardCanvas')));
      Future<void> line(List<Offset> pts) async {
        final g = await t.startGesture(c + pts.first, kind: PointerDeviceKind.stylus);
        for (var i = 1; i < pts.length; i++) {
          final a = pts[i - 1], b = pts[i];
          final n = max(1, ((b - a).distance / 12).ceil());
          for (var k = 1; k <= n; k++) {
            await g.moveTo(c + Offset.lerp(a, b, k / n)!);
          }
        }
        await g.up();
        await t.pump();
      }

      await line([const Offset(-520, -200), const Offset(-120, -200), const Offset(-120, -80), const Offset(-520, -80), const Offset(-520, -200)]);
      for (var i = 0; i < 4; i++) {
        await line([Offset(-480.0 + i * 90, -170), Offset(-430.0 + i * 90, -110)]);
      }
      Future<void> pen(String simple) async {
        if (find.byKey(ValueKey(simple)).evaluate().isNotEmpty) await tap(t, simple);
      }

      await pen('tool-red');
      await line([const Offset(160, -220), const Offset(160, 40)]);
      await line([const Offset(130, 10), const Offset(160, 40), const Offset(190, 10)]);
      await pen('tool-blue');
      await line([for (var a = 0; a <= 36; a++) Offset(360 + 150 * cos(a * pi / 18), 60 + 150 * sin(a * pi / 18))]);
    }

    ({InstalledPack pack, Lesson lesson}) hit(Services s) => s.lessonFor('puc1-physics-07-gravitation.t3')!;
    Widget lesson(Services s, {int step = 1}) => SimpleLessonScreen(pack: hit(s).pack, lesson: hit(s).lesson, period: s.school.periods.firstWhere((p) => p.id == 'p2'), startStep: step);
    InstalledPack grav(Services s) => s.store.byChapter('puc1-physics-07-gravitation')!;
    Widget chapterBoard(Services s) => SmartboardScreen(pack: grav(s));
    Widget lessonBoard(Services s) => SmartboardScreen(pack: hit(s).pack, lesson: hit(s).pack.lessonFor(hit(s).lesson, s.config.board), step: 2);

    // v8 · the simple-first app
    testWidgets('01 first open', (t) => shoot(t, (_) => const FirstOpenScreen(), '01-first-open-language'));
    testWidgets('02 who', (t) => shoot(t, (_) => const WhoTodayScreen(), '02-who-is-teaching-no-pin', prep: (s) async => s.school.signIn(null)));
    testWidgets('03 home', (t) => shoot(t, (_) => const HomeScreen(tour: false), '03-home-simple'));
    testWidgets('04 tour', (t) => shoot(t, (_) => const HomeScreen(tour: true), '04-voice-guided-first-use'));
    testWidgets('05 practice', (t) => shoot(t, (_) => const PracticeClassScreen(), '05-practice-class', act: () => tap(t, 'practiceNext')));
    testWidgets('06 lesson', (t) => shoot(t, lesson, '06-lesson-simple-mode'));
    testWidgets('07 help', (t) => shoot(t, lesson, '07-what-do-i-do-now', act: () => tap(t, 'lessonHelp')));
    testWidgets('08 board', (t) => shoot(t, (_) => const BoardPage(), '08-simple-whiteboard'));
    testWidgets('09 quiz', (t) => shoot(t, (s) => SimpleQuizScreen(pack: grav(s), questions: quizQuestions(grav(s), topicId: 'puc1-physics-07-gravitation.t3')), '09-quiz-tap-roll-numbers', act: () async {
      for (final r in const [1, 2, 4, 5, 8, 9, 11, 12, 14, 17, 18, 21, 23, 26, 27, 30, 33, 36]) {
        await tap(t, 'roll-$r');
      }
    }));
    testWidgets('10 finish', (t) => shoot(t, (_) => const FinishClassScreen(recordId: 'c1'), '10-finish-class', prep: (s) async {
      final h = hit(s);
      s.school.addClass(ClassRecord(id: 'c1', at: DateTime(2026, 11, 4, 10, 30), subject: 'physics', topicId: h.lesson.topicId, topic: h.lesson.title, chapter: h.pack.chapter.title, stepsSeen: h.lesson.blocks.length, stepsTotal: h.lesson.blocks.length, minutes: 42, teacherId: 't1', teacherName: 'K. Meera', homework: 'Textbook questions 8.3 and 8.5', absent: const [7, 15, 22, 31], rollCount: 40));
    }));
    testWidgets('11 all tools', (t) => shoot(t, (_) => const HomeScreen(tour: false), '11-show-all-tools', prep: (s) async => s.school.setShowAll(true)));
    testWidgets('12 home kn', (t) => shoot(t, (_) => const HomeScreen(tour: false), '12-home-kannada', lang: 'kn'));
    testWidgets('13 home phone', (t) => shoot(t, (_) => const HomeScreen(tour: false), '13-home-phone', size: phone));
    testWidgets('14 lesson kn', (t) => shoot(t, lesson, '14-lesson-kannada', lang: 'kn'));
    testWidgets('15 lesson phone', (t) => shoot(t, lesson, '15-lesson-phone', size: phone));
    testWidgets('16 quiz phone', (t) => shoot(t, (s) => SimpleQuizScreen(pack: grav(s), questions: quizQuestions(grav(s), topicId: 'puc1-physics-07-gravitation.t3')), '16-quiz-phone', size: phone, act: () async {
      for (final r in const [1, 2, 4, 5]) {
        await tap(t, 'roll-$r');
      }
    }));
    testWidgets('17 all tools phone', (t) => shoot(t, (_) => const HomeScreen(tour: false), '17-show-all-tools-phone', size: phone, prep: (s) async => s.school.setShowAll(true)));

    // v9 · the whiteboard
    testWidgets('wb 01 simple', (t) => shoot(t, chapterBoard, 'wb-01-whiteboard-simple', act: () => scribble(t)));
    testWidgets('wb 02 all tools', (t) => shoot(t, chapterBoard, 'wb-02-whiteboard-all-tools', prefs: {'smartboardAllTools': true}, act: () => scribble(t)));
    testWidgets('wb 03 geometry', (t) => shoot(t, chapterBoard, 'wb-03-geometry-tools', prefs: {'smartboardAllTools': true}, act: () async {
      await tap(t, 'geo-ruler');
      await tap(t, 'geo-protractor');
    }));
    testWidgets('wb 04 kit', (t) => shoot(t, chapterBoard, 'wb-04-subject-kit', act: () => tap(t, 'openKit')));
    testWidgets('wb 05 lesson page', (t) => shoot(t, lessonBoard, 'wb-05-lesson-step-as-page'));
    testWidgets('wb 06 insert', (t) => shoot(t, chapterBoard, 'wb-06-insert-menu', act: () => tap(t, 'insert')));
    testWidgets('wb 07 projector', (t) => shoot(t, chapterBoard, 'wb-07-projector-view', prefs: {'smartboardAllTools': true}, act: () async {
      await scribble(t);
      await tap(t, 'projector');
    }));
    testWidgets('wb 08 kannada', (t) => shoot(t, chapterBoard, 'wb-08-whiteboard-kannada', lang: 'kn', act: () => scribble(t)));
    testWidgets('wb 09 tablet', (t) => shoot(t, chapterBoard, 'wb-09-whiteboard-tablet', size: tablet));
    testWidgets('wb 10 phone', (t) => shoot(t, chapterBoard, 'wb-10-whiteboard-phone', size: phone));
  });

  testWidgets('33 accounting equation', (t) => sim(t, 'puc1-accountancy-03-recording-of-transactions-i.t2', 'sim1', '33-sim-accounting-equation'));
}

/// Places a few of the sort activity's items (tap an item, then a column), leaving one selected.
Future<void> sortSome(WidgetTester t) async {
  for (final (item, bucket) in [(0, 'asset'), (1, 'asset'), (4, 'liability'), (3, 'asset'), (8, 'capital'), (5, 'liability')]) {
    final chip = find.byKey(ValueKey('item-$item'));
    final col = find.byKey(ValueKey('bucket-$bucket'));
    if (chip.evaluate().isEmpty || col.evaluate().isEmpty) continue;
    await t.tap(chip, warnIfMissed: false);
    await t.pump();
    await t.tap(col, warnIfMissed: false);
    await t.pump();
  }
  final next = find.byKey(const ValueKey('item-6'));
  if (next.evaluate().isNotEmpty) {
    await t.tap(next);
    await t.pump();
  }
}

int _index(WidgetTester t) {
  final txt = (find.byKey(const ValueKey('stepOf')).evaluate().first.widget as Text).data!;
  return int.parse(RegExp(r'\d+').firstMatch(txt)!.group(0)!) - 1;

}

/// The demo's player: each clip "plays" until the harness has taken its frame.
class DemoPlayer implements VoicePlayer {
  VoiceClip? current;
  Completer<bool>? _c;
  @override
  Future<bool> play(VoiceClip clip) {
    current = clip;
    return (_c = Completer<bool>()).future;
  }

  void finish() {
    current = null;
    if (!(_c?.isCompleted ?? true)) _c!.complete(true);
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {
    current = null;
    if (!(_c?.isCompleted ?? true)) _c!.complete(false);
  }

  @override
  Future<void> dispose() async {}
}
