import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kinetix_ink/kinetix_ink.dart' hide Lesson;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/apps.dart';
import '../core/services.dart';
import '../core/strings.dart' as strings;
import '../core/theme.dart' show ScreenSize;
import '../core/ui.dart' show ZSmallButton;
import '../engine/model.dart';
import '../whiteboard/board_store.dart';
import '../whiteboard/board_tools.dart';
import '../whiteboard/insert_menu.dart';
import '../whiteboard/lesson_steps.dart';
import '../whiteboard/live_objects.dart';
import '../whiteboard/pptx_import.dart';
import '../whiteboard/recording.dart';
import '../whiteboard/remote.dart';
import '../whiteboard/subject_kit.dart';
import '../whiteboard/wb_widgets.dart';
import 'simple/kit.dart';

/// The always-visible way to the Smartboard. [onOpen] runs before it opens (the lesson player
/// pauses), [onClose] after it closes. With a [lesson] the board opens on that lesson's step
/// [step] as a page; [onStep] hears where the teacher went (so the lesson can follow).
class SmartboardButton extends StatelessWidget {
  const SmartboardButton({super.key, this.onOpen, this.onClose, this.pack, this.lesson, this.step, this.onStep});
  final VoidCallback? onOpen, onClose;
  final InstalledPack? pack;
  final Lesson? lesson;
  final int? step;
  final ValueChanged<int>? onStep;

  @override
  Widget build(BuildContext context) {
    final l = ServicesScope.of(context).config.lang;
    return ZSmallButton(
      key: const ValueKey('smartboard'),
      iconOnly: context.narrow,
      icon: Icons.desktop_windows_outlined,
      label: strings.tr('smartboard', l),
      onPressed: () async {
        onOpen?.call();
        await openSmartboard(context, pack: pack, lesson: lesson, step: step, onStep: onStep);
        onClose?.call();
      },
    );
  }
}

/// Opens the Smartboard: the board of this class and [pack]'s chapter (saved, reopened next time).
Future<void> openSmartboard(BuildContext context, {InstalledPack? pack, Lesson? lesson, int? step, ValueChanged<int>? onStep, String? chapterId}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => SmartboardScreen(pack: pack, lesson: lesson, step: step, onStep: onStep, chapterId: chapterId),
  ),
);

/// The Smartboard (approved v9 design): a big white board with a few labelled tools ("simple"),
/// and "Show all tools" for the grouped tools — write, draw, fix, measure, maths, page, insert.
/// Boards are kept per class and chapter and come back next time. Everything works offline;
/// there is no AI and no camera anywhere on it.
class SmartboardScreen extends StatefulWidget {
  const SmartboardScreen({super.key, this.controller, this.pack, this.lesson, this.step, this.onStep, this.classId, this.chapterId, this.store});

  /// A board to show instead of the class's saved one (not saved).
  final WhiteboardController? controller;
  final InstalledPack? pack;
  final Lesson? lesson;

  /// The lesson block the teacher is on: the board opens it as a page.
  final int? step;
  final ValueChanged<int>? onStep;
  final String? classId, chapterId;
  final BoardStore? store;

  /// A new board in the Smartboard's look.
  static WhiteboardController newBoard() => BoardStore.newController();

  static WhiteboardController? _current, _blank;

  /// The board open now (the last one opened), for wrappers that offer its Undo.
  static WhiteboardController get shared => _current ?? (_blank ??= newBoard());

  @override
  State<SmartboardScreen> createState() => SmartboardScreenState();
}

/// Where the "Show all tools" switch is kept on this board.
const _allToolsPref = 'smartboardAllTools';

class SmartboardScreenState extends State<SmartboardScreen> {
  OpenBoard? _open;
  BoardStore get store => widget.store ?? BoardStore.instance;
  WhiteboardController get board => _open!.controller;
  OpenBoard? get openBoard => _open;

  bool allTools = false, penMenu = false, kitOpen = false, answerShown = false, reading = false, blank = false, geoHelp = true;
  BoardRecorder? recorder;
  RemoteServer? remote;

  /// Index into [steps] while a lesson step is shown as a page.
  int? stepAt;
  late final List<LessonStep> steps = widget.lesson == null ? const [] : lessonSteps(widget.lesson!, board: _services.config.board);
  List<KitItem>? _kit;

