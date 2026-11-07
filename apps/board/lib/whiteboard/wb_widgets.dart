import 'package:flutter/material.dart';
import 'package:kinetix_ink/kinetix_ink.dart' hide Lesson;

import '../engine/model.dart';
import '../features/simple/kit.dart';

/// The board's pen colours and line widths (v9 design).
const wbInk = Color(0xFF1B1D2E), wbBlue = Color(0xFF2457E6), wbRed = Color(0xFFD7263D), wbGreen = Color(0xFF1F9D55);
const wbPurple = Color(0xFF8E44AD), wbOrange = Color(0xFFE67E22);
const wbColours = [wbInk, wbBlue, wbRed, wbGreen, wbPurple, wbOrange];
const wbHighlights = [Color(0x80FFE45C), Color(0x8066E0A3), Color(0x80FF8FB1), Color(0x8070B8FF)];
const wbWidths = [(5.0, 'Thin', 'ತೆಳು'), (9.0, 'Medium', 'ಮಧ್ಯಮ'), (16.0, 'Thick', 'ದಪ್ಪ')];

String colourName(Color c, Lang l) => switch (c.toARGB32()) {
  0xFF1B1D2E => tr(l, 'Black', 'ಕಪ್ಪು'),
  0xFF2457E6 => tr(l, 'Blue', 'ನೀಲಿ'),
  0xFFD7263D => tr(l, 'Red', 'ಕೆಂಪು'),
  0xFF1F9D55 => tr(l, 'Green', 'ಹಸಿರು'),
  0xFF8E44AD => tr(l, 'Purple', 'ನೇರಳೆ'),
  _ => tr(l, 'Orange', 'ಕಿತ್ತಳೆ'),
};

/// Anything tappable on the board screen: a key for tests, a hit area at least as big as the
/// child, and a dimmed look when it cannot be used now.
class Tap extends StatelessWidget {
  const Tap({super.key, required this.child, this.onTap, this.onLongPress, this.label});
  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final String? label;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    enabled: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Opacity(opacity: onTap == null && onLongPress == null ? .4 : 1, child: child),
    ),
  );
}

/// A labelled pill for the top bar (Record, Projector, Read aloud, Phone as remote, Undo).
class Pill extends StatelessWidget {
  const Pill(this.label, this.icon, {super.key, this.dot, this.trailing, this.h = 120, this.size = 34, this.on = false});
  final String label;
  final IconData icon;
  final Color? dot;
  final Widget? trailing;
  final double h, size;
  final bool on;
  @override
  Widget build(BuildContext context) => Container(
    height: h,
    padding: EdgeInsets.symmetric(horizontal: h * .3),
    decoration: BoxDecoration(
      color: on ? S.soft : Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: on ? S.violet : S.line, width: on ? 4 : 3),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot != null
            ? Container(
                width: size * 1.1,
                height: size * 1.1,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              )
            : Icon(icon, size: size * 1.3, color: S.ink),
        SizedBox(width: size * .45),
        Text(
          label,
          style: tx(size, c: S.ink, w: FontWeight.w700, h: 1.1),
        ),
        if (trailing != null) ...[SizedBox(width: size * .5), trailing!],
      ],
    ),
  );
}

/// The board sheet: white, rounded, a soft shadow.
class BoardSheet extends StatelessWidget {
  const BoardSheet({super.key, required this.child, this.radius = 48});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFFFFFFE),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: S.shadowSoft,
      border: Border.all(color: S.line, width: 3),
    ),
    child: child,
  );
}

/// A small picture of a page.
class PageThumb extends StatelessWidget {
  const PageThumb({super.key, required this.page, required this.width, this.on = false});
  final WhiteboardPage page;
  final double width;
  final bool on;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * .625,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: page.background.paper,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: on ? S.violet : S.line, width: on ? 6 : 3),
    ),
    child: page.elements.isEmpty
        ? const SizedBox.expand()
        : IgnorePointer(
            child: WhiteboardView(
              board: SavedBoard(background: page.background, canvas: const Size(2400, 1350), pages: [page.elements]),
            ),
          ),
  );
}

/// What a page's long press offers.
enum PageAction { left, right, duplicate, delete }

/// The pages of the board: tap to open, hold for move / copy / delete, and Add page.
class PagesPanel extends StatelessWidget {
  const PagesPanel({super.key, required this.board, required this.lang, required this.onAdd, required this.onAction, this.vertical = true, this.thumbW = 250, this.title = true});
  final WhiteboardController board;
  final Lang lang;
  final VoidCallback onAdd;
  final void Function(int page, PageAction a) onAction;
  final bool vertical, title;
  final double thumbW;

