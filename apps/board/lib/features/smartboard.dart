import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kinetix_3d/kinetix_3d.dart' show Model3dLibrary;
import 'package:kinetix_animations/kinetix_animations.dart' show AnimLang, AnimationsPanel;
import 'package:kinetix_cs/kinetix_cs.dart' show AlgoKind, AlgoPlayer, CodeLab, CodeLanguage, SimKind, SimPanel;
import 'package:kinetix_ink/kinetix_ink.dart';
import 'package:kinetix_labs/kinetix_labs.dart' show LabBrowser, LabLang;
import 'package:kinetix_ui/kinetix_ui.dart' show KinetixTheme;

import '../core/apps.dart';
import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';

/// The always-visible way to the Smartboard. [onOpen] runs before it opens (the lesson player
/// pauses), [onClose] after it closes.
class SmartboardButton extends StatelessWidget {
  const SmartboardButton({super.key, this.onOpen, this.onClose});
  final VoidCallback? onOpen, onClose;

  @override
  Widget build(BuildContext context) {
    final l = ServicesScope.of(context).config.lang;
    return BigButton(
      key: const ValueKey('smartboard'),
      icon: Icons.draw_outlined,
      label: tr('smartboard', l),
      filled: false,
      onPressed: () async {
        onOpen?.call();
        await openSmartboard(context);
        onClose?.call();
      },
    );
  }
}

Future<void> openSmartboard(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const SmartboardScreen()));

/// A full-screen board on the Kinetix ink engine: pages, a big toolbar, and an Insert panel with
/// 3D models, labs, animations, computer science players and maths. The pages stay while the
/// app runs, so closing the board (to go back to a lesson) and opening it again keeps the work.
class SmartboardScreen extends StatefulWidget {
  const SmartboardScreen({super.key, this.controller});

  /// The board to show; the app's shared board by default.
  final WhiteboardController? controller;

  static WhiteboardController? _shared;
  static WhiteboardController get shared => _shared ??= newBoard();

  /// A chalkboard with white chalk, like the classroom's own.
  static WhiteboardController newBoard() {
    final c = WhiteboardController()..background = BoardBackground.chalkboard;
    c.setPen(color: WhiteboardController.chalkWhite, width: 6);
    return c;
  }

  @override
  State<SmartboardScreen> createState() => SmartboardScreenState();
}

const _chalk = [Color(0xFFFFFFFF), Color(0xFFFFE45C), Color(0xFFFF7A70), Color(0xFF8BE88F), Color(0xFF7CC4FF), Color(0xFFFFB25C)];
const _widths = [3.0, 6.0, 12.0];

class SmartboardScreenState extends State<SmartboardScreen> {
  late final WhiteboardController board = widget.controller ?? SmartboardScreen.shared;
  bool insertOpen = false;
  double panelWidth = 820;
  late final Future<bool> _kinetixInstalled = Apps.isInstalled(Apps.kinetixBoard);

  void toggleInsert() => setState(() => insertOpen = !insertOpen);

  String _id() => 'zx${DateTime.now().microsecondsSinceEpoch}';
  Offset get _middle => board.visibleArea?.center ?? const Offset(600, 400);

  void insertElements(List<BoardElement> els) => board.addAll(els, group: true);

  void insertImage(Uint8List png, {Size size = const Size(640, 360)}) =>
      board.add(ImageElement(id: _id(), rect: Rect.fromCenter(center: _middle, width: size.width, height: size.height), bytes: png));

  void insertMath(String tex) {
    if (tex.trim().isEmpty) return;
    const fontSize = 56.0;
    board.add(MathElement(id: _id(), position: _middle - const Offset(200, 40), latex: tex.trim(), color: board.penColor, fontSize: fontSize, size: const Size(400, 80)));
  }

