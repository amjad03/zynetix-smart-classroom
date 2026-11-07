import 'package:flutter/material.dart';
import 'package:kinetix_3d/kinetix_3d.dart' show Model3dLibrary;
import 'package:kinetix_ink/kinetix_ink.dart' hide Lesson;
import 'package:kinetix_labs/kinetix_labs.dart' show LabBrowser, LabLang;
import 'package:kinetix_ui/kinetix_ui.dart' show KinetixTheme;

import '../core/apps.dart';
import '../engine/model.dart';
import '../features/simple/kit.dart';
import 'subject_kit.dart';
import 'wb_widgets.dart';

/// What the Insert menu puts on the board.
enum InsertKind { picture, powerpoint, model3d, lab, simulation, graph, blank, template }

/// "What do you want to put on the board?": eight cards, all offline, all undoable.
Future<InsertKind?> showInsertMenu(BuildContext context, Lang l, {VoidCallback? help, Future<bool>? kinetix}) => showDialog<InsertKind>(
  context: context,
  barrierColor: const Color(0x9913165A),
  builder: (ctx) {
    final items = [
      (InsertKind.picture, S.sky, Icons.image_outlined, tr(l, 'Picture', 'ಚಿತ್ರ'), tr(l, 'From a pen drive or this board', 'ಪೆನ್ ಡ್ರೈವ್ ಅಥವಾ ಈ ಬೋರ್ಡ್‌ನಿಂದ')),
      (InsertKind.powerpoint, S.peach, Icons.slideshow_rounded, tr(l, 'PowerPoint slides', 'ಪವರ್‌ಪಾಯಿಂಟ್ ಸ್ಲೈಡ್‌ಗಳು'), tr(l, 'Each slide becomes a page', 'ಪ್ರತಿ ಸ್ಲೈಡ್ ಒಂದು ಪುಟವಾಗುತ್ತದೆ')),
      (InsertKind.model3d, S.lavender, Icons.view_in_ar_rounded, tr(l, '3D model', '3D ಮಾದರಿ'), tr(l, 'Earth, heart, atom, engine…', 'ಭೂಮಿ, ಹೃದಯ, ಪರಮಾಣು, ಎಂಜಿನ್…')),
      (InsertKind.lab, S.mint, Icons.science_outlined, tr(l, 'Virtual lab', 'ವರ್ಚುವಲ್ ಲ್ಯಾಬ್'), tr(l, 'Do the experiment on the board', 'ಬೋರ್ಡ್‌ನಲ್ಲೇ ಪ್ರಯೋಗ ಮಾಡಿ')),
      (InsertKind.simulation, S.butter, Icons.play_circle_outline_rounded, tr(l, 'Simulation', 'ಸಿಮ್ಯುಲೇಶನ್'), tr(l, 'Move a slider, watch it change', 'ಸ್ಲೈಡರ್ ಸರಿಸಿ, ಬದಲಾವಣೆ ನೋಡಿ')),
      (InsertKind.graph, S.pink, Icons.show_chart_rounded, tr(l, 'Graph', 'ಗ್ರಾಫ್'), tr(l, 'Axes ready. Type y = 2x + 1', 'ಅಕ್ಷಗಳು ಸಿದ್ಧ. y = 2x + 1 ಟೈಪ್ ಮಾಡಿ')),
      (InsertKind.blank, S.mist, Icons.note_add_outlined, tr(l, 'Blank page', 'ಖಾಲಿ ಪುಟ'), tr(l, 'A fresh white page', 'ಹೊಸ ಬಿಳಿ ಪುಟ')),
      (InsertKind.template, S.mint, Icons.grid_on_rounded, tr(l, 'Template', 'ಟೆಂಪ್ಲೇಟ್'), tr(l, 'Lined, grid, graph, map, table', 'ಗೆರೆ, ಗ್ರಿಡ್, ಗ್ರಾಫ್, ನಕ್ಷೆ, ಕೋಷ್ಟಕ')),
    ];
    return LayoutBuilder(
      builder: (ctx, box) {
        final narrow = box.maxWidth < 2000;
        final cols = narrow ? 2 : 4;
        return Dialog(
          insetPadding: EdgeInsets.all(narrow ? 24 : 80),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(56)),
          child: Padding(
            padding: EdgeInsets.all(narrow ? 36 : 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(l, 'Insert', 'ಸೇರಿಸಿ'),
                            style: tx(34, c: S.eyebrow, w: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(tr(l, 'What do you want to put on the board?', 'ಬೋರ್ಡ್ ಮೇಲೆ ಏನು ಹಾಕಬೇಕು?'), style: hd(narrow ? 56 : 80, l: l)),
                        ],
                      ),
                    ),
                    if (help != null && !narrow) ...[
                      Tap(
                        onTap: help,
                        child: HelpButton(lang: l, size: 32),
                      ),
                      const SizedBox(width: 20),
                    ],
                    Tap(
                      key: const ValueKey('closeInsert'),
                      onTap: () => Navigator.pop(ctx),
                      child: BigButton(tr(l, 'Close', 'ಮುಚ್ಚಿ'), icon: Icons.close_rounded, bg: Colors.white, fg: S.ink, border: S.line, height: 128, size: 36),
                    ),
                  ],
                ),
                SizedBox(height: narrow ? 30 : 46),
                Flexible(
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: cols,
                    mainAxisSpacing: 30,
                    crossAxisSpacing: 30,
                    childAspectRatio: narrow ? 1.2 : 1.45,
                    children: [
                      for (final (k, bg, icon, title, sub) in items)
                        Tap(
                          key: ValueKey('insert-${k.name}'),
                          onTap: () => Navigator.pop(ctx, k),
                          child: PastelCard(bg: bg, icon: icon, title: title, sub: sub, lang: l, titleSize: narrow ? 44 : 56, pad: narrow ? 30 : 44, iconSize: narrow ? 96 : 120),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: SafeLine(
                        tr(l, 'All of these work without internet. You can Undo anything you put on.', 'ಇವೆಲ್ಲವೂ ಇಂಟರ್ನೆಟ್ ಇಲ್ಲದೆ ಕೆಲಸ ಮಾಡುತ್ತವೆ. ನೀವು ಹಾಕಿದ ಯಾವುದನ್ನೂ ರದ್ದುಮಾಡಬಹುದು.'),
                        size: 32,
                      ),
                    ),
                    // The full KINETIX board app, when this board has it.
                    FutureBuilder<bool>(
                      future: kinetix,
                      builder: (_, snap) => snap.data == true
                          ? Tap(
                              key: const ValueKey('openKinetix'),
                              onTap: () => Apps.launch(Apps.kinetixBoard),
                              child: WbTag(tr(l, 'Open the KINETIX board app', 'KINETIX ಬೋರ್ಡ್ ಆ್ಯಪ್ ತೆರೆಯಿರಿ'), icon: Icons.open_in_new_rounded, bg: S.soft, size: 30),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);

/// A full-screen picker with a title and Close.
Future<T?> _picker<T>(BuildContext context, Lang l, String title, Widget Function(BuildContext ctx) body) => Navigator.of(context).push<T>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (ctx) => Scaffold(
      backgroundColor: S.mist,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: hd(64, l: l)),
                  ),
                  Tap(
                    key: const ValueKey('closePicker'),
                    onTap: () => Navigator.pop(ctx),
                    child: BigButton(tr(l, 'Close', 'ಮುಚ್ಚಿ'), icon: Icons.close_rounded, bg: Colors.white, fg: S.ink, border: S.line, height: 120, size: 36),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: ColoredBox(color: Colors.white, child: body(ctx)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// Picks a 3D model from the Kinetix library (all on the board).
Future<String?> pick3dModel(BuildContext context, Lang l) => _picker<String>(
  context,
  l,
  tr(l, 'Choose a 3D model', '3D ಮಾದರಿ ಆಯ್ಕೆಮಾಡಿ'),
  (ctx) => Theme(
    data: KinetixTheme.board(),
    child: Model3dLibrary(lang: l.name, onPick: (id) => Navigator.pop(ctx, id)),
  ),
);

/// Picks a Kinetix virtual lab.
Future<String?> pickLab(BuildContext context, Lang l) => _picker<String>(
  context,
  l,
  tr(l, 'Choose a virtual lab', 'ವರ್ಚುವಲ್ ಲ್ಯಾಬ್ ಆಯ್ಕೆಮಾಡಿ'),
  (ctx) => Theme(
    data: KinetixTheme.board(),
    child: LabBrowser(lang: l == Lang.kn ? LabLang.kn : LabLang.en, onOpen: (_, e) => Navigator.pop(ctx, e.id)),
  ),
);

/// Picks one of [items] (the chapter's simulations, or any list of kit items).
Future<KitItem?> pickKitItem(BuildContext context, Lang l, String title, List<KitItem> items) => _picker<KitItem>(
  context,
  l,
  title,
  (ctx) => items.isEmpty
      ? Center(
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: Text(
              tr(l, 'This chapter has none. Open a lesson first, or choose a 3D model or a lab.', 'ಈ ಅಧ್ಯಾಯದಲ್ಲಿ ಇಲ್ಲ. ಮೊದಲು ಪಾಠವನ್ನು ತೆರೆಯಿರಿ, ಅಥವಾ 3D ಮಾದರಿ ಅಥವಾ ಲ್ಯಾಬ್ ಆಯ್ಕೆಮಾಡಿ.'),
              textAlign: TextAlign.center,
              style: tx(38, c: S.body),
            ),
          ),
        )
      : GridView.count(
          padding: const EdgeInsets.all(30),
          crossAxisCount: MediaQuery.sizeOf(ctx).width < 2000 ? 2 : 3,
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          childAspectRatio: 1.9,
          children: [
            for (final i in items)
              Tap(
                key: ValueKey('pick-${i.key}'),
                onTap: () => Navigator.pop(ctx, i),
                child: PastelCard(bg: kitColor(i.kind), icon: kitIcon(i.kind), title: i.title.t(l), sub: kitKindName(i.kind).t(l), lang: l, titleSize: 44, compact: true),
              ),
          ],
        ),
);

/// The page templates.
const templates = [
  (BoardBackground.ruled, Icons.notes_rounded, 'Lined', 'ಗೆರೆ'),
  (BoardBackground.grid, Icons.grid_4x4_rounded, 'Grid', 'ಗ್ರಿಡ್'),
  (BoardBackground.graph, Icons.grid_on_rounded, 'Graph paper', 'ಗ್ರಾಫ್ ಕಾಗದ'),
  (BoardBackground.fourLine, Icons.format_line_spacing_rounded, 'Four-line writing', 'ನಾಲ್ಕು ಗೆರೆ'),
  (BoardBackground.kannadaLines, Icons.translate_rounded, 'Kannada lines', 'ಕನ್ನಡ ಗೆರೆಗಳು'),
  (BoardBackground.indiaMap, Icons.map_outlined, 'India map', 'ಭಾರತದ ನಕ್ಷೆ'),
  (BoardBackground.worldMap, Icons.public_rounded, 'World map', 'ವಿಶ್ವ ನಕ್ಷೆ'),
  (BoardBackground.twoColumns, Icons.view_column_outlined, 'Two-column table', 'ಎರಡು ಕಾಲಂ ಕೋಷ್ಟಕ'),
  (BoardBackground.threeColumns, Icons.view_week_outlined, 'Three-column table', 'ಮೂರು ಕಾಲಂ ಕೋಷ್ಟಕ'),
  (BoardBackground.isometric, Icons.change_history_rounded, 'Isometric dots', 'ಐಸೋಮೆಟ್ರಿಕ್'),
  (BoardBackground.ledger, Icons.account_balance_outlined, 'Ledger', 'ಲೆಡ್ಜರ್'),
  (BoardBackground.chalkboard, Icons.dark_mode_outlined, 'Chalkboard', 'ಕಪ್ಪು ಹಲಗೆ'),
];

/// Picks a page template.
Future<BoardBackground?> pickTemplate(BuildContext context, Lang l) => _picker<BoardBackground>(
  context,
  l,
  tr(l, 'Choose a page', 'ಪುಟ ಆಯ್ಕೆಮಾಡಿ'),
  (ctx) => GridView.count(
    padding: const EdgeInsets.all(30),
    crossAxisCount: MediaQuery.sizeOf(ctx).width < 2000 ? 2 : 4,
    mainAxisSpacing: 24,
    crossAxisSpacing: 24,
    childAspectRatio: 1.6,
    children: [
      for (final (bg, icon, en, kn) in templates)
        Tap(
          key: ValueKey('template-${bg.name}'),
          onTap: () => Navigator.pop(ctx, bg),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bg.paper,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: S.line, width: 3),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _PaperPainter(bg))),
                Positioned(
                  left: 24,
                  bottom: 24,
                  child: WbTag(tr(l, en, kn), icon: icon, bg: Colors.white, size: 30),
                ),
              ],
            ),
          ),
        ),
    ],
  ),
);

class _PaperPainter extends CustomPainter {
  _PaperPainter(this.bg);
  final BoardBackground bg;
  @override
  void paint(Canvas canvas, Size size) => paintBoardBackground(canvas, Offset.zero & size, bg, scale: .6);
  @override
  bool shouldRepaint(_PaperPainter old) => old.bg != bg;
}