  Future<void> _menu(BuildContext context, int i) async {
    final l = lang;
    final a = await showModalBottomSheet<PageAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(48))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(l, 'Page ${i + 1}', 'ಪುಟ ${i + 1}'), style: hd(56, l: l)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final (a, icon, en, kn) in [
                    (PageAction.left, Icons.arrow_upward_rounded, 'Move earlier', 'ಮುಂಚೆ ಸರಿಸಿ'),
                    (PageAction.right, Icons.arrow_downward_rounded, 'Move later', 'ನಂತರ ಸರಿಸಿ'),
                    (PageAction.duplicate, Icons.copy_rounded, 'Make a copy', 'ನಕಲು ಮಾಡಿ'),
                    (PageAction.delete, Icons.delete_outline_rounded, 'Delete page', 'ಪುಟ ಅಳಿಸಿ'),
                  ])
                    Tap(
                      key: ValueKey('pageAction-${a.name}'),
                      onTap: () => Navigator.pop(ctx, a),
                      child: ToolButton(tr(l, en, kn), icon, bg: a == PageAction.delete ? S.peach : S.mist, fg: a == PageAction.delete ? S.rust : S.ink, width: 300, height: 150),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (a != null) onAction(i, a);
  }

  @override
  Widget build(BuildContext context) {
    final l = lang;
    final pages = board.pages;
    final th = thumbW * .625;
    Widget thumb(int i) => Tap(
      key: ValueKey('pageThumb-$i'),
      label: tr(l, 'Page ${i + 1}', 'ಪುಟ ${i + 1}'),
      onTap: () => board.goToPage(i),
      onLongPress: () => _menu(context, i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageThumb(key: ValueKey('thumb-${pages[i].id}'), page: pages[i], width: thumbW, on: i == board.pageIndex),
          const SizedBox(height: 8),
          Text(
            tr(l, 'Page ${i + 1}', 'ಪುಟ ${i + 1}'),
            style: tx(28, c: i == board.pageIndex ? S.violet : S.ink, w: FontWeight.w700, h: 1.1),
          ),
        ],
      ),
    );
    final add = Tap(
      key: const ValueKey('newPage'),
      label: tr(l, 'Add page', 'ಪುಟ ಸೇರಿಸಿ'),
      onTap: onAdd,
      child: Container(
        width: thumbW,
        height: th,
        decoration: BoxDecoration(
          color: S.mist,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFC9CCDA), width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: thumbW * .22, color: S.violet),
            Text(
              tr(l, 'Add page', 'ಪುಟ ಸೇರಿಸಿ'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx(thumbW * .12, c: S.violet, w: FontWeight.w700, h: 1.1),
            ),
          ],
        ),
      ),
    );
    if (!vertical) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < pages.length; i++) ...[thumb(i), const SizedBox(width: 20)],
            add,
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), boxShadow: S.shadowSoft),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title) ...[Text(tr(l, 'Pages', 'ಪುಟಗಳು'), style: hd(44, l: l)), const SizedBox(height: 20)],
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < pages.length; i++) ...[thumb(i), const SizedBox(height: 22)],
                  add,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pen's (or highlighter's) colour and thickness, opened from the Pen button.
class PenChooser extends StatelessWidget {
  const PenChooser({super.key, required this.board, required this.lang, required this.onDone});
  final WhiteboardController board;
  final Lang lang;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = lang;
    final hl = board.tool == BoardTool.highlighter;
    final colours = hl ? wbHighlights : wbColours;
    final colour = hl ? board.highlighterColor : board.penColor;
    final width = hl ? board.highlighterWidth : board.penWidth;
    Widget box(Widget child, bool on, {double w = 84, double h = 84, Key? key, VoidCallback? onTap}) => Tap(
      key: key,
      onTap: onTap,
      child: Container(
        width: w,
        height: h,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: on ? S.soft : S.mist,
          borderRadius: BorderRadius.circular(24),
          border: on ? Border.all(color: S.ink, width: 4) : null,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
    return Container(
      key: const ValueKey('penChooser'),
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: S.shadow,
        border: Border.all(color: S.line, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hl ? tr(l, 'Highlighter colour', 'ಹೈಲೈಟರ್ ಬಣ್ಣ') : tr(l, 'Pen colour', 'ಪೆನ್ ಬಣ್ಣ'),
            style: tx(28, c: S.eyebrow, w: FontWeight.w700, h: 1.1),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in colours)
                box(
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: c.withValues(alpha: 1), shape: BoxShape.circle),
                  ),
                  c.toARGB32() == colour.toARGB32(),
                  key: ValueKey('colour-${c.toARGB32().toRadixString(16)}'),
                  onTap: () => hl ? board.setHighlighter(color: c) : board.setPen(color: c),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            tr(l, 'Thickness', 'ದಪ್ಪ'),
            style: tx(28, c: S.eyebrow, w: FontWeight.w700, h: 1.1),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (w, en, kn) in wbWidths)
                box(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: w * 1.4,
                        decoration: BoxDecoration(color: wbInk, borderRadius: BorderRadius.circular(99)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr(l, en, kn),
                        style: tx(26, c: S.ink, w: FontWeight.w600, h: 1),
                      ),
                    ],
                  ),
                  w == width,
                  w: 170,
                  h: 100,
                  key: ValueKey('width-$en'),
                  onTap: () => hl ? board.setHighlighter(width: w) : board.setPen(width: w),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Tap(
              key: const ValueKey('penChooserDone'),
              onTap: onDone,
              child: WbTag(tr(l, 'Done', 'ಆಯಿತು'), icon: Icons.check_rounded, bg: S.soft, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

/// A help step: a tick, a ring with its number, and the words.
class HelpStep extends StatelessWidget {
  const HelpStep(this.n, this.text, {super.key, this.done = false, this.size = 30});
  final int n;
  final String text;
  final bool done;
  final double size;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: size * .6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: size * 1.9,
          height: size * 1.9,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done ? S.green : S.violet),
          alignment: Alignment.center,
          child: done
              ? Icon(Icons.check_rounded, size: size * 1.3, color: Colors.white)
              : Text(
                  '$n',
                  style: tx(size * .9, c: Colors.white, w: FontWeight.w700, h: 1),
                ),
        ),
        SizedBox(width: size * .7),
        Expanded(
          child: Text(text, style: tx(size, c: S.cardText, h: 1.4)),
        ),
      ],
    ),
  );
}