  Future<String?> _editMath(String? latex) => showDialog<String>(
        context: context,
        builder: (ctx) {
          final t = TextEditingController(text: latex ?? '');
          return AlertDialog(
            title: Text(tr('maths', ServicesScope.of(context).config.lang), style: zText(40)),
            content: SizedBox(width: 800, child: TextField(controller: t, autofocus: true, style: const TextStyle(fontSize: 34), decoration: const InputDecoration(hintText: r'\frac{a}{b}'))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel', ServicesScope.of(context).config.lang), style: zText(30))),
              FilledButton(onPressed: () => Navigator.pop(ctx, t.text), child: Text(tr('done', ServicesScope.of(context).config.lang))),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), l = s.config.lang;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: board,
          builder: (context, _) => Column(children: [
            _topBar(l),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: ClipRect(child: WhiteboardCanvas(key: const ValueKey('smartboardCanvas'), controller: board, editMath: _editMath))),
                if (insertOpen) ...[
                  // Drag to make the panel wider or narrower.
                  GestureDetector(
                    key: const ValueKey('panelHandle'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (d) => setState(() => panelWidth = (panelWidth - d.delta.dx).clamp(480.0, MediaQuery.sizeOf(context).width - 480)),
                    child: Container(
                      width: 36,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.drag_indicator, size: 36),
                    ),
                  ),
                  SizedBox(width: panelWidth, child: InsertPanel(board: this, lang: l, kinetixInstalled: _kinetixInstalled)),
                ],
              ]),
            ),
            _toolbar(l),
          ]),
        ),
      ),
    );
  }

  Widget _topBar(Lang l) {
    final text = Theme.of(context).textTheme;
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(children: [
        BigButton(key: const ValueKey('closeSmartboard'), icon: Icons.close, label: tr('close', l), filled: false, onPressed: () => Navigator.pop(context)),
        const SizedBox(width: 24),
        const Icon(Icons.draw_outlined, size: 52, color: Z.accent),
        const SizedBox(width: 12),
        Text(tr('smartboard', l), style: text.headlineLarge),
        const Spacer(),
        IconButton.filledTonal(key: const ValueKey('prevPage'), iconSize: 56, onPressed: board.hasPrevious ? board.previous : null, icon: const Icon(Icons.chevron_left)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('${tr('page', l)} ${board.pageIndex + 1} / ${board.pageCount}', key: const ValueKey('pageNo'), style: text.headlineMedium),
        ),
        IconButton.filledTonal(key: const ValueKey('nextPage'), iconSize: 56, onPressed: board.hasNext ? board.next : null, icon: const Icon(Icons.chevron_right)),
        const SizedBox(width: 12),
        IconButton.filledTonal(key: const ValueKey('newPage'), iconSize: 56, tooltip: 'New page', onPressed: board.canAddPage ? board.addPage : null, icon: const Icon(Icons.note_add_outlined)),
        const Spacer(),
        BigButton(key: const ValueKey('insert'), icon: Icons.add_box_outlined, label: tr('insert', l), filled: insertOpen, onPressed: toggleInsert),
      ]),
    );
  }

  Widget _toolbar(Lang l) {
    final t = board.tool;
    final hl = t == BoardTool.highlighter;
    final color = hl ? board.highlighterColor : board.penColor;
    final width = hl ? board.highlighterWidth : board.penWidth;
    Widget sep() => Container(width: 2, height: 72, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white24);
    return Container(
      key: const ValueKey('smartboardToolbar'),
      color: Theme.of(context).colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Tool(key: const ValueKey('tool-pen'), icon: Icons.edit, label: 'Pen', on: t == BoardTool.pen, onTap: () => board.setPen()),
        _Tool(key: const ValueKey('tool-highlighter'), icon: Icons.highlight, label: 'Marker', on: hl, onTap: () => board.setHighlighter()),
        _Tool(key: const ValueKey('tool-eraser'), icon: Icons.auto_fix_normal, label: 'Eraser', on: t == BoardTool.eraser, onTap: () => board.tool = BoardTool.eraser),
        PopupMenuButton<ShapeKind>(
          key: const ValueKey('tool-shapes'),
          onSelected: board.setShape,
          itemBuilder: (_) => [
            for (final (k, i, n) in const [
              (ShapeKind.line, Icons.horizontal_rule, 'Line'),
              (ShapeKind.arrow, Icons.arrow_right_alt, 'Arrow'),
              (ShapeKind.circle, Icons.circle_outlined, 'Circle'),
              (ShapeKind.rectangle, Icons.crop_square, 'Rectangle'),
              (ShapeKind.triangle, Icons.change_history, 'Triangle'),
            ])
              PopupMenuItem(value: k, height: 88, child: Row(children: [Icon(i, size: 48), const SizedBox(width: 16), Text(n, style: zText(30))])),
          ],
          child: _Tool(icon: Icons.category_outlined, label: 'Shapes', on: t == BoardTool.shape, menu: true),
        ),
        _Tool(key: const ValueKey('tool-select'), icon: Icons.highlight_alt, label: 'Select', on: t == BoardTool.select, onTap: () => board.tool = BoardTool.select),
        sep(),
        for (final c in _chalk)
          _Swatch(
            key: ValueKey('colour-${c.toARGB32().toRadixString(16)}'),
            color: c,
            on: c.toARGB32() == color.toARGB32() && t != BoardTool.eraser,
            onTap: () => hl ? board.setHighlighter(color: c) : board.setPen(color: c),
          ),
        sep(),
        for (final w in _widths)
          _Tool(
            key: ValueKey('width-$w'),
            on: width == w,
            label: w == 3 ? 'Thin' : (w == 6 ? 'Medium' : 'Thick'),
            onTap: () => hl ? board.setHighlighter(width: w) : board.setPen(width: w),
            child: Container(width: 40, height: w * 1.6 + 2, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
          ),
        sep(),
        _Tool(key: const ValueKey('undo'), icon: Icons.undo, label: 'Undo', onTap: board.canUndo ? board.undo : null),
        _Tool(key: const ValueKey('redo'), icon: Icons.redo, label: 'Redo', onTap: board.canRedo ? board.redo : null),
        _Tool(key: const ValueKey('clearPage'), icon: Icons.delete_sweep_outlined, label: 'Clear', onTap: board.canClearPage ? board.clearPage : null),
      ]),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({super.key, this.icon, this.child, required this.label, this.on = false, this.onTap, this.menu = false});
  final IconData? icon;
  final Widget? child;
  final String label;
  final bool on;
  final VoidCallback? onTap;
  /// Opens a menu itself (the shapes button), so it has no onTap and is still enabled.
  final bool menu;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: on ? Z.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            width: 92,
            height: Z.tap,
            child: Opacity(
              opacity: onTap == null && !menu ? 0.35 : 1,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                child ?? Icon(icon, size: 42, color: on ? Colors.black : null),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, overflow: TextOverflow.clip, style: zText(18, FontWeight.w600).copyWith(color: on ? Colors.black : null, height: 1.1)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.color, required this.on, required this.onTap});
  final Color color;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: on ? Z.accent : Colors.white24, width: on ? 7 : 2)),
          ),
        ),
      );
}

