import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinetix_ink/kinetix_ink.dart' hide Lesson;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zynetix_board/engine/model.dart' show Lang;
import 'package:zynetix_board/features/smartboard.dart';
import 'package:zynetix_board/whiteboard/board_store.dart';
import 'package:zynetix_board/whiteboard/lesson_steps.dart';
import 'package:zynetix_board/whiteboard/live_objects.dart';
import 'package:zynetix_board/whiteboard/pptx_import.dart';
import 'package:zynetix_board/whiteboard/recording.dart';
import 'package:zynetix_board/whiteboard/remote.dart';
import 'package:zynetix_board/whiteboard/subject_kit.dart';
import 'package:zynetix_board/whiteboard/wb_widgets.dart';

import 'helpers.dart';

const gravitation = 'puc1-physics-07-gravitation';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

/// Opens the Smartboard on its own (simple mode) and returns its state.
Future<SmartboardScreenState> openBoard(WidgetTester t, {Map<String, Object> prefs = const {}, Widget? home, Size size = const Size(1920, 1080)}) async {
  final s = await testServices(prefs: prefs);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await pumpBoard(t, s, home: home ?? const SmartboardScreen());
  t.view.physicalSize = size;
  await settle(t);
  return t.state<SmartboardScreenState>(find.byType(SmartboardScreen));
}

/// Draws a line across the middle of the board with a stylus.
Future<void> draw(WidgetTester t, {double dy = 0}) async {
  final c = t.getCenter(find.byKey(const ValueKey('smartboardCanvas'))) + Offset(0, dy);
  final g = await t.startGesture(c - const Offset(120, 0), kind: PointerDeviceKind.stylus);
  for (var i = 1; i <= 12; i++) {
    await g.moveTo(c - const Offset(120, 0) + Offset(i * 20.0, i.isEven ? 4 : -4));
  }
  await g.up();
  await t.pump();
}