/// "What do I do now?": a few plain steps for what is on the screen.
Future<void> showBoardHelp(BuildContext context, Lang l, String title, List<String> steps, {VoidCallback? readAloud}) => showDialog<void>(
  context: context,
  builder: (ctx) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(56)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1500),
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(l, 'What do I do now?', 'ಈಗ ನಾನು ಏನು ಮಾಡಲಿ?'),
                style: tx(30, c: S.eyebrow, w: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(title, style: hd(64, l: l)),
              const SizedBox(height: 36),
              for (final (i, s) in steps.indexed) HelpStep(i + 1, s, size: 38),
              const SizedBox(height: 12),
              SafeLine(tr(l, 'You cannot break anything. Undo takes back the last change.', 'ನೀವು ಏನನ್ನೂ ಹಾಳುಮಾಡಲು ಸಾಧ್ಯವಿಲ್ಲ. ರದ್ದುಮಾಡು ಕೊನೆಯ ಬದಲಾವಣೆಯನ್ನು ಹಿಂಪಡೆಯುತ್ತದೆ.')),
              const SizedBox(height: 36),
              Row(
                children: [
                  if (readAloud != null) ...[
                    Tap(
                      key: const ValueKey('helpRead'),
                      onTap: readAloud,
                      child: BigButton(tr(l, 'Read it to me', 'ನನಗೆ ಓದಿ ಹೇಳಿ'), icon: Icons.volume_up_rounded, bg: Colors.white, fg: S.ink, border: S.line, height: 120, size: 36),
                    ),
                    const SizedBox(width: 24),
                  ],
                  const Spacer(),
                  Tap(
                    key: const ValueKey('helpClose'),
                    onTap: () => Navigator.pop(ctx),
                    child: BigButton(tr(l, 'Got it', 'ಸರಿ'), icon: Icons.check_rounded, bg: S.violet, height: 120, size: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// Asks before something that cannot be taken back easily; true when the teacher agrees.
Future<bool> confirmBoard(BuildContext context, Lang l, String title, String sub, String yes) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(56)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: hd(64, l: l)),
                const SizedBox(height: 16),
                Text(sub, style: tx(36, c: S.body)),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tap(
                      key: const ValueKey('confirmNo'),
                      onTap: () => Navigator.pop(ctx, false),
                      child: BigButton(tr(l, 'Keep it', 'ಹಾಗೆಯೇ ಇರಲಿ'), bg: Colors.white, fg: S.ink, border: S.line, height: 120, size: 36),
                    ),
                    const SizedBox(width: 24),
                    Tap(
                      key: const ValueKey('confirmYes'),
                      onTap: () => Navigator.pop(ctx, true),
                      child: BigButton(yes, icon: Icons.delete_outline_rounded, bg: S.rust, height: 120, size: 36),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ) ??
    false;

/// A rounded tag whose words shorten with an ellipsis when room is short (the kit's Tag does not).
class WbTag extends StatelessWidget {
  const WbTag(this.text, {super.key, this.size = 30, this.bg = const Color(0xBFFFFFFF), this.fg = S.ink, this.icon});
  final String text;
  final double size;
  final Color bg, fg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: size * .8, vertical: size * .38),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: size * 1.2, color: fg), SizedBox(width: size * .35)],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tx(size, c: fg, w: FontWeight.w500, h: 1.2),
          ),
        ),
      ],
    ),
  );
}