/// Insert: 3D models, labs, animations, computer science and maths, beside the board; and the
/// full Zynetix Board app when it is installed.
class InsertPanel extends StatefulWidget {
  const InsertPanel({super.key, required this.board, required this.lang, required this.kinetixInstalled});
  final SmartboardScreenState board;
  final Lang lang;
  final Future<bool> kinetixInstalled;
  @override
  State<InsertPanel> createState() => _InsertPanelState();
}

class _InsertPanelState extends State<InsertPanel> {
  String? model, lab, cs;
  final tex = TextEditingController(text: r'v = u + at');

  static const _formulas = [r'v = u + at', r's = ut + \tfrac{1}{2}at^2', r'F = ma', r'x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}', r'PV = nRT', r'\sin^2\theta + \cos^2\theta = 1', r'E = mc^2', r'\int_0^1 x^2\,dx = \tfrac{1}{3}'];
  static const _algoNames = {
    AlgoKind.bubble: 'Bubble sort', AlgoKind.insertion: 'Insertion sort', AlgoKind.selection: 'Selection sort', AlgoKind.merge: 'Merge sort', AlgoKind.quick: 'Quick sort',
    AlgoKind.heap: 'Heap sort', AlgoKind.linear: 'Linear search', AlgoKind.binary: 'Binary search', AlgoKind.stack: 'Stack', AlgoKind.queue: 'Queue', AlgoKind.list: 'Linked list',
    AlgoKind.hash: 'Hash table', AlgoKind.bst: 'Binary search tree', AlgoKind.bfs: 'BFS', AlgoKind.dfs: 'DFS', AlgoKind.dijkstra: 'Dijkstra',
  };
  static const _simNames = {
    SimKind.numbers: 'Number systems', SimKind.logic: 'Logic gates', SimKind.osi: 'OSI model', SimKind.tcp: 'TCP handshake', SimKind.subnet: 'Subnetting',
    SimKind.cpu: 'CPU scheduling', SimKind.paging: 'Paging', SimKind.banker: "Banker's algorithm", SimKind.normal: 'Normalisation',
  };

  @override
  void dispose() {
    tex.dispose();
    super.dispose();
  }