/// A one-slide .pptx with a title.
Uint8List tinyPptx(String title) {
  final a = Archive();
  void add(String name, String text) {
    final b = utf8.encode(text);
    a.addFile(ArchiveFile(name, b.length, b));
  }

  add('ppt/presentation.xml', '<p:presentation xmlns:p="p" xmlns:r="r"><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst><p:sldSz cx="12192000" cy="6858000"/></p:presentation>');
  add('ppt/_rels/presentation.xml.rels', '<Relationships><Relationship Id="rId1" Target="slides/slide1.xml"/></Relationships>');
  add(
    'ppt/slides/slide1.xml',
    '<p:sld xmlns:p="p" xmlns:a="a"><p:cSld><p:spTree>'
        '<p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr><p:spPr><a:xfrm><a:off x="838200" y="365125"/><a:ext cx="10515600" cy="1325563"/></a:xfrm></p:spPr>'
        '<p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="4400"/><a:t>$title</a:t></a:r></a:p></p:txBody></p:sp>'
        '<p:sp><p:spPr><a:xfrm><a:off x="838200" y="2000000"/><a:ext cx="3000000" cy="2000000"/></a:xfrm><a:prstGeom prst="ellipse"/><a:solidFill><a:srgbClr val="2457E6"/></a:solidFill></p:spPr></p:sp>'
        '</p:spTree></p:cSld></p:sld>',
  );
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  setUp(() {
    BoardStore.instance = BoardStore();
    RecordingStore.instance = RecordingStore();
  });

  group('tools', () {
    testWidgets('simple mode: pen colours, highlighter, eraser; the simple tools only', (t) async {
      final st = await openBoard(t);
      final b = st.board;
      expect(find.byKey(const ValueKey('all-shapes')), findsNothing, reason: 'simple first');
      await t.tap(find.byKey(const ValueKey('tool-blue')));
      await t.pump();
      expect(b.tool, BoardTool.pen);
      expect(b.penColor, wbBlue);
      await t.tap(find.byKey(const ValueKey('tool-red')));
      await t.pump();
      expect(b.penColor, wbRed);
      await t.tap(find.byKey(const ValueKey('tool-highlighter')));
      await t.pump();
      expect(b.tool, BoardTool.highlighter);
      await t.tap(find.byKey(const ValueKey('tool-eraser')));
      await t.pump();
      expect(b.tool, BoardTool.eraser);
      expect(b.inputConfig.eraser.mode, EraserMode.stroke);
    });

    testWidgets('Show all tools: grouped tools, shapes, text, eraser modes, measuring tools; remembered', (t) async {
      final st = await openBoard(t);
      final b = st.board;
      await t.tap(find.byKey(const ValueKey('showAllTools')));
      await t.pump();
      expect(st.allTools, isTrue);
      expect((await SharedPreferences.getInstance()).getBool('smartboardAllTools'), isTrue);
      await t.tap(find.byKey(const ValueKey('all-text')));
      await t.pump();
      expect(b.tool, BoardTool.text);
      await t.tap(find.byKey(const ValueKey('all-pen')));
      await t.pump();
      expect(find.byKey(const ValueKey('penChooser')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('colour-ff1f9d55')));
      await t.tap(find.byKey(const ValueKey('width-Thick')));
      await t.pump();
      expect(b.penColor, wbGreen);
      expect(b.penWidth, 16);
      await t.tap(find.byKey(const ValueKey('all-shapes')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('shape-triangle')));
      await settle(t);
      expect((b.tool, b.shapeKind), (BoardTool.shape, ShapeKind.triangle));
      await t.tap(find.byKey(const ValueKey('all-eraser')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('all-eraser')));
      await t.pump();
      expect(b.inputConfig.eraser.mode, EraserMode.area, reason: 'a second tap rubs out only a part');
      await t.tap(find.byKey(const ValueKey('geo-ruler')));
      await t.tap(find.byKey(const ValueKey('geo-protractor')));
      await t.pump();
      expect(b.geoTools.value.map((g) => g.kind), [GeoKind.ruler, GeoKind.protractor]);
      // Back to simple: the measuring view with "Put the tools away".
      await t.tap(find.byKey(const ValueKey('showAllTools')));
      await t.pump();
      expect(find.text('How to measure an angle'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('putToolsAway')));
      await t.pump();
      expect(b.geoTools.value, isEmpty);
      expect(find.byKey(const ValueKey('tool-highlighter')), findsOneWidget);
    });

    testWidgets('backgrounds, zoom, graph and number line', (t) async {
      final st = await openBoard(t, prefs: {'smartboardAllTools': true});
      final b = st.board;
      expect(st.allTools, isTrue);
      await t.tap(find.byKey(const ValueKey('bg-graph')));
      await t.pump();
      expect(b.background, BoardBackground.graph);
      await t.tap(find.byKey(const ValueKey('zoomIn')));
      await t.pump();
      expect(b.view.value.scale, closeTo(1.25, .01));
      await t.tap(find.byKey(const ValueKey('zoomReset')));
      await t.pump();
      expect(b.view.value.scale, closeTo(1, .01));
      await t.tap(find.byKey(const ValueKey('all-numberLine')));
      await t.pump();
      expect(b.elements.whereType<TextElement>().map((e) => e.text), containsAll(['-10', '0', '10']));
      st.insertGraph();
      await settle(t);
      expect(b.elements.whereType<GraphElement>(), hasLength(1));
    });
  });

  group('undo', () {
    testWidgets('a stroke is drawn, undone and redone; Clear asks first and Undo brings it back', (t) async {
      final st = await openBoard(t);
      final b = st.board;
      await draw(t);
      expect(b.elements.whereType<Stroke>(), hasLength(1));
      await t.tap(find.byKey(const ValueKey('undo')));
      await t.pump();
      expect(b.elements, isEmpty);
      b.redo();
      await t.pump();
      expect(b.elements, hasLength(1));
      await t.tap(find.byKey(const ValueKey('clearPage')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('confirmNo')));
      await settle(t);
      expect(b.elements, hasLength(1), reason: 'Keep it');
      await t.tap(find.byKey(const ValueKey('clearPage')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('confirmYes')));
      await settle(t);
      expect(b.elements, isEmpty);
      await t.tap(find.byKey(const ValueKey('undo')));
      await t.pump();
      expect(b.elements, hasLength(1));
    });
  });

  group('pages', () {
    testWidgets('add (not from a blank page), open, reorder, copy and delete', (t) async {
      final st = await openBoard(t);
      final b = st.board;
      await t.tap(find.byKey(const ValueKey('newPage')));
      await t.pump();
      expect(b.pageCount, 1, reason: 'a blank page does not spawn another');
      await draw(t);
      await t.tap(find.byKey(const ValueKey('newPage')));
      await t.pump();
      expect((b.pageCount, b.pageIndex), (2, 1));
      await draw(t, dy: 60);
      await draw(t, dy: 120);
      expect(find.byKey(const ValueKey('pageThumb-1')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('pageThumb-0')));
      await t.pump();
      expect(b.pageIndex, 0);
      expect(b.elements, hasLength(1));
      // Hold page 1: move it later.
      await t.longPress(find.byKey(const ValueKey('pageThumb-0')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('pageAction-right')));
      await settle(t);
      expect(b.pages[1].elements, hasLength(1), reason: 'the one-stroke page is now second');
      await t.longPress(find.byKey(const ValueKey('pageThumb-1')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('pageAction-duplicate')));
      await settle(t);
      expect(b.pageCount, 3);
      await t.longPress(find.byKey(const ValueKey('pageThumb-2')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('pageAction-delete')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('confirmYes')));
      await settle(t);
      expect(b.pageCount, 2);
    });
  });

  group('persistence', () {
    test('a board is saved per class and chapter, with its pages, papers and lesson-step pages', () async {
      final dir = Directory.systemTemp.createTempSync('zx-boards');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = BoardStore(dir: dir);
      final k = const BoardKey('1puc-a', gravitation);
      final b = await store.open(k);
      final c = b.controller;
      c.add(lineStroke(const Offset(10, 10), const Offset(200, 10), color: wbRed, width: 9));
      c.addPage();
      c.background = BoardBackground.grid;
      c.add(liveObject(LiveKind.model3d, 'earth_layers', const Offset(600, 400)));
      b.stepPages[c.page.id] = 'b3';
      await store.save(b);
      expect(File('${dir.path}/${k.file}').existsSync(), isTrue);

      // Next period: a new app run reads it back.
      final again = await BoardStore(dir: dir).open(k);
      final c2 = again.controller;
      expect(c2.pageCount, 2);
      expect(c2.pageIndex, 1, reason: 'opens on the page the teacher left');
      expect(c2.background, BoardBackground.grid);
      expect(c2.elements.whereType<ImageElement>().single.link, const EmbedLink(kind: 'model3d', id: 'earth_layers', preset: 'v:front'));
      expect(again.pageForStep('b3'), 1);
      expect(c2.pages.first.elements.whereType<Stroke>().single.style.color, wbRed);

      // Another class's board of the same chapter is its own.
      final other = await BoardStore(dir: dir).open(const BoardKey('1puc-b', gravitation));
      expect(other.controller.isBlank, isTrue);
    });

    testWidgets('closing and opening the board for the class keeps the writing', (t) async {
      final st = await openBoard(t);
      await draw(t);
      final key = st.openBoard!.key;
      await t.tap(find.byKey(const ValueKey('closeSmartboard')));
      await settle(t);
      expect(BoardStore.instance.openNow(key)!.controller.elements, hasLength(1));
      await t.pumpWidget(const SizedBox());
      final st2 = await openBoard(t);
      expect(st2.board.elements, hasLength(1));
    });
  });

  group('insert', () {
    testWidgets('a 3D model is a live, movable object; Remove and Undo', (t) async {
      final st = await openBoard(t);
      final b = st.board;
      st.insertLive(LiveKind.model3d, 'earth_layers');
      await t.pump();
      expect(find.byKey(const ValueKey('embed:3d:earth_layers')), findsOneWidget);
      final id = b.elements.single.id;
      final before = (b.elements.single as ImageElement).rect;
      await t.drag(find.byKey(ValueKey('liveMove-$id')), const Offset(100, 40));
      await t.pump();
      final after = (b.byId(id)! as ImageElement).rect;
      expect(after.left, greaterThan(before.left));
      b.undo();
      await t.pump();
      expect((b.byId(id)! as ImageElement).rect, before, reason: 'one undo step per move');
      await t.tap(find.byKey(ValueKey('liveRemove-$id')));
      await t.pump();
      expect(b.elements, isEmpty);
      b.undo();
      await t.pump();
      expect(find.byKey(const ValueKey('embed:3d:earth_layers')), findsOneWidget);
    });

    testWidgets('the Insert menu: blank page and template', (t) async {
      final st = await openBoard(t);
      final b = st.board;
      await draw(t);
      await t.tap(find.byKey(const ValueKey('insert')));
      await settle(t);
      expect(find.text('What do you want to put on the board?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('insert-blank')));
      await settle(t);
      expect((b.pageCount, b.elements.length), (2, 0));
      await draw(t);
      await t.tap(find.byKey(const ValueKey('insert')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('insert-template')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('template-ruled')));
      await settle(t);
      expect((b.pageCount, b.background), (3, BoardBackground.ruled));
    });

    test('PowerPoint: each slide becomes a page with its text and shapes', () async {
      final deck = await importPptx(tinyPptx('Newton’s law'));
      expect(deck.title, 'Newton’s law');
      expect(deck.pages, hasLength(1));
      final els = deck.pages.single.elements;
      expect(els.whereType<TextElement>().map((e) => e.text), ['Newton’s law']);
      expect(els.whereType<Stroke>().single.shape, ShapeKind.ellipse);
      expect(() => importPptx(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });

    testWidgets('PowerPoint slides are added as pages after this one', (t) async {
      final st = await openBoard(t);
      await draw(t);
      final n = await t.runAsync(() => st.importSlides(tinyPptx('Gravitation')));
      await t.pump();
      expect(n, 1);
      expect(st.board.pageCount, 2);
      expect(st.board.elements.whereType<TextElement>().single.text, 'Gravitation');
    });
  });

  group('subject kit and lesson pages', () {
    testWidgets('the kit lists the chapter’s models, labs, sims, explainers and exam questions; Put on board', (t) async {
      final s = await testServices();
      final pack = s.store.byChapter(gravitation)!;
      final kit = subjectKit(pack);
      expect(kit.map((i) => i.kind).toSet(), containsAll([KitKind.model3d, KitKind.sim, KitKind.explainer, KitKind.exam, KitKind.video]));
      expect(kit.where((i) => i.online).map((i) => i.kind), [KitKind.video], reason: 'only concept videos need the internet');
      final st = await openBoard(t, home: SmartboardScreen(pack: pack));
      await t.tap(find.byKey(const ValueKey('openKit')));
      await t.pump();
      expect(find.text('Subject kit for this chapter'), findsOneWidget);
      final model = kit.firstWhere((i) => i.kind == KitKind.model3d);
      await t.tap(find.byKey(ValueKey('put-${model.key}')));
      await t.pump();
      expect(find.text('On the board'), findsOneWidget);
      expect(st.board.elements.whereType<ImageElement>().single.link!.id, model.ref);
      final exam = kit.firstWhere((i) => i.kind == KitKind.exam);
      st.putOnBoard(exam);
      await t.pump();
      expect(st.board.elements.whereType<NoteElement>().where((n) => n.hidden), isNotEmpty, reason: 'answers are covered');
    });

    testWidgets('a lesson step opens as a page with the flow bar, quick check and recap; pages are kept', (t) async {
      final s = await testServices();
      final pack = s.store.byChapter(gravitation)!;
      final lesson = pack.lessons.values.firstWhere((l) => l.topicId.endsWith('t3'));
      final st = await openBoard(
        t,
        home: SmartboardScreen(pack: pack, lesson: lesson, step: 1),
      );
      expect(find.byKey(const ValueKey('flowBar')), findsOneWidget);
      expect(find.textContaining('From lesson step'), findsNothing, reason: 'it is board text, painted');
      expect(st.board.elements.whereType<TextElement>().first.text, startsWith('From lesson step 2'));
      expect(find.text('Back to the lesson'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('showAnswer')));
      await t.pump();
      expect(find.text('Tap to show the answer'), findsNothing);
      await draw(t);
      final pages = st.board.pageCount;
      await t.tap(find.byKey(const ValueKey('nextStep')));
      await t.pump();
      expect(st.stepAt, 2);
      expect(st.board.pageCount, pages + 1);
      await t.tap(find.byKey(const ValueKey('flowStep-1')));
      await t.pump();
      expect(st.board.pageCount, pages + 1, reason: 'the step’s page is reopened, with the writing');
      expect(st.board.elements.whereType<Stroke>(), hasLength(1));
      await t.tap(find.byKey(const ValueKey('openRecap')));
      await t.pump();
      expect(st.board.elements.whereType<TextElement>().first.text, startsWith('Recap'));
    });

    test('lesson steps carry minutes and a title', () async {
      final s = await testServices();
      final lesson = s.store.byChapter(gravitation)!.lessons.values.first;
      final steps = lessonSteps(lesson);
      expect(steps, isNotEmpty);
      expect(steps.every((x) => x.minutes >= 1 && x.title.en.isNotEmpty), isTrue);
    });
  });

  group('Kannada', () {
    testWidgets('every tool is labelled in Kannada', (t) async {
      await openBoard(t, prefs: {'lang': 'kn'});
      for (final w in ['ಪೆನ್', 'ನೀಲಿ', 'ಕೆಂಪು', 'ಹೈಲೈಟ್', 'ರಬ್ಬರ್', 'ರದ್ದುಮಾಡು', 'ಅಳಿಸಿ', 'ಎಲ್ಲಾ ಸಾಧನಗಳನ್ನು ತೋರಿಸಿ']) {
        expect(find.text(w), findsWidgets, reason: w);
      }
      await t.tap(find.byKey(const ValueKey('showAllTools')));
      await t.pump();
      for (final w in ['ಅಳತೆಪಟ್ಟಿ', 'ಕೋನಮಾಪಕ', 'ಕೈವಾರ', 'ಮೂಲೆಮಟ್ಟ', 'ಗ್ರಾಫ್', 'ಸಂಖ್ಯಾ ರೇಖೆ', 'ರೆಕಾರ್ಡ್', 'ಓದಿ ಹೇಳಿ', 'ಫೋನ್ ರಿಮೋಟ್']) {
        expect(find.text(w), findsWidgets, reason: w);
      }
    });
  });

  group('phone and tablet', () {
    testWidgets('a tablet held upright gets the stacked board with big tool tiles', (t) async {
      final st = await openBoard(t, size: const Size(820, 1180));
      expect(find.byKey(const ValueKey('tool-pen')), findsOneWidget);
      expect(find.byKey(const ValueKey('insert')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tool-blue')));
      await t.pump();
      expect(st.board.penColor, wbBlue);
      await t.tap(find.byKey(const ValueKey('showAllTools')));
      await t.pump();
      expect(find.byKey(const ValueKey('geo-ruler')), findsOneWidget);
    });
  });

  group('remote, recording, read aloud', () {
    test('the phone remote obeys only its own key', () async {
      final done = <String>[];
      final r = RemoteServer(onAction: done.add, state: () => {'page': 1, 'pages': 2});
      expect((await r.api('wrong', 'next'))['ok'], false);
      expect(done, isEmpty);
      expect(await r.api(r.key, 'next'), {'ok': true, 'page': 1, 'pages': 2});
      await r.api(r.key, 'state');
      expect(done, ['next']);
      expect(remotePage(Lang.kn), contains('ಮುಂದೆ'));
      expect(remotePage(Lang.en), isNot(contains('capture')), reason: 'no camera on the phone page');
    });

    test('a recording keeps the board as it changed, and plays it back', () async {
      final dir = Directory.systemTemp.createTempSync('zx-rec');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = RecordingStore(dir: dir);
      final c = BoardStore.newController();
      final rec = BoardRecorder(c, title: 'Gravitation', store: store);
      await rec.start(voice: false);
      c.add(lineStroke(const Offset(0, 0), const Offset(100, 0), color: wbInk, width: 9));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      c.add(TextElement(id: newElementId(), position: Offset.zero, text: 'g = 9.8', color: wbInk, fontSize: 40, size: const Size(200, 50)));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final r = (await rec.stop())!;
      expect(r.frames.length, greaterThanOrEqualTo(3));
      expect(r.elementsOf(r.frames.first), isEmpty);
      expect(r.elementsOf(r.frames.last), hasLength(2));
      final saved = await store.list();
      expect(saved.single.title, 'Gravitation');
      expect(saved.single.voice, isNull);
      rec.dispose();
    });

    testWidgets('Read aloud reads the words on the page', (t) async {
      final st = await openBoard(t);
      st.board.addAll(boardTextFor('Newton’s law of gravitation'));
      await t.pump();
      expect(st.reading, isFalse);
      final f = st.readAloud();
      await t.pump();
      expect(st.reading, isTrue);
      await settle(t);
      await f;
    });
  });
}

List<BoardElement> boardTextFor(String s) => boardText(s, const Offset(100, 100)).$1;