  late Services _services;
  Lang get l => _services.config.lang;
  InstalledPack? get pack => widget.pack ?? (widget.lesson == null ? null : _services.store.byChapter(widget.lesson!.chapterId));
  String get chapterId => widget.chapterId ?? pack?.chapter.id ?? widget.lesson?.chapterId ?? 'free';
  List<KitItem> get kit => _kit ??= pack == null ? const [] : subjectKit(pack!, board: _services.config.board);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = ServicesScope.of(context);
    if (_open == null && widget.controller == null) {
      final key = BoardKey(widget.classId ?? _services.config.sectionId, chapterId);
      final now = store.openNow(key);
      if (now != null) {
        _ready(now);
      } else {
        unawaited(store.open(key).then((b) => mounted ? setState(() => _ready(b)) : null));
      }
    } else if (_open == null) {
      _ready(OpenBoard(const BoardKey('preview'), widget.controller!));
    }
  }

  void _ready(OpenBoard b) {
    _open = b;
    SmartboardScreen._current = b.controller;
    unawaited(
      SharedPreferences.getInstance().then((p) {
        final on = p.getBool(_allToolsPref) ?? false;
        if (mounted && on != allTools) setState(() => allTools = on);
      }),
    );
    if (widget.lesson != null && widget.step != null) {
      final i = steps.indexWhere((s) => s.index >= widget.step!);
      if (i >= 0) showStep(i);
    }
  }

  @override
  void dispose() {
    unawaited(recorder?.stop());
    recorder?.dispose();
    unawaited(remote?.stop());
    if (reading) unawaited(_services.narrator.stop());
    if (_open != null && widget.controller == null) unawaited(store.save(_open!));
    super.dispose();
  }

  // ───────────────────────────── actions ─────────────────────────────

  void setAllTools(bool on) {
    setState(() {
      allTools = on;
      penMenu = false;
    });
    unawaited(SharedPreferences.getInstance().then((p) => p.setBool(_allToolsPref, on)));
  }

  void pen(Color c) {
    board.tool = BoardTool.pen;
    board.setPen(color: c);
  }

  void highlight() => board.setHighlighter();

  void eraser([EraserMode? mode]) {
    if (mode != null) board.inputConfig.eraser = board.inputConfig.eraser.copyWith(mode: mode);
    board.tool = BoardTool.eraser;
    setState(() {});
  }

  Future<void> clearPage() async {
    if (!board.canClearPage) return;
    final yes = await confirmBoard(
      context,
      l,
      tr(l, 'Clear this page?', 'ಈ ಪುಟವನ್ನು ಅಳಿಸಬೇಕೇ?'),
      tr(l, 'Everything written on this page goes. Undo brings it back.', 'ಈ ಪುಟದಲ್ಲಿ ಬರೆದದ್ದೆಲ್ಲ ಹೋಗುತ್ತದೆ. ರದ್ದುಮಾಡು ಅದನ್ನು ಮರಳಿ ತರುತ್ತದೆ.'),
      tr(l, 'Clear the page', 'ಪುಟ ಅಳಿಸಿ'),
    );
    if (yes) board.clearPage();
  }

  void _say(String en, String kn) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: S.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          content: Text(
            tr(l, en, kn),
            style: tx(32, c: Colors.white, w: FontWeight.w600),
          ),
        ),
      );
  }

  void addPage() {
    if (!board.canAddPage) {
      _say('This page is still empty: write on it first.', 'ಈ ಪುಟ ಇನ್ನೂ ಖಾಲಿ ಇದೆ: ಮೊದಲು ಇದರಲ್ಲಿ ಬರೆಯಿರಿ.');
      return;
    }
    board.addPage();
  }

  void pageAction(int i, PageAction a) {
    switch (a) {
      case PageAction.left:
        board.movePage(i, i - 1);
      case PageAction.right:
        board.movePage(i, i + 1);
      case PageAction.duplicate:
        board.duplicatePage(i);
      case PageAction.delete:
        unawaited(() async {
          final ok =
              board.pages[i].elements.isEmpty ||
              await confirmBoard(
                context,
                l,
                tr(l, 'Delete page ${i + 1}?', 'ಪುಟ ${i + 1} ಅಳಿಸಬೇಕೇ?'),
                tr(l, 'The page and what is on it go.', 'ಪುಟ ಮತ್ತು ಅದರಲ್ಲಿರುವುದು ಹೋಗುತ್ತದೆ.'),
                tr(l, 'Delete page', 'ಪುಟ ಅಳಿಸಿ'),
              );
          if (ok) board.deletePage(i);
        }());
    }
    setState(() {});
  }

  /// Turns a measuring tool on or off.
  void geo(GeoKind k) {
    final have = board.geoTools.value.where((t) => t.kind == k).firstOrNull;
    if (have != null) {
      board.removeGeoTool(have.id);
    } else {
      board.addGeoTool(k);
      geoHelp = true;
    }
    setState(() {});
  }

  bool geoOn(GeoKind k) => board.geoTools.value.any((t) => t.kind == k);

  void putToolsAway() {
    for (final t in board.geoTools.value.toList()) {
      board.removeGeoTool(t.id);
    }
    setState(() {});
  }

  Offset get _middle => board.visibleArea?.center ?? const Offset(1200, 675);

  void insertLive(String kind, String id, {String? preset}) {
    board.add(liveObject(kind, id, _middle, preset: preset));
    board.tool = BoardTool.pen;
  }

  Future<void> insertPicture() async {
    final f = await _pick(FileType.image);
    if (f == null) return;
    final e = await pictureElement(f, _middle);
    if (e == null) return _say('That file is not a picture this board can open.', 'ಈ ಫೈಲ್ ಈ ಬೋರ್ಡ್ ತೆರೆಯಬಹುದಾದ ಚಿತ್ರವಲ್ಲ.');
    board.add(e);
  }

  Future<Uint8List?> _pick(FileType type, [List<String>? ext]) async {
    try {
      final r = await FilePicker.platform.pickFiles(type: type, allowedExtensions: ext, withData: true);
      return r?.files.single.bytes;
    } catch (_) {
      _say('Could not open the files on this board.', 'ಈ ಬೋರ್ಡ್‌ನ ಫೈಲ್‌ಗಳನ್ನು ತೆರೆಯಲಾಗಲಿಲ್ಲ.');
      return null;
    }
  }

  Future<void> insertPowerPoint() async {
    final bytes = await _pick(FileType.custom, const ['pptx']);
    if (bytes == null) return;
    await importSlides(bytes);
  }

  /// Puts a .pptx on the board: each slide becomes a page after this one.
  Future<int> importSlides(Uint8List bytes) async {
    final PptxImport deck;
    try {
      deck = await importPptx(bytes);
    } on FormatException {
      _say('That is not a PowerPoint (.pptx) file. Save old .ppt files as .pptx first.', 'ಇದು ಪವರ್‌ಪಾಯಿಂಟ್ (.pptx) ಫೈಲ್ ಅಲ್ಲ. ಹಳೆಯ .ppt ಅನ್ನು ಮೊದಲು .pptx ಆಗಿ ಉಳಿಸಿ.');
      return 0;
    }
    if (deck.pages.isEmpty) return 0;
    final first = board.page.elements.isEmpty ? board.pageIndex : board.pageIndex + 1;
    board.addPages([for (final p in deck.pages) p.elements]);
    final pages = board.pages;
    for (var i = 0; i < deck.pages.length && first + i < pages.length; i++) {
      pages[first + i].background = deck.pages[i].background;
    }
    board.fitContent();
    _say('${deck.pages.length} slides are now pages.', '${deck.pages.length} ಸ್ಲೈಡ್‌ಗಳು ಈಗ ಪುಟಗಳಾಗಿವೆ.');
    setState(() {});
    return deck.pages.length;
  }

  Future<void> insertModel() async {
    final id = await pick3dModel(context, l);
    if (id != null) insertLive(LiveKind.model3d, id);
  }

  Future<void> insertLab() async {
    final id = await pickLab(context, l);
    if (id != null) insertLive(LiveKind.lab, id);
  }

  Future<void> insertSim() async {
    final sims = kit.where((k) => k.kind == KitKind.sim).toList();
    final i = await pickKitItem(context, l, tr(l, 'Choose a simulation', 'ಸಿಮ್ಯುಲೇಶನ್ ಆಯ್ಕೆಮಾಡಿ'), sims);
    if (i != null) putOnBoard(i);
  }

  Future<void> insertGraph() async {
    final g = newGraph(_middle);
    board.add(g);
    if (mounted) await editGraph(context, board, g);
  }

  /// Typeset maths in the middle of the view.
  void insertMath(String tex) {
    if (tex.trim().isEmpty) return;
    board.add(MathElement(id: newElementId(), position: _middle - const Offset(200, 40), latex: tex.trim(), color: board.penColor, fontSize: 56, size: const Size(400, 80)));
  }

  void insertNumberLine() => board.addAll(numberLine(_middle), group: true);

  void blankPage([BoardBackground bg = BoardBackground.plain]) {
    if (board.page.elements.isNotEmpty) board.addPage();
    board.background = bg;
    setState(() {});
  }

  Future<void> insertTemplate() async {
    final bg = await pickTemplate(context, l);
    if (bg != null) blankPage(bg);
  }

  Future<void> openInsert() async {
    final k = await showInsertMenu(context, l, help: _help, kinetix: Apps.isInstalled(Apps.kinetixBoard));
    switch (k) {
      case InsertKind.picture:
        await insertPicture();
      case InsertKind.powerpoint:
        await insertPowerPoint();
      case InsertKind.model3d:
        await insertModel();
      case InsertKind.lab:
        await insertLab();
      case InsertKind.simulation:
        await insertSim();
      case InsertKind.graph:
        await insertGraph();
      case InsertKind.blank:
        blankPage();
      case InsertKind.template:
        await insertTemplate();
      case null:
    }
  }

  /// "Put on board" from the subject kit.
  void putOnBoard(KitItem i) {
    switch (i.kind) {
      case KitKind.model3d:
        insertLive(LiveKind.model3d, i.ref);
      case KitKind.lab:
        insertLive(LiveKind.lab, i.ref, preset: i.block?.s('preset'));
      case KitKind.sim:
        insertLive(LiveKind.sim, i.ref);
      case KitKind.explainer:
        final s = pack == null ? null : explainerStep(pack!, i);
        if (s == null) return;
        if (board.page.elements.isNotEmpty) board.addPage();
        board.addAll(stepPage(s, s.index + 1, pack, l));
      case KitKind.exam:
        if (board.page.elements.isNotEmpty) board.addPage();
        board.addAll(examPage(i.questions));
      case KitKind.video:
        _say('Concept videos need the internet. They are not on this board offline.', 'ಪರಿಕಲ್ಪನಾ ವೀಡಿಯೊಗಳಿಗೆ ಇಂಟರ್ನೆಟ್ ಬೇಕು. ಇವು ಆಫ್‌ಲೈನ್‌ನಲ್ಲಿ ಇಲ್ಲ.');
        return;
    }
    setState(() {});
  }

  /// A page of exam questions, each answer covered until the teacher taps it.
  List<BoardElement> examPage(List<Question> qs) {
    final els = <BoardElement>[];
    var y = 60.0;
    final (h, hy) = boardText(tr(l, 'Board-exam questions', 'ಬೋರ್ಡ್ ಪರೀಕ್ಷಾ ಪ್ರಶ್ನೆಗಳು'), Offset(100, y), size: 64, color: S.ink, bold: true);
    els.addAll(h);
    y = hy + 24;
    for (final (n, q) in qs.indexed) {
      final (t, ty) = boardText('${n + 1}. ${plain(q.stem.t(l))}', Offset(100, y), size: 36, width: 1400);
      els.addAll(t);
      els.add(NoteElement(id: newElementId(), rect: Rect.fromLTWH(1560, y, 620, 90), text: answerOf(q, l), color: const Color(0xFFDDF3E7), fontSize: 30, kind: NoteKind.answer));
      y = ty + 30;
    }
    return els;
  }

  bool belongs(KitItem i) => board.elements.any((e) => e is ImageElement && e.link != null && e.link!.id == i.ref && LiveKind.all.contains(e.link!.kind));

  // Lesson steps as pages.

  /// Opens step [i] of the lesson as a board page (made once, then reopened with the writing).
  void showStep(int i) {
    if (i < 0 || i >= steps.length) return;
    final s = steps[i];
    final at = _open!.pageForStep(s.block.id);
    if (at != null) {
      board.goToPage(at);
    } else {
      if (board.page.elements.isNotEmpty || _open!.stepPages.containsKey(board.page.id)) {
        board.goToPage(board.pageCount - 1);
        board.addPage(force: true);
      }
      _open!.stepPages[board.page.id] = s.block.id;
      board.addAll(stepPage(s, i + 1, pack, l));
      board.fitContent();
    }
    setState(() {
      stepAt = i;
      answerShown = false;
    });
    widget.onStep?.call(s.index);
  }

  void openRecap() {
    final lesson = widget.lesson;
    if (lesson == null) return;
    const id = '#recap';
    final at = _open!.pageForStep(id);
    if (at != null) {
      board.goToPage(at);
    } else {
      board.goToPage(board.pageCount - 1);
      if (board.page.elements.isNotEmpty || _open!.stepPages.containsKey(board.page.id)) board.addPage(force: true);
      _open!.stepPages[board.page.id] = id;
      board.addAll(recapPage(lesson, steps, l));
    }
    setState(() {});
  }

  // Top bar tools.

  Future<void> toggleRecord() async {
    if (recorder?.recording ?? false) {
      final r = await recorder!.stop();
      setState(() => recorder = null);
      if (r != null) {
        _say(
          'Recording saved (${mmss(Duration(milliseconds: r.durationMs))}). Open Record to play it.',
          'ರೆಕಾರ್ಡಿಂಗ್ ಉಳಿಸಲಾಗಿದೆ (${mmss(Duration(milliseconds: r.durationMs))}). ಪ್ಲೇ ಮಾಡಲು ರೆಕಾರ್ಡ್ ತೆರೆಯಿರಿ.',
        );
      }
      return;
    }
    final go = await _recordSheet();
    if (go != true || !mounted) return;
    final title = '${pack?.chapter.title.t(l) ?? tr(l, 'Board', 'ಬೋರ್ಡ್')} · ${_services.config.sectionLabel}';
    final r = BoardRecorder(board, title: title)..addListener(() => mounted ? setState(() {}) : null);
    setState(() => recorder = r);
    await r.start();
  }

  Future<bool?> _recordSheet() async {
    final list = await RecordingStore.instance.list();
    if (!mounted) return null;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(56)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500, maxHeight: 1400),
          child: Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(l, 'Record this lesson', 'ಈ ಪಾಠವನ್ನು ರೆಕಾರ್ಡ್ ಮಾಡಿ'), style: hd(64, l: l)),
                const SizedBox(height: 12),
                Text(
                  tr(
                    l,
                    'The board and your voice are recorded. No camera, and no student is recorded. It stays on this board.',
                    'ಬೋರ್ಡ್ ಮತ್ತು ನಿಮ್ಮ ಧ್ವನಿ ರೆಕಾರ್ಡ್ ಆಗುತ್ತದೆ. ಕ್ಯಾಮೆರಾ ಇಲ್ಲ, ಯಾವ ವಿದ್ಯಾರ್ಥಿಯೂ ರೆಕಾರ್ಡ್ ಆಗುವುದಿಲ್ಲ. ಇದು ಈ ಬೋರ್ಡ್‌ನಲ್ಲೇ ಇರುತ್ತದೆ.',
                  ),
                  style: tx(34),
                ),
                const SizedBox(height: 32),
                Tap(
                  key: const ValueKey('startRecording'),
                  onTap: () => Navigator.pop(ctx, true),
                  child: BigButton(tr(l, 'Start recording', 'ರೆಕಾರ್ಡಿಂಗ್ ಪ್ರಾರಂಭಿಸಿ'), icon: Icons.fiber_manual_record_rounded, bg: wbRed, height: 130, size: 38),
                ),
                if (list.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  Text(
                    tr(l, 'Recorded lessons', 'ರೆಕಾರ್ಡ್ ಮಾಡಿದ ಪಾಠಗಳು'),
                    style: tx(30, c: S.eyebrow, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final r in list.take(20))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${r.title} · ${r.at.day}/${r.at.month} · ${mmss(Duration(milliseconds: r.durationMs))}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tx(32, c: S.ink, w: FontWeight.w600),
                                  ),
                                ),
                                Tap(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => RecordingPlayer(recording: r, lang: l),
                                      ),
                                    );
                                  },
                                  child: WbTag(tr(l, 'Play', 'ಪ್ಲೇ'), icon: Icons.play_arrow_rounded, bg: S.soft, size: 30),
                                ),
                                const SizedBox(width: 12),
                                Tap(
                                  onTap: () async {
                                    await RecordingStore.instance.delete(r);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                                  child: WbTag(tr(l, 'Delete', 'ಅಳಿಸಿ'), icon: Icons.delete_outline_rounded, bg: S.peach, fg: S.rust, size: 30),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> readAloud() async {
    if (reading) {
      await _services.narrator.stop();
      if (mounted) setState(() => reading = false);
      return;
    }
    var text = pageText(board.elements);
    if (text.isEmpty) {
      return _say('There are no typed words on this page to read.', 'ಈ ಪುಟದಲ್ಲಿ ಓದಲು ಟೈಪ್ ಮಾಡಿದ ಪದಗಳಿಲ್ಲ.');
    }
    if (stepAt != null) {
      final say = steps[stepAt!].block.narration;
      if (say != null) text = plain(say.t(l));
    }
    setState(() => reading = true);
    try {
      await _services.narrator.speak(text, l);
    } catch (_) {}
    if (mounted) setState(() => reading = false);
  }

  void _remoteAction(String a) {
    if (!mounted) return;
    switch (a) {
      case 'prev':
        board.previous();
      case 'next':
        if (board.hasNext) {
          board.next();
        } else if (stepAt != null && stepAt! < steps.length - 1) {
          showStep(stepAt! + 1);
        }
      case 'page':
        addPage();
      case 'undo':
        if (board.canUndo) board.undo();
      case 'blank':
        blank = !blank;
      case 'read':
        unawaited(readAloud());
    }
    setState(() {});
  }

  Future<void> phoneRemote() async {
    final r = remote ??= RemoteServer(
      onAction: _remoteAction,
      state: () => {'page': board.pageIndex + 1, 'pages': board.pageCount, 'title': pack?.chapter.title.t(l) ?? 'Zynetix Board', 'blank': blank},
    );
    String? url = r.url;
    if (!r.running) {
      try {
        url = await r.start(lang: l);
      } catch (_) {
        url = null;
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(56)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(l, 'Your phone as a remote', 'ನಿಮ್ಮ ಫೋನ್ ರಿಮೋಟ್ ಆಗಿ'), style: hd(64, l: l)),
                const SizedBox(height: 16),
                if (url == null)
                  Text(tr(l, 'This board is not on a Wi-Fi network. Join the school Wi-Fi, then try again.', 'ಈ ಬೋರ್ಡ್ Wi-Fi ನಲ್ಲಿ ಇಲ್ಲ. ಶಾಲೆಯ Wi-Fi ಸೇರಿ, ನಂತರ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.'), style: tx(36))
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: S.line, width: 3),
                        ),
                        child: QrImageView(data: url, size: 420),
                      ),
                      const SizedBox(width: 48),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HelpStep(1, tr(l, 'Join your phone to the same Wi-Fi as this board.', 'ನಿಮ್ಮ ಫೋನನ್ನು ಈ ಬೋರ್ಡ್‌ನ ಅದೇ Wi-Fi ಗೆ ಸೇರಿಸಿ.'), size: 34),
                            HelpStep(2, tr(l, 'Point the phone camera at the code and open the link.', 'ಫೋನ್ ಕ್ಯಾಮೆರಾವನ್ನು ಕೋಡ್ ಕಡೆ ಹಿಡಿದು ಲಿಂಕ್ ತೆರೆಯಿರಿ.'), size: 34),
                            HelpStep(3, tr(l, 'Use Next, Back, New page and Undo from anywhere in the room.', 'ಕೊಠಡಿಯ ಎಲ್ಲಿಂದಲಾದರೂ ಮುಂದೆ, ಹಿಂದೆ, ಹೊಸ ಪುಟ, ರದ್ದುಮಾಡು ಬಳಸಿ.'), size: 34),
                            const SizedBox(height: 8),
                            SelectableText(
                              url,
                              style: tx(30, c: S.violet, w: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 30),
                SafeLine(tr(l, 'No internet and no app needed: the board and the phone talk over the Wi-Fi.', 'ಇಂಟರ್ನೆಟ್ ಅಥವಾ ಆ್ಯಪ್ ಬೇಡ: ಬೋರ್ಡ್ ಮತ್ತು ಫೋನ್ Wi-Fi ಮೂಲಕ ಮಾತನಾಡುತ್ತವೆ.'), size: 30),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (url != null)
                      Tap(
                        key: const ValueKey('stopRemote'),
                        onTap: () async {
                          await remote?.stop();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: BigButton(tr(l, 'Stop the remote', 'ರಿಮೋಟ್ ನಿಲ್ಲಿಸಿ'), bg: Colors.white, fg: S.ink, border: S.line, height: 120, size: 34),
                      ),
                    const SizedBox(width: 20),
                    Tap(
                      onTap: () => Navigator.pop(ctx),
                      child: BigButton(tr(l, 'Done', 'ಆಯಿತು'), icon: Icons.check_rounded, bg: S.violet, height: 120, size: 34),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> projector() async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (_, _, _) => _ProjectorView(state: this),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
    if (mounted) setState(() {});
  }

  void _help() {
    final geoOut = board.geoTools.value.isNotEmpty;
    final (title, list) = switch (true) {
      _ when geoOut && geoOn(GeoKind.protractor) => (
        tr(l, 'How to measure an angle', 'ಕೋನವನ್ನು ಅಳೆಯುವುದು ಹೇಗೆ'),
        [
          tr(l, 'Drag the protractor. Put its centre dot on the corner.', 'ಕೋನಮಾಪಕವನ್ನು ಎಳೆಯಿರಿ. ಅದರ ಮಧ್ಯದ ಚುಕ್ಕೆಯನ್ನು ಮೂಲೆಯ ಮೇಲೆ ಇಡಿ.'),
          tr(l, 'Turn it with the round handle so 0 lies along one line.', 'ವೃತ್ತಾಕಾರದ ಹಿಡಿಕೆಯಿಂದ ತಿರುಗಿಸಿ, 0 ಒಂದು ಗೆರೆಯ ಮೇಲೆ ಬರಲಿ.'),
          tr(l, 'Read where the other line crosses the numbers.', 'ಇನ್ನೊಂದು ಗೆರೆ ಸಂಖ್ಯೆಗಳನ್ನು ದಾಟುವಲ್ಲಿ ಓದಿ.'),
        ],
      ),
      _ when geoOut => (
        tr(l, 'Measuring tools', 'ಅಳತೆ ಸಾಧನಗಳು'),
        [
          tr(l, 'Drag a tool to move it. Turn it with its round handle.', 'ಸಾಧನವನ್ನು ಸರಿಸಲು ಎಳೆಯಿರಿ. ವೃತ್ತಾಕಾರದ ಹಿಡಿಕೆಯಿಂದ ತಿರುಗಿಸಿ.'),
          tr(l, 'Draw with the pen along the ruler’s edge: the line comes out straight.', 'ಅಳತೆಪಟ್ಟಿಯ ಅಂಚಿನಲ್ಲಿ ಪೆನ್‌ನಿಂದ ಬರೆಯಿರಿ: ಗೆರೆ ನೇರವಾಗಿ ಬರುತ್ತದೆ.'),
          tr(l, 'Tap “Put the tools away” when you are done.', 'ಮುಗಿದಾಗ “ಸಾಧನಗಳನ್ನು ಇಡಿ” ಒತ್ತಿ.'),
        ],
      ),
      _ when stepAt != null => (
        tr(l, 'Teaching from the lesson', 'ಪಾಠದಿಂದ ಬೋಧನೆ'),
        [
          tr(l, 'This page is the lesson step. Write on it with the pen.', 'ಈ ಪುಟವೇ ಪಾಠದ ಹಂತ. ಪೆನ್‌ನಿಂದ ಇದರ ಮೇಲೆ ಬರೆಯಿರಿ.'),
          tr(l, 'Ask the class the quick check. Tap to show the answer.', 'ತರಗತಿಗೆ ತ್ವರಿತ ಪ್ರಶ್ನೆ ಕೇಳಿ. ಉತ್ತರ ತೋರಿಸಲು ಒತ್ತಿ.'),
          tr(l, 'Tap “Next step” to go on. Your writing stays on each page.', 'ಮುಂದುವರಿಯಲು “ಮುಂದಿನ ಹಂತ” ಒತ್ತಿ. ನಿಮ್ಮ ಬರಹ ಪ್ರತಿ ಪುಟದಲ್ಲೂ ಉಳಿಯುತ್ತದೆ.'),
        ],
      ),
      _ => (
        tr(l, 'Writing on the board', 'ಬೋರ್ಡ್ ಮೇಲೆ ಬರೆಯುವುದು'),
        [
          tr(l, 'Pick Pen, Blue or Red and write with your finger or the pen.', 'ಪೆನ್, ನೀಲಿ ಅಥವಾ ಕೆಂಪು ಆಯ್ಕೆಮಾಡಿ, ಬೆರಳು ಅಥವಾ ಪೆನ್‌ನಿಂದ ಬರೆಯಿರಿ.'),
          tr(l, 'Made a mistake? Tap Undo, or rub it out with the Eraser.', 'ತಪ್ಪಾಯಿತೇ? ರದ್ದುಮಾಡು ಒತ್ತಿ, ಅಥವಾ ರಬ್ಬರ್‌ನಿಂದ ಅಳಿಸಿ.'),
          tr(l, 'Need more room? Add a page. Your pages are kept for this class.', 'ಹೆಚ್ಚು ಜಾಗ ಬೇಕೇ? ಪುಟ ಸೇರಿಸಿ. ನಿಮ್ಮ ಪುಟಗಳು ಈ ತರಗತಿಗಾಗಿ ಉಳಿಯುತ್ತವೆ.'),
          tr(l, 'Want a ruler, shapes or pictures? Switch on “Show all tools”.', 'ಅಳತೆಪಟ್ಟಿ, ಆಕಾರಗಳು ಅಥವಾ ಚಿತ್ರಗಳು ಬೇಕೇ? “ಎಲ್ಲಾ ಸಾಧನಗಳನ್ನು ತೋರಿಸಿ” ಆನ್ ಮಾಡಿ.'),
        ],
      ),
    };
    unawaited(showBoardHelp(context, l, title, list, readAloud: () => unawaited(_services.narrator.speak('$title. ${list.join(' ')}', l))));
  }

  Future<String?> _editMath(String? latex) => showDialog<String>(
    context: context,
    builder: (ctx) {
      final t = TextEditingController(text: latex ?? '');
      return AlertDialog(
        title: Text(tr(l, 'Maths', 'ಗಣಿತ'), style: hd(48, l: l)),
        content: SizedBox(
          width: 900,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: t,
                autofocus: true,
                style: tx(34, c: S.ink),
                decoration: const InputDecoration(hintText: r'\frac{a}{b}'),
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: t,
                builder: (_, _) => Math.tex(t.text, textStyle: const TextStyle(fontSize: 48), onErrorFallback: (_) => const SizedBox.shrink()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(l, 'Cancel', 'ರದ್ದು'), style: tx(30, c: S.ink)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, t.text),
            child: Text(tr(l, 'Done', 'ಆಯಿತು'), style: tx(30, c: Colors.white)),
          ),
        ],
      );
    },
  );

  // ───────────────────────────── layout ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final o = _open;
    return PopScope(
      onPopInvokedWithResult: (_, _) {
        if (o != null && widget.controller == null) unawaited(store.save(o));
      },
      child: Scaffold(
        backgroundColor: S.mist,
        body: o == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: ListenableBuilder(
                  listenable: Listenable.merge([o.controller, o.controller.geoTools, _services.config]),
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, box) {
                      final wide = box.maxWidth >= 2000 && box.maxWidth > box.maxHeight * 1.15;
                      if (!wide) return _narrow(box);
                      if (stepAt != null) return _lessonLayout();
                      if (kitOpen) return _kitLayout();
                      if (allTools) return _allLayout();
                      if (board.geoTools.value.isNotEmpty) return _geoLayout();
                      return _simpleLayout();
                    },
                  ),
                ),
              ),
      ),
    );
  }

  /// The board itself.
  Widget canvas({bool chrome = true}) => BoardSheet(
    child: Stack(
      children: [
        Positioned.fill(
          // kinetix_ink's small tool buttons (on the ruler and protractor) keep their own size.
          child: Theme(
            data: Theme.of(context).copyWith(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: WhiteboardCanvas(
              key: const ValueKey('smartboardCanvas'),
              controller: board,
              editMath: _editMath,
              labels: WhiteboardCanvasLabels(
                typeHint: tr(l, 'Type…', 'ಟೈಪ್ ಮಾಡಿ…'),
                hideRuler: tr(l, 'Put the ruler away', 'ಅಳತೆಪಟ್ಟಿ ಇಡಿ'),
                hideProtractor: tr(l, 'Put the protractor away', 'ಕೋನಮಾಪಕ ಇಡಿ'),
                turn: tr(l, 'Turn', 'ತಿರುಗಿಸಿ'),
              ),
              liveOverlay: (ctx, view) => LiveObjectsLayer(board: board, view: view, lang: l),
            ),
          ),
        ),
        if (chrome && penMenu && allTools)
          Positioned(
            left: 30,
            top: 30,
            child: PenChooser(board: board, lang: l, onDone: () => setState(() => penMenu = false)),
          ),
        if (chrome && geoHelp && geoOn(GeoKind.protractor)) Positioned(right: 30, top: 30, width: 760, child: _angleHelp()),
        if (recorder?.recording ?? false)
          Positioned(
            left: 30,
            bottom: 30,
            child: IgnorePointer(
              child: WbTag('● ${tr(l, 'Recording', 'ರೆಕಾರ್ಡ್ ಆಗುತ್ತಿದೆ')} ${mmss(recorder!.elapsed)}', bg: wbRed, fg: Colors.white, size: 30),
            ),
          ),
      ],
    ),
  );

  Widget _angleHelp() => Container(
    padding: const EdgeInsets.fromLTRB(40, 34, 30, 20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), boxShadow: S.shadowSoft),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(tr(l, 'How to measure an angle', 'ಕೋನವನ್ನು ಅಳೆಯುವುದು ಹೇಗೆ'), style: hd(44, l: l)),
            ),
            Tap(
              key: const ValueKey('hideAngleHelp'),
              onTap: () => setState(() => geoHelp = false),
              child: const Icon(Icons.close_rounded, size: 48, color: S.muted),
            ),
          ],
        ),
        const SizedBox(height: 20),
        HelpStep(1, tr(l, 'Drag the protractor. Put its centre dot on the corner.', 'ಕೋನಮಾಪಕವನ್ನು ಎಳೆಯಿರಿ. ಅದರ ಮಧ್ಯದ ಚುಕ್ಕೆಯನ್ನು ಮೂಲೆಯ ಮೇಲೆ ಇಡಿ.'), size: 28),
        HelpStep(2, tr(l, 'Turn it so 0 lies along one line.', '0 ಒಂದು ಗೆರೆಯ ಮೇಲೆ ಬರುವಂತೆ ತಿರುಗಿಸಿ.'), size: 28),
        HelpStep(3, tr(l, 'Read where the other line crosses the numbers.', 'ಇನ್ನೊಂದು ಗೆರೆ ಸಂಖ್ಯೆಗಳನ್ನು ದಾಟುವಲ್ಲಿ ಓದಿ.'), size: 28),
      ],
    ),
  );

  String _subject(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String get _title => pack?.chapter.title.t(l) ?? tr(l, 'Smartboard', 'ಸ್ಮಾರ್ಟ್‌ಬೋರ್ಡ್');

  Widget back({double h = 130, double size = 40}) => Tap(
    key: const ValueKey('closeSmartboard'),
    onTap: () => Navigator.maybePop(context),
    child: BigButton(widget.lesson != null ? tr(l, 'Back to the lesson', 'ಪಾಠಕ್ಕೆ ಹಿಂತಿರುಗಿ') : tr(l, 'Close the board', 'ಬೋರ್ಡ್ ಮುಚ್ಚಿ'), icon: Icons.arrow_back_rounded, height: h, size: size),
  );

  Widget help({double size = 36}) => Tap(
    key: const ValueKey('boardHelp'),
    onTap: _help,
    child: HelpButton(lang: l, size: size),
  );

  Widget undoPill({double h = 130, double size = 38}) => Tap(
    key: const ValueKey('undoTop'),
    onTap: board.canUndo ? board.undo : null,
    child: Pill(tr(l, 'Undo', 'ರದ್ದುಮಾಡು'), Icons.undo_rounded, h: h, size: size),
  );

  /// Where the board is (chapter · page), as a white pill that shortens with an ellipsis.
  Widget crumb(IconData icon, String text) => Expanded(
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: S.ink),
            const SizedBox(width: 11),
            Flexible(
              child: Text(
                text,
                key: const ValueKey('boardCrumb'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tx(32, c: S.ink, w: FontWeight.w500, h: 1.2),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String get pageCrumb => tr(l, '$_title · Board · page ${board.pageIndex + 1} of ${board.pageCount}', '$_title · ಬೋರ್ಡ್ · ಪುಟ ${board.pageIndex + 1} / ${board.pageCount}');

  /// Pen, Blue, Red, Highlight | Eraser, Undo, (Clear).
  Widget simpleTools({double w = 200, double h = 176, bool clear = true, bool insert = false}) {
    final t = board.tool;
    Widget colour(Color c, String name, String key) {
      final on = t == BoardTool.pen && board.penColor.toARGB32() == c.toARGB32();
      return Tap(
        key: ValueKey(key),
        label: name,
        onTap: () => pen(c),
        child: ToolButton(name, Icons.circle, dot: c, bg: on ? S.soft : Colors.white, fg: S.ink, width: w, height: h, on: on),
      );
    }

    return Container(
      key: const ValueKey('smartboardToolbar'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(60), boxShadow: S.shadow),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          colour(wbInk, tr(l, 'Pen', 'ಪೆನ್'), 'tool-pen'),
          const SizedBox(width: 10),
          colour(wbBlue, tr(l, 'Blue', 'ನೀಲಿ'), 'tool-blue'),
          const SizedBox(width: 10),
          colour(wbRed, tr(l, 'Red', 'ಕೆಂಪು'), 'tool-red'),
          const SizedBox(width: 10),
          Tap(
            key: const ValueKey('tool-highlighter'),
            onTap: highlight,
            child: ToolButton(
              tr(l, 'Highlight', 'ಹೈಲೈಟ್'),
              Icons.border_color_rounded,
              bg: t == BoardTool.highlighter ? S.soft : Colors.white,
              fg: S.ink,
              width: w,
              height: h,
              on: t == BoardTool.highlighter,
            ),
          ),
          Container(width: 3, height: h * .7, color: S.line, margin: const EdgeInsets.symmetric(horizontal: 14)),
          Tap(
            key: const ValueKey('tool-eraser'),
            onTap: () => eraser(EraserMode.stroke),
            child: ToolButton(tr(l, 'Eraser', 'ರಬ್ಬರ್'), Icons.auto_fix_normal_rounded, bg: t == BoardTool.eraser ? S.soft : Colors.white, fg: S.ink, width: w, height: h, on: t == BoardTool.eraser),
          ),
          const SizedBox(width: 10),
          Tap(
            key: const ValueKey('undo'),
            onTap: board.canUndo ? board.undo : null,
            child: ToolButton(tr(l, 'Undo', 'ರದ್ದುಮಾಡು'), Icons.undo_rounded, bg: Colors.white, fg: S.ink, width: w, height: h),
          ),
          if (insert) ...[
            const SizedBox(width: 10),
            Tap(
              key: const ValueKey('insert'),
              onTap: openInsert,
              child: ToolButton(tr(l, 'Insert', 'ಸೇರಿಸಿ'), Icons.add_photo_alternate_outlined, bg: Colors.white, fg: S.ink, width: w, height: h),
            ),
          ],
          if (clear) ...[
            const SizedBox(width: 10),
            Tap(
              key: const ValueKey('clearPage'),
              onTap: board.canClearPage ? clearPage : null,
              child: ToolButton(tr(l, 'Clear', 'ಅಳಿಸಿ'), Icons.delete_outline_rounded, bg: S.peach, fg: S.rust, width: w, height: h),
            ),
          ],
        ],
      ),
    );
  }

  Widget showAll({double sw = 132, bool sub = true}) => Tap(
    key: const ValueKey('showAllTools'),
    onTap: () => setAllTools(!allTools),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BigSwitch(on: allTools, w: sw),
        const SizedBox(width: 26),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                allTools ? tr(l, 'Show all tools · On', 'ಎಲ್ಲಾ ಸಾಧನಗಳು · ಆನ್') : tr(l, 'Show all tools', 'ಎಲ್ಲಾ ಸಾಧನಗಳನ್ನು ತೋರಿಸಿ'),
                style: tx(38, c: S.ink, w: FontWeight.w700, h: 1.15),
              ),
              if (sub)
                Text(
                  allTools ? tr(l, 'Switch off for the simple board', 'ಸರಳ ಬೋರ್ಡ್‌ಗೆ ಆಫ್ ಮಾಡಿ') : tr(l, 'Ruler, shapes, graph, pictures and more', 'ಅಳತೆಪಟ್ಟಿ, ಆಕಾರಗಳು, ಗ್ರಾಫ್, ಚಿತ್ರಗಳು'),
                  style: tx(30, c: S.muted, h: 1.3),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget pages({bool vertical = true, double thumbW = 250}) =>
      PagesPanel(key: const ValueKey('pagesPanel'), board: board, lang: l, vertical: vertical, thumbW: thumbW, onAdd: addPage, onAction: pageAction);

  // 01 · simple.
  Widget _simpleLayout() => Padding(
    padding: const EdgeInsets.fromLTRB(140, 50, 140, 50),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [back(), const SizedBox(width: 28), crumb(Icons.description_outlined, pageCrumb), const SizedBox(width: 28), help()]),
        const SizedBox(height: 36),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: canvas()),
              const SizedBox(width: 44),
              Align(alignment: Alignment.topCenter, child: pages()),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    simpleTools(),
                    const SizedBox(width: 30),
                    Tap(key: const ValueKey('insert'), onTap: openInsert, child: Pill(tr(l, 'Insert', 'ಸೇರಿಸಿ'), Icons.add_photo_alternate_outlined, h: 120, size: 34)),
                    if (pack != null) ...[
                      const SizedBox(width: 20),
                      Tap(key: const ValueKey('openKit'), onTap: () => setState(() => kitOpen = true), child: Pill(tr(l, 'Subject kit', 'ವಿಷಯ ಕಿಟ್'), Icons.inventory_2_outlined, h: 120, size: 34)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 30),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: showAll()),
          ],
        ),
      ],
    ),
  );

  // 03 · measuring tools out.
  Widget _geoLayout() => Padding(
    padding: const EdgeInsets.fromLTRB(140, 50, 140, 50),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            back(),
            const SizedBox(width: 28),
            crumb(Icons.architecture_rounded, tr(l, 'Measuring · page ${board.pageIndex + 1}', 'ಅಳತೆ · ಪುಟ ${board.pageIndex + 1}')),
            const SizedBox(width: 28),
            undoPill(),
            const SizedBox(width: 20),
            help(),
          ],
        ),
        const SizedBox(height: 36),
        Expanded(child: canvas()),
        const SizedBox(height: 36),
        Row(
          children: [
            Expanded(
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _geoTools()),
            ),
            const SizedBox(width: 30),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Tap(
                  key: const ValueKey('putToolsAway'),
                  onTap: putToolsAway,
                  child: BigButton(tr(l, 'Put the tools away', 'ಸಾಧನಗಳನ್ನು ಇಡಿ'), icon: Icons.check_rounded, bg: S.violet, height: 176, size: 46),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _geoTools({double w = 200, double h = 176}) {
    Widget g(GeoKind k, IconData icon, String en, String kn) => Tap(
      key: ValueKey('geo-${k.name}'),
      onTap: () => geo(k),
      child: ToolButton(tr(l, en, kn), icon, bg: geoOn(k) ? S.mint : Colors.white, fg: S.ink, width: w, height: h, on: geoOn(k)),
    );
    final t = board.tool;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(60), boxShadow: S.shadow),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          g(GeoKind.ruler, Icons.straighten_rounded, 'Ruler', 'ಅಳತೆಪಟ್ಟಿ'),
          const SizedBox(width: 10),
          g(GeoKind.protractor, Icons.architecture_rounded, 'Protractor', 'ಕೋನಮಾಪಕ'),
          const SizedBox(width: 10),
          g(GeoKind.compass, Icons.explore_outlined, 'Compass', 'ಕೈವಾರ'),
          const SizedBox(width: 10),
          g(GeoKind.setSquare45, Icons.change_history_rounded, 'Set square', 'ಮೂಲೆಮಟ್ಟ'),
          Container(width: 3, height: h * .7, color: S.line, margin: const EdgeInsets.symmetric(horizontal: 14)),
          Tap(
            key: const ValueKey('tool-pen'),
            onTap: () => pen(board.penColor),
            child: ToolButton(tr(l, 'Pen', 'ಪೆನ್'), Icons.circle, dot: board.penColor, bg: t == BoardTool.pen ? S.soft : Colors.white, fg: S.ink, width: w, height: h, on: t == BoardTool.pen),
          ),
          const SizedBox(width: 10),
          Tap(
            key: const ValueKey('tool-eraser'),
            onTap: () => eraser(EraserMode.stroke),
            child: ToolButton(tr(l, 'Eraser', 'ರಬ್ಬರ್'), Icons.auto_fix_normal_rounded, bg: t == BoardTool.eraser ? S.soft : Colors.white, fg: S.ink, width: w, height: h, on: t == BoardTool.eraser),
          ),
        ],
      ),
    );
  }

  // 02 · all tools.
  Widget _topTools({double h = 104, double size = 30}) {
    final rec = recorder?.recording ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tap(
          key: const ValueKey('record'),
          onTap: toggleRecord,
          child: Pill(rec ? tr(l, 'Stop · ${mmss(recorder!.elapsed)}', 'ನಿಲ್ಲಿಸಿ · ${mmss(recorder!.elapsed)}') : tr(l, 'Record', 'ರೆಕಾರ್ಡ್'), Icons.circle, dot: wbRed, h: h, size: size, on: rec),
        ),
        const SizedBox(width: 14),
        Tap(
          key: const ValueKey('projector'),
          onTap: projector,
          child: Pill(
            tr(l, 'Projector', 'ಪ್ರೊಜೆಕ್ಟರ್'),
            Icons.cast_rounded,
            trailing: BigSwitch(on: false, w: h * .8),
            h: h,
            size: size,
          ),
        ),
        const SizedBox(width: 14),
        Tap(
          key: const ValueKey('readAloud'),
          onTap: readAloud,
          child: Pill(reading ? tr(l, 'Stop reading', 'ಓದು ನಿಲ್ಲಿಸಿ') : tr(l, 'Read aloud', 'ಓದಿ ಹೇಳಿ'), Icons.volume_up_rounded, h: h, size: size, on: reading),
        ),
        const SizedBox(width: 14),
        Tap(
          key: const ValueKey('phoneRemote'),
          onTap: phoneRemote,
          child: Pill(tr(l, 'Phone as remote', 'ಫೋನ್ ರಿಮೋಟ್'), Icons.phone_iphone_rounded, h: h, size: size, on: remote?.running ?? false),
        ),
      ],
    );
  }

  Widget _allLayout() => Padding(
    padding: const EdgeInsets.fromLTRB(140, 44, 140, 44),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            back(h: 112, size: 34),
            const SizedBox(width: 20),
            Expanded(
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: _topTools()),
            ),
            const SizedBox(width: 14),
            help(size: 31),
          ],
        ),
        const SizedBox(height: 28),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 810, child: _toolPanel()),
              const SizedBox(width: 36),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: canvas()),
                    const SizedBox(height: 24),
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _strip()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// The grouped, labelled tools.
  Widget _toolPanel({bool scroll = false}) {
    final t = board.tool;
    Widget tool(String key, String label, IconData icon, VoidCallback? onTap, {bool on = false, VoidCallback? onLong}) => Tap(
      key: ValueKey(key),
      label: label,
      onTap: onTap,
      onLongPress: onLong,
      child: ToolButton(label, icon, bg: on ? Colors.white : Colors.transparent, fg: S.ink, width: 188, height: 128, on: on),
    );
    Widget group(String title, Color bg, List<Widget> tools) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              title,
              style: tx(28, c: S.eyebrow, w: FontWeight.w700, h: 1.1),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(36)),
            child: Wrap(spacing: 6, runSpacing: 6, children: tools),
          ),
        ],
      ),
    );
    final area = board.inputConfig.eraser.mode == EraserMode.area;
    final groups = SizedBox(
      width: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          group(tr(l, 'Write', 'ಬರೆಯಿರಿ'), S.lavender, [
            tool('all-pen', tr(l, 'Pen', 'ಪೆನ್'), Icons.edit_rounded, () {
              if (t == BoardTool.pen) {
                setState(() => penMenu = !penMenu);
              } else {
                pen(board.penColor);
                setState(() => penMenu = true);
              }
            }, on: t == BoardTool.pen),
            tool('all-highlighter', tr(l, 'Highlighter', 'ಹೈಲೈಟರ್'), Icons.border_color_rounded, () {
              highlight();
              setState(() => penMenu = t == BoardTool.highlighter ? !penMenu : true);
            }, on: t == BoardTool.highlighter),
            tool('all-text', tr(l, 'Text', 'ಪಠ್ಯ'), Icons.text_fields_rounded, () => board.tool = BoardTool.text, on: t == BoardTool.text),
          ]),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              group(tr(l, 'Draw', 'ಚಿತ್ರಿಸಿ'), S.peach, [
                _shapeMenu(t == BoardTool.shape && board.shapeKind.index > ShapeKind.doubleArrow.index, lines: false),
                _shapeMenu(t == BoardTool.shape && board.shapeKind.index <= ShapeKind.doubleArrow.index, lines: true),
              ]),
              const SizedBox(width: 18),
              group(tr(l, 'Fix', 'ಸರಿಪಡಿಸಿ'), S.pink, [
                tool('all-eraser', area ? tr(l, 'Eraser · part', 'ರಬ್ಬರ್ · ಭಾಗ') : tr(l, 'Eraser', 'ರಬ್ಬರ್'), Icons.auto_fix_normal_rounded, () {
                  // A second tap switches between rubbing out whole lines and only a part.
                  eraser(t == BoardTool.eraser ? (area ? EraserMode.stroke : EraserMode.area) : null);
                }, on: t == BoardTool.eraser),
                tool('all-undo', tr(l, 'Undo', 'ರದ್ದುಮಾಡು'), Icons.undo_rounded, board.canUndo ? board.undo : null),
              ]),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              group(tr(l, 'Move', 'ಸರಿಸಿ'), S.sky, [
                tool('all-select', tr(l, 'Select', 'ಆಯ್ಕೆ'), Icons.highlight_alt_rounded, () => board.tool = BoardTool.select, on: t == BoardTool.select),
                tool('all-hand', tr(l, 'Move board', 'ಬೋರ್ಡ್ ಸರಿಸಿ'), Icons.pan_tool_outlined, () => board.tool = BoardTool.hand, on: t == BoardTool.hand),
              ]),
              const SizedBox(width: 18),
              group(tr(l, 'Bring back', 'ಮರಳಿ ತನ್ನಿ'), S.pink, [tool('all-redo', tr(l, 'Redo', 'ಮತ್ತೆ ಮಾಡು'), Icons.redo_rounded, board.canRedo ? board.redo : null)]),
            ],
          ),
          group(tr(l, 'Measure', 'ಅಳತೆ'), S.mint, [
            tool('geo-ruler', tr(l, 'Ruler', 'ಅಳತೆಪಟ್ಟಿ'), Icons.straighten_rounded, () => geo(GeoKind.ruler), on: geoOn(GeoKind.ruler)),
            tool('geo-protractor', tr(l, 'Protractor', 'ಕೋನಮಾಪಕ'), Icons.architecture_rounded, () => geo(GeoKind.protractor), on: geoOn(GeoKind.protractor)),
            tool('geo-compass', tr(l, 'Compass', 'ಕೈವಾರ'), Icons.explore_outlined, () => geo(GeoKind.compass), on: geoOn(GeoKind.compass)),
            tool('geo-setSquare45', tr(l, 'Set square', 'ಮೂಲೆಮಟ್ಟ'), Icons.change_history_rounded, () => geo(GeoKind.setSquare45), on: geoOn(GeoKind.setSquare45)),
          ]),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              group(tr(l, 'Maths', 'ಗಣಿತ'), S.sky, [
                tool('all-graph', tr(l, 'Graph', 'ಗ್ರಾಫ್'), Icons.show_chart_rounded, insertGraph),
                tool('all-numberLine', tr(l, 'Number line', 'ಸಂಖ್ಯಾ ರೇಖೆ'), Icons.linear_scale_rounded, insertNumberLine),
              ]),
              const SizedBox(width: 18),
              group(tr(l, 'Page', 'ಪುಟ'), S.pink, [
                tool('all-addPage', tr(l, 'Add page', 'ಪುಟ ಸೇರಿಸಿ'), Icons.note_add_outlined, addPage),
                tool('all-clearPage', tr(l, 'Clear page', 'ಪುಟ ಅಳಿಸಿ'), Icons.delete_outline_rounded, board.canClearPage ? clearPage : null),
              ]),
            ],
          ),
          group(tr(l, 'Insert', 'ಸೇರಿಸಿ'), S.butter, [
            tool('all-picture', tr(l, 'Picture', 'ಚಿತ್ರ'), Icons.image_outlined, insertPicture),
            tool('all-powerpoint', tr(l, 'PowerPoint', 'ಪವರ್‌ಪಾಯಿಂಟ್'), Icons.slideshow_rounded, insertPowerPoint),
            tool('all-model3d', tr(l, '3D model', '3D ಮಾದರಿ'), Icons.view_in_ar_rounded, insertModel),
            tool('all-lab', tr(l, 'Lab', 'ಲ್ಯಾಬ್'), Icons.science_outlined, insertLab),
            tool('all-simulation', tr(l, 'Simulation', 'ಸಿಮ್ಯುಲೇಶನ್'), Icons.play_circle_outline_rounded, insertSim),
            tool('all-more', tr(l, 'More…', 'ಇನ್ನಷ್ಟು…'), Icons.add_rounded, openInsert),
            if (pack != null) tool('openKit', tr(l, 'Subject kit', 'ವಿಷಯ ಕಿಟ್'), Icons.inventory_2_outlined, () => setState(() => kitOpen = true)),
          ]),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), boxShadow: S.shadowSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: scroll
                ? SingleChildScrollView(
                    child: FittedBox(fit: BoxFit.fitWidth, alignment: Alignment.topLeft, child: groups),
                  )
                : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topLeft, child: groups),
          ),
          Container(height: 3, color: S.line),
          const SizedBox(height: 18),
          showAll(sw: 104, sub: false),
        ],
      ),
    );
  }

  Widget _shapeMenu(bool on, {required bool lines}) {
    final kinds = lines
        ? [
            (ShapeKind.line, Icons.horizontal_rule_rounded, 'Line', 'ಗೆರೆ'),
            (ShapeKind.arrow, Icons.arrow_right_alt_rounded, 'Arrow', 'ಬಾಣ'),
            (ShapeKind.doubleArrow, Icons.swap_horiz_rounded, 'Two-way arrow', 'ಎರಡು ಬದಿ ಬಾಣ'),
          ]
        : [
            (ShapeKind.circle, Icons.circle_outlined, 'Circle', 'ವೃತ್ತ'),
            (ShapeKind.ellipse, Icons.egg_outlined, 'Oval', 'ಅಂಡಾಕಾರ'),
            (ShapeKind.rectangle, Icons.crop_square_rounded, 'Rectangle', 'ಆಯತ'),
            (ShapeKind.triangle, Icons.change_history_rounded, 'Triangle', 'ತ್ರಿಕೋನ'),
            (ShapeKind.rightTriangle, Icons.signal_cellular_0_bar_rounded, 'Right triangle', 'ಲಂಬ ತ್ರಿಕೋನ'),
            (ShapeKind.parallelogram, Icons.view_compact_outlined, 'Parallelogram', 'ಸಮಾಂತರ ಚತುರ್ಭುಜ'),
            (ShapeKind.rhombus, Icons.diamond_outlined, 'Rhombus', 'ವಜ್ರಾಕೃತಿ'),
            (ShapeKind.pentagon, Icons.pentagon_outlined, 'Pentagon', 'ಪಂಚಭುಜ'),
            (ShapeKind.hexagon, Icons.hexagon_outlined, 'Hexagon', 'ಷಡ್ಭುಜ'),
          ];
    return PopupMenuButton<ShapeKind>(
      key: ValueKey(lines ? 'all-lines' : 'all-shapes'),
      tooltip: '',
      constraints: const BoxConstraints(minWidth: 560, maxWidth: 800),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      onSelected: (k) => board.setShape(k),
      itemBuilder: (_) => [
        for (final (k, i, en, kn) in kinds)
          PopupMenuItem(
            key: ValueKey('shape-${k.name}'),
            value: k,
            height: 110,
            child: Row(
              children: [
                Icon(i, size: 52, color: S.ink),
                const SizedBox(width: 20),
                Text(
                  tr(l, en, kn),
                  style: tx(34, c: S.ink, w: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
      child: ToolButton(
        lines ? tr(l, 'Line, arrow', 'ಗೆರೆ, ಬಾಣ') : tr(l, 'Shapes', 'ಆಕಾರಗಳು'),
        lines ? Icons.north_east_rounded : Icons.category_rounded,
        bg: on ? Colors.white : Colors.transparent,
        fg: S.ink,
        width: 188,
        height: 128,
        on: on,
      ),
    );
  }

  /// Background, zoom and pages, under the board.
  Widget _strip() {
    Widget head(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        s,
        style: tx(28, c: S.eyebrow, w: FontWeight.w700, h: 1.1),
      ),
    );
    Widget box(Widget c, {bool on = false, double w = 150, Key? key, VoidCallback? onTap}) => Tap(
      key: key,
      onTap: onTap,
      child: Container(
        width: w,
        height: 104,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: on ? S.soft : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: on ? S.ink : S.line, width: on ? 4 : 3),
        ),
        child: c,
      ),
    );
    final scale = board.view.value.scale;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), boxShadow: S.shadowSoft),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              head(tr(l, 'Background', 'ಹಿನ್ನೆಲೆ')),
              Row(
                children: [
                  for (final (bg, en, kn) in [
                    (BoardBackground.plain, 'Plain', 'ಸಾದಾ'),
                    (BoardBackground.ruled, 'Lined', 'ಗೆರೆ'),
                    (BoardBackground.grid, 'Grid', 'ಗ್ರಿಡ್'),
                    (BoardBackground.graph, 'Graph', 'ಗ್ರಾಫ್'),
                  ]) ...[
                    box(
                      Stack(
                        children: [
                          Positioned.fill(child: CustomPaint(painter: _MiniPaper(bg))),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              color: Colors.white,
                              child: Text(
                                tr(l, en, kn),
                                style: tx(26, c: S.ink, w: FontWeight.w700, h: 1.1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      on: board.background == bg,
                      key: ValueKey('bg-${bg.name}'),
                      onTap: () => board.background = bg,
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ],
          ),
          Container(width: 3, height: 140, color: S.line, margin: const EdgeInsets.symmetric(horizontal: 22)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              head(tr(l, 'Zoom', 'ಜೂಮ್')),
              Row(
                children: [
                  box(
                    const Icon(Icons.remove_rounded, size: 48, color: S.ink),
                    w: 104,
                    key: const ValueKey('zoomOut'),
                    onTap: () => board.zoomBy(1 / 1.25),
                  ),
                  const SizedBox(width: 10),
                  box(
                    Center(
                      child: Text(
                        '${(scale * 100).round()}%',
                        style: tx(32, c: S.ink, w: FontWeight.w700),
                      ),
                    ),
                    w: 130,
                    key: const ValueKey('zoomReset'),
                    onTap: board.resetZoom,
                  ),
                  const SizedBox(width: 10),
                  box(
                    const Icon(Icons.add_rounded, size: 48, color: S.ink),
                    w: 104,
                    key: const ValueKey('zoomIn'),
                    onTap: () => board.zoomBy(1.25),
                  ),
                ],
              ),
            ],
          ),
          Container(width: 3, height: 140, color: S.line, margin: const EdgeInsets.symmetric(horizontal: 22)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              head(tr(l, 'Pages', 'ಪುಟಗಳು')),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 150), child: pages(vertical: false, thumbW: 166)),
            ],
          ),
        ],
      ),
    );
  }

  // 04 · subject kit open.
  Widget _kitLayout() => Padding(
    padding: const EdgeInsets.fromLTRB(140, 50, 140, 50),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: FittedBox(fit: BoxFit.scaleDown, child: back(h: 120, size: 36)),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [undoPill(h: 120, size: 36), const SizedBox(width: 20), help(size: 32)]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Expanded(child: canvas()),
              const SizedBox(height: 36),
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(fit: BoxFit.scaleDown, child: simpleTools(clear: false)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 50),
        Expanded(flex: 9, child: _kitPanel()),
      ],
    ),
  );

  Widget _kitPanel({bool closeable = true}) {
    final items = kit;
    return Container(
      key: const ValueKey('kitPanel'),
      padding: const EdgeInsets.fromLTRB(44, 40, 44, 40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(56), boxShadow: S.shadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_subject(pack?.chapter.subject ?? '')} · ${pack?.chapter.title.t(l) ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx(34, c: S.eyebrow, w: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(l, 'Subject kit for this chapter', 'ಈ ಅಧ್ಯಾಯದ ವಿಷಯ ಕಿಟ್'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: hd(60, l: l),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr(l, 'Everything is saved on this board. No internet needed.', 'ಎಲ್ಲವೂ ಈ ಬೋರ್ಡ್‌ನಲ್ಲೇ ಇದೆ. ಇಂಟರ್ನೆಟ್ ಬೇಡ.'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tx(32, c: S.muted),
                    ),
                  ],
                ),
              ),
              if (closeable)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Tap(
                      key: const ValueKey('closeKit'),
                      onTap: () => setState(() => kitOpen = false),
                      child: BigButton(tr(l, 'Close', 'ಮುಚ್ಚಿ'), icon: Icons.close_rounded, bg: Colors.white, fg: S.ink, border: S.line, height: 128, size: 34),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text(tr(l, 'Open a chapter to see its kit.', 'ಕಿಟ್ ನೋಡಲು ಅಧ್ಯಾಯ ತೆರೆಯಿರಿ.'), style: tx(36)))
                : GridView.count(crossAxisCount: 2, mainAxisSpacing: 26, crossAxisSpacing: 26, childAspectRatio: 1.75, children: [for (final i in items) _kitCard(i)]),
          ),
        ],
      ),
    );
  }

  Widget _kitCard(KitItem i) {
    final on = belongs(i);
    return Container(
      key: ValueKey('kit-${i.key}'),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: kitColor(i.kind),
        borderRadius: BorderRadius.circular(44),
        border: on ? Border.all(color: S.violet, width: 6) : null,
      ),
      // Laid out at its design size and scaled to the card, so long (Kannada) titles never spill.
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 640,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                    child: Icon(kitIcon(i.kind), size: 52, color: S.ink),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Text(
                      kitKindName(i.kind).t(l),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx(32, c: S.cardText, w: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                i.title.t(l),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: hd(46, l: l),
              ),
              const SizedBox(height: 16),
              Tap(
                key: ValueKey('put-${i.key}'),
                onTap: on ? null : () => putOnBoard(i),
                child: on
                    ? WbTag(tr(l, 'On the board', 'ಬೋರ್ಡ್‌ನಲ್ಲಿದೆ'), icon: Icons.check_rounded, bg: S.green, fg: Colors.white, size: 32)
                    : WbTag(
                        i.online ? tr(l, 'Needs internet', 'ಇಂಟರ್ನೆಟ್ ಬೇಕು') : tr(l, 'Put on board', 'ಬೋರ್ಡ್‌ಗೆ ಹಾಕಿ'),
                        icon: i.online ? Icons.wifi_rounded : Icons.add_rounded,
                        bg: Colors.white,
                        size: 32,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 05 · lesson step as a page.
  Widget _lessonLayout() {
    final lesson = widget.lesson!;
    final s = steps[stepAt!];
    final done = steps.take(stepAt!).fold(0, (a, b) => a + b.minutes);
    final total = steps.fold(0, (a, b) => a + b.minutes);
    final next = stepAt! + 1 < steps.length ? steps[stepAt! + 1] : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(140, 50, 140, 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      back(),
                      const SizedBox(width: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1500),
                        child: Text(
                          tr(l, '$_title · today’s lesson', '$_title · ಇಂದಿನ ಪಾಠ'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hd(54, l: l),
                        ),
                      ),
                      const SizedBox(width: 24),
                      WbTag(tr(l, '${done + s.minutes} of $total min', '${done + s.minutes} / $total ನಿಮಿಷ'), icon: Icons.schedule_rounded, bg: Colors.white, size: 30),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [undoPill(), const SizedBox(width: 20), help()]),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _flowBar(),
          const SizedBox(height: 36),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 16, child: canvas()),
                const SizedBox(width: 48),
                Expanded(
                  flex: 9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 11, child: _quickCheck(lesson)),
                      const SizedBox(height: 36),
                      Expanded(flex: 8, child: _recapCard(lesson)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: simpleTools(clear: false)),
              const SizedBox(width: 24),
              if (allTools)
                Tap(key: const ValueKey('leaveLessonPage'), onTap: () => setState(() => stepAt = null), child: Pill(tr(l, 'All tools', 'ಎಲ್ಲಾ ಸಾಧನಗಳು'), Icons.apps_rounded, h: 120, size: 34)),
              const Spacer(),
              if (next != null)
                Flexible(
                  child: Tap(
                    key: const ValueKey('nextStep'),
                    onTap: () => showStep(stepAt! + 1),
                    child: BigButton(tr(l, 'Next step: ${plain(next.title.t(l))}', 'ಮುಂದಿನ ಹಂತ: ${plain(next.title.t(l))}'), icon: Icons.arrow_forward_rounded, bg: S.violet, height: 176, size: 46),
                  ),
                )
              else
                Tap(
                  key: const ValueKey('nextStep'),
                  onTap: openRecap,
                  child: BigButton(tr(l, 'Open the recap', 'ಪುನರಾವರ್ತನೆ ತೆರೆಯಿರಿ'), icon: Icons.description_outlined, bg: S.violet, height: 176, size: 46),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flowBar() => Container(
    key: const ValueKey('flowBar'),
    height: 156,
    padding: const EdgeInsets.symmetric(horizontal: 30),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(44), boxShadow: S.shadowSoft),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: steps.length,
      separatorBuilder: (_, i) => Center(
        child: Container(width: 110, height: 5, margin: const EdgeInsets.symmetric(horizontal: 20), color: i < stepAt! ? S.green : S.line),
      ),
      itemBuilder: (_, i) {
        final s = steps[i];
        final now = i == stepAt;
        return Center(
          child: Tap(
            key: ValueKey('flowStep-$i'),
            onTap: () => showStep(i),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 30, 12),
              decoration: now
                  ? BoxDecoration(
                      color: S.soft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: S.violet, width: 5),
                    )
                  : null,
              child: Row(
                children: [
                  Tick(done: i < stepAt!, now: now, n: i + 1, size: 72),
                  const SizedBox(width: 18),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          plain(s.title.t(l)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tx(32, c: S.ink, w: FontWeight.w600, h: 1.1),
                        ),
                      ),
                      Text(tr(l, '${s.minutes} min', '${s.minutes} ನಿಮಿಷ'), style: tx(26, c: S.muted, h: 1.1)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _quickCheck(Lesson lesson) {
    final q = quickCheck(lesson, pack, steps[stepAt!].index);
    return Container(
      key: const ValueKey('quickCheck'),
      padding: const EdgeInsets.all(44),
      decoration: BoxDecoration(color: S.lavender, borderRadius: BorderRadius.circular(48)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(l, 'Quick check · ask the class', 'ತ್ವರಿತ ಪರೀಕ್ಷೆ · ತರಗತಿಯನ್ನು ಕೇಳಿ'),
            style: tx(32, c: S.eyebrow, w: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(q == null ? tr(l, 'No question for this step.', 'ಈ ಹಂತಕ್ಕೆ ಪ್ರಶ್ನೆ ಇಲ್ಲ.') : plain(q.stem.t(l)), style: hd(48, l: l)),
            ),
          ),
          const SizedBox(height: 20),
          if (q != null)
            Tap(
              key: const ValueKey('showAnswer'),
              onTap: () => setState(() => answerShown = !answerShown),
              child: Container(
                height: 150,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  gradient: answerShown ? null : const LinearGradient(colors: [S.night, S.violet]),
                  color: answerShown ? Colors.white : null,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: answerShown
                    ? Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 60, color: S.green),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Text(
                              answerOf(q, l),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tx(40, c: S.ink, w: FontWeight.w700),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.visibility_off_outlined, size: 64, color: Colors.white),
                          const SizedBox(width: 24),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(l, 'Tap to show the answer', 'ಉತ್ತರ ತೋರಿಸಲು ಒತ್ತಿ'),
                                    style: tx(40, c: Colors.white, w: FontWeight.w700, h: 1.15),
                                  ),
                                  Text(tr(l, 'Hidden until you tap', 'ನೀವು ಒತ್ತುವವರೆಗೆ ಮರೆ'), style: tx(28, c: const Color(0xCCFFFFFF), h: 1.2)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recapCard(Lesson lesson) {
    final points = recapPoints(lesson, steps, l);
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: S.mint, borderRadius: BorderRadius.circular(48)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(l, 'Recap', 'ಪುನರಾವರ್ತನೆ'), style: hd(34, l: l)),
                  const SizedBox(height: 8),
                  for (final p in points.take(4))
                    Text(
                      '• $p',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx(26, c: S.cardText, h: 1.35),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 26),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(l, 'Recap page', 'ಪುನರಾವರ್ತನೆ ಪುಟ'), style: hd(46, l: l)),
                const SizedBox(height: 10),
                Flexible(
                  child: Text(tr(l, 'Made from today’s steps.', 'ಇಂದಿನ ಹಂತಗಳಿಂದ ಮಾಡಿದ್ದು.'), style: tx(30, c: S.cardText)),
                ),
                const Spacer(),
                Tap(
                  key: const ValueKey('openRecap'),
                  onTap: openRecap,
                  child: WbTag(tr(l, 'Open recap', 'ಪುನರಾವರ್ತನೆ ತೆರೆಯಿರಿ'), icon: Icons.description_outlined, bg: Colors.white, size: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 09 · tablet and phone.
  Widget _narrow(BoxConstraints box) {
    final w = box.maxWidth;
    final pad = w < 1000 ? 30.0 : 50.0;
    // Held sideways (a phone or small tablet): the board on the left, the tools in a column.
    final side = w > box.maxHeight;
    final sideW = (w * .38).clamp(560.0, 1000.0);
    final cell = side ? (sideW - 18) / 2 : (w - pad * 2 - 3 * 18) / 4;
    final t = board.tool;
    Widget cellTool(String key, String label, IconData icon, VoidCallback? onTap, {bool on = false, Color? dot, Color bg = Colors.white, Color fg = S.ink}) => Tap(
      key: ValueKey(key),
      label: label,
      onTap: onTap,
      child: ToolButton(label, icon, dot: dot, bg: on ? S.soft : bg, fg: fg, width: cell, height: 150, on: on),
    );
    bool penOn(Color c) => t == BoardTool.pen && board.penColor.toARGB32() == c.toARGB32();
    final simple = [
      cellTool('tool-pen', tr(l, 'Pen', 'ಪೆನ್'), Icons.circle, () => pen(wbInk), on: penOn(wbInk), dot: wbInk),
      cellTool('tool-blue', tr(l, 'Blue', 'ನೀಲಿ'), Icons.circle, () => pen(wbBlue), on: penOn(wbBlue), dot: wbBlue),
      cellTool('tool-red', tr(l, 'Red', 'ಕೆಂಪು'), Icons.circle, () => pen(wbRed), on: penOn(wbRed), dot: wbRed),
      cellTool('tool-highlighter', tr(l, 'Highlight', 'ಹೈಲೈಟ್'), Icons.border_color_rounded, highlight, on: t == BoardTool.highlighter),
      cellTool('tool-eraser', tr(l, 'Eraser', 'ರಬ್ಬರ್'), Icons.auto_fix_normal_rounded, () => eraser(EraserMode.stroke), on: t == BoardTool.eraser),
      cellTool('undo', tr(l, 'Undo', 'ರದ್ದುಮಾಡು'), Icons.undo_rounded, board.canUndo ? board.undo : null),
      cellTool('insert', tr(l, 'Insert', 'ಸೇರಿಸಿ'), Icons.add_photo_alternate_outlined, openInsert),
      cellTool('clearPage', tr(l, 'Clear', 'ಅಳಿಸಿ'), Icons.delete_outline_rounded, board.canClearPage ? clearPage : null, bg: S.peach, fg: S.rust),
    ];
    final extras = <Widget>[
      if (allTools) ...[
        const SizedBox(height: 20),
        SizedBox(height: 900, child: _toolPanel(scroll: true)),
        const SizedBox(height: 20),
        FittedBox(fit: BoxFit.scaleDown, child: _topTools(h: 100, size: 28)),
      ],
      if (kitOpen) ...[const SizedBox(height: 20), SizedBox(height: 1100, child: _kitPanel())],
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(36)),
        child: showAll(sw: 120),
      ),
      if (board.geoTools.value.isNotEmpty) ...[
        const SizedBox(height: 20),
        Tap(
          key: const ValueKey('putToolsAway'),
          onTap: putToolsAway,
          child: BigButton(tr(l, 'Put the tools away', 'ಸಾಧನಗಳನ್ನು ಇಡಿ'), icon: Icons.check_rounded, bg: S.violet, height: 120, size: 34),
        ),
      ],
    ];
    final next = stepAt != null && stepAt! + 1 < steps.length
        ? Tap(
            key: const ValueKey('nextStep'),
            onTap: () => showStep(stepAt! + 1),
            child: BigButton(
              tr(l, 'Next step: ${plain(steps[stepAt! + 1].title.t(l))}', 'ಮುಂದಿನ ಹಂತ: ${plain(steps[stepAt! + 1].title.t(l))}'),
              icon: Icons.arrow_forward_rounded,
              bg: S.violet,
              height: 120,
              size: 34,
            ),
          )
        : null;
    if (side) {
      return Padding(
        padding: EdgeInsets.all(pad * .6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(fit: BoxFit.scaleDown, child: back(h: 100, size: 30)),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: FittedBox(fit: BoxFit.scaleDown, child: help(size: 28)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: canvas()),
                ],
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: sideW,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      stepAt != null
                          ? plain(steps[stepAt!].title.t(l))
                          : tr(l, '$_title · page ${board.pageIndex + 1} of ${board.pageCount}', '$_title · ಪುಟ ${board.pageIndex + 1} / ${board.pageCount}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: hd(44, l: l),
                    ),
                    const SizedBox(height: 16),
                    next ?? SizedBox(height: 175, child: pages(vertical: false, thumbW: 210)),
                    const SizedBox(height: 16),
                    Wrap(spacing: 18, runSpacing: 18, children: simple),
                    ...extras,
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad * .6, pad, pad * .6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: back(h: 110, size: 32)),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: help(size: 30)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            stepAt != null ? plain(steps[stepAt!].title.t(l)) : tr(l, '$_title · page ${board.pageIndex + 1} of ${board.pageCount}', '$_title · ಪುಟ ${board.pageIndex + 1} / ${board.pageCount}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hd(52, l: l),
          ),
          const SizedBox(height: 20),
          Expanded(flex: 5, child: canvas()),
          const SizedBox(height: 24),
          next ?? SizedBox(height: 215, child: pages(vertical: false, thumbW: 260)),
          const SizedBox(height: 20),
          Flexible(
            flex: allTools || kitOpen ? 5 : 3,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 18, runSpacing: 18, children: simple),
                  ...extras,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPaper extends CustomPainter {
  _MiniPaper(this.bg);
  final BoardBackground bg;
  @override
  void paint(Canvas canvas, Size size) => paintBoardBackground(canvas, Offset.zero & size, bg, scale: .45);
  @override
  bool shouldRepaint(_MiniPaper old) => old.bg != bg;
}

/// 07 · Projector / TV: the board alone, full screen, with the page number. The teacher can
/// still write on it; Esc, Back or the corner button leaves.
class _ProjectorView extends StatefulWidget {
  const _ProjectorView({required this.state});
  final SmartboardScreenState state;
  @override
  State<_ProjectorView> createState() => _ProjectorViewState();
}

class _ProjectorViewState extends State<_ProjectorView> {
  bool _chrome = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _show() {
    setState(() => _chrome = true);
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () => mounted ? setState(() => _chrome = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state, b = s.board, l = s.l;
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListenableBuilder(
        listenable: b,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: (_) => _show(),
                child: WhiteboardCanvas(
                  key: const ValueKey('projectorCanvas'),
                  controller: b,
                  liveOverlay: (ctx, view) => LiveObjectsLayer(board: b, view: view, lang: l, interactive: false),
                ),
              ),
            ),
            if (s.blank) const Positioned.fill(child: ColoredBox(color: Colors.black)),
            Positioned(
              right: 40,
              bottom: 30,
              child: IgnorePointer(
                child: Text(
                  '${b.pageIndex + 1} / ${b.pageCount}',
                  style: tx(34, c: const Color(0xFF9A9EB2), w: FontWeight.w600),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _chrome ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tap(onTap: b.hasPrevious ? b.previous : null, child: Pill(tr(l, 'Back', 'ಹಿಂದೆ'), Icons.chevron_left_rounded, h: 110, size: 32)),
                      const SizedBox(width: 14),
                      Tap(onTap: b.hasNext ? b.next : null, child: Pill(tr(l, 'Next', 'ಮುಂದೆ'), Icons.chevron_right_rounded, h: 110, size: 32)),
                      const SizedBox(width: 14),
                      Tap(
                        key: const ValueKey('leaveProjector'),
                        onTap: () => Navigator.pop(context),
                        child: BigButton(tr(l, 'Leave projector', 'ಪ್ರೊಜೆಕ್ಟರ್‌ನಿಂದ ಹೊರಬನ್ನಿ'), icon: Icons.close_fullscreen_rounded, height: 110, size: 32),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