  Widget _back(String title, VoidCallback onBack) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          IconButton(iconSize: 52, icon: const Icon(Icons.arrow_back), onPressed: onBack),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: zText(30, FontWeight.w700), overflow: TextOverflow.ellipsis)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), l = widget.lang;
    final tabs = [tr('models3d', l), tr('labs', l), tr('animations', l), tr('computerScience', l), tr('maths', l)];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: DefaultTabController(
        length: tabs.length,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FutureBuilder<bool>(
            future: widget.kinetixInstalled,
            builder: (context, snap) => snap.data == true
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BigButton(key: const ValueKey('openKinetix'), icon: Icons.open_in_new, label: tr('openKinetix', l), filled: false, onPressed: () => Apps.launch(Apps.kinetixBoard)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            labelStyle: zText(27, FontWeight.w700),
            unselectedLabelStyle: zText(26, FontWeight.w500),
            tabs: [for (final (i, t) in tabs.indexed) Tab(key: ValueKey('insertTab-$i'), height: Z.tap - 8, text: t)],
          ),
          Expanded(
            // The Kinetix panels are laid out for the Kinetix board theme, not the back-bench sizes.
            child: Theme(
              data: KinetixTheme.board(),
              child: TabBarView(physics: const NeverScrollableScrollPhysics(), children: [
              // 3D models: the library, then the model in this panel.
              model == null
                  ? Model3dLibrary(lang: l.name, onPick: (id) => setState(() => model = id))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _back(model!, () => setState(() => model = null)),
                      Expanded(child: s.embeds.model3d(Block(BlockType.model3d, {'id': 'smartboard', 'modelId': model, 'caption': {'en': ''}}), l)),
                    ]),
              lab == null
                  ? LabBrowser(lang: l == Lang.kn ? LabLang.kn : LabLang.en, onOpen: (_, e) => setState(() => lab = e.id))
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _back(lab!, () => setState(() => lab = null)),
                      Expanded(child: s.embeds.lab(lab!, null, l)),
                    ]),
              AnimationsPanel(lang: l == Lang.kn ? AnimLang.kn : AnimLang.en, onAddToBoard: (png, _) => widget.board.insertImage(png)),
              cs == null ? _csPicker() : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_back(_csTitle(cs!), () => setState(() => cs = null)), Expanded(child: _csPlayer(cs!))]),
              _maths(l),
            ]),
            ),
          ),
        ]),
      ),
    );
  }

  String _csTitle(String id) {
    final (kind, name) = switch (id.split('.')) { [final k, final n] => (k, n), _ => ('', '') };
    return switch (kind) {
      'algo' => _algoNames[AlgoKind.values.byName(name)]!,
      'sim' => _simNames[SimKind.values.byName(name)]!,
      _ => CodeLanguage.values.byName(name).label,
    };
  }

  Widget _csPlayer(String id) {
    final (kind, name) = switch (id.split('.')) { [final k, final n] => (k, n), _ => ('', '') };
    final insert = widget.board.insertElements;
    return switch (kind) {
      'algo' => AlgoPlayer(kind: AlgoKind.values.byName(name), onInsert: insert),
      'sim' => SimPanel(kind: SimKind.values.byName(name), onInsert: insert),
      _ => CodeLab(initialLanguage: CodeLanguage.values.byName(name), onInsert: insert),
    };
  }

  Widget _csPicker() {
    Widget group(String title, List<(String, String)> items) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: zText(30, FontWeight.w700).copyWith(color: Z.accent)),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final (id, label) in items)
                ActionChip(key: ValueKey('cs:$id'), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), label: Text(label, style: zText(26)), onPressed: () => setState(() => cs = id)),
            ]),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(20), children: [
      group('Algorithms', [for (final e in _algoNames.entries) ('algo.${e.key.name}', e.value)]),
      group('Simulations', [for (final e in _simNames.entries) ('sim.${e.key.name}', e.value)]),
      group('Code', [for (final c in CodeLanguage.values) if (c.onDevice) ('code.${c.name}', c.label)]),
    ]);
  }

  Widget _maths(Lang l) => ListView(padding: const EdgeInsets.all(20), children: [
        TextField(
          key: const ValueKey('texInput'),
          controller: tex,
          style: const TextStyle(fontSize: 32, fontFamily: 'monospace'),
          decoration: const InputDecoration(labelText: 'LaTeX', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Container(
          height: 160,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFF1C2B26), borderRadius: BorderRadius.circular(Z.radius)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Math.tex(tex.text, textStyle: const TextStyle(fontSize: 52, color: Colors.white), onErrorFallback: (e) => Text(e.message, style: const TextStyle(fontSize: 24, color: Z.wrong))),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerLeft, child: BigButton(key: const ValueKey('addMath'), icon: Icons.add, label: tr('addToBoard', l), onPressed: () => widget.board.insertMath(tex.text))),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final f in _formulas)
            ActionChip(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              label: Math.tex(f, textStyle: const TextStyle(fontSize: 28), onErrorFallback: (_) => Text(f)),
              onPressed: () => setState(() => tex.text = f),
            ),
        ]),
      ]);
}
