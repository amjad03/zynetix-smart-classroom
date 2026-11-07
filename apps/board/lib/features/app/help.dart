import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../engine/model.dart';
import 'kit.dart';

/// An undo a screen offers itself (the ink on a lesson step, the board's last stroke).
class LocalUndo {
  const LocalUndo(this.what, this.run);
  final L10n what;
  final VoidCallback run;
}

/// What "What do I do now?" says on a screen: the next step in plain words, the button to
/// point at with Show me, and an undo the screen offers itself (else the board's last action).
class HelpInfo {
  const HelpInfo({required this.next, this.detail, this.target, this.undo});
  final L10n next;
  final L10n? detail;
  final GlobalKey? target;
  final LocalUndo? Function()? undo;
}

/// The "What do I do now?" button, on every screen. [info] is read when it is tapped, so it
/// always describes the screen as it is now.
class HelpFab extends StatelessWidget {
  const HelpFab({super.key, required this.info, this.size = 40, this.dark = false});
  final HelpInfo Function() info;
  final double size;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final l = ServicesScope.of(context).config.lang;
    return Press(
      key: const ValueKey('help'),
      onTap: () => openHelp(context, info()),
      child: HelpButton(lang: l, size: size, dark: dark),
    );
  }
}

/// A smaller help chip for crowded top bars (class tools): a "?" disc and the words.
class HelpChip extends StatelessWidget {
  const HelpChip({super.key, required this.info});
  final HelpInfo Function() info;
  @override
  Widget build(BuildContext context) {
    final l = ServicesScope.of(context).config.lang;
    final phone = usePhoneLayout(context);
    return Press(
      key: const ValueKey('help'),
      onTap: () => openHelp(context, info()),
      child: Container(
        height: 84,
        padding: const EdgeInsets.fromLTRB(10, 0, 28, 0),
        decoration: BoxDecoration(color: S.violet, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 64, height: 64, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.question_mark_rounded, size: 40, color: S.violet)),
          const SizedBox(width: 14),
          Flexible(child: Text(phone ? tr(l, 'Help', 'ಸಹಾಯ') : tr(l, 'What do I do now?', 'ಈಗ ನಾನು ಏನು ಮಾಡಲಿ?'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(28, c: Colors.white, w: FontWeight.w700, h: 1.1))),
        ]),
      ),
    );
  }
}

/// Opens the help panel from the right: the next step (with Show me), Undo last action, and
/// who to call.
Future<void> openHelp(BuildContext context, HelpInfo info) async {
  final showMe = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x990B0D33),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) => Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: usePhoneLayout(ctx) ? 1 : 1180 / 2880,
        heightFactor: 1,
        child: Material(type: MaterialType.transparency, child: HelpPanel(info: info)),
      ),
    ),
    transitionBuilder: (ctx, a, _, child) => SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
  );
  if (showMe == true && context.mounted && info.target != null) {
    await spotlight(context, info.target!, info.next);
  }
}

class HelpPanel extends StatelessWidget {
  const HelpPanel({super.key, required this.info});
  final HelpInfo info;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return ListenableBuilder(
      listenable: s.school,
      builder: (context, _) {
        final l = s.config.lang;
        final phone = usePhoneLayout(context);
        final local = info.undo?.call();
        final last = s.school.lastUndo;
        final undoWhat = local?.what ?? last?.what;
        final contact = s.school.helpContact;
        return Container(
          padding: EdgeInsets.fromLTRB(phone ? 40 : 80, phone ? 48 : 72, phone ? 40 : 80, phone ? 40 : 64),
          decoration: BoxDecoration(color: Colors.white, borderRadius: phone ? null : const BorderRadius.horizontal(left: Radius.circular(72)), boxShadow: S.shadow),
          child: LayoutBuilder(builder: (context, box) => SingleChildScrollView(child: ConstrainedBox(constraints: BoxConstraints(minHeight: box.maxHeight), child: IntrinsicHeight(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 96, height: 96, decoration: const BoxDecoration(color: S.violet, shape: BoxShape.circle), child: const Icon(Icons.question_mark_rounded, size: 60, color: Colors.white)),
              const SizedBox(width: 28),
              Expanded(child: Text(tr(l, 'What do I do now?', 'ಈಗ ನಾನು ಏನು ಮಾಡಲಿ?'), style: hd(phone ? 56 : 80, l: l))),
              ZxButton(tr(l, 'Close', 'ಮುಚ್ಚಿ'), key: const ValueKey('helpClose'), icon: Icons.close_rounded, bg: S.mist, fg: S.ink, height: 112, size: 34, onTap: () => Navigator.pop(context)),
            ]),
            SizedBox(height: phone ? 36 : 52),
            Container(
              padding: const EdgeInsets.fromLTRB(56, 48, 56, 52),
              decoration: BoxDecoration(color: S.lavender, borderRadius: BorderRadius.circular(56)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(l, 'Your next step', 'ನಿಮ್ಮ ಮುಂದಿನ ಹಂತ'), style: tx(36, c: S.eyebrow, w: FontWeight.w600)),
                const SizedBox(height: 14),
                Text(info.next.t(l), key: const ValueKey('helpNext'), style: hd(phone ? 54 : 76, l: l)),
                if (info.detail != null) ...[const SizedBox(height: 18), Text(info.detail!.t(l), style: tx(36, c: S.cardText))],
                if (info.target != null) ...[
                  const SizedBox(height: 40),
                  ZxButton(tr(l, 'Show me', 'ನನಗೆ ತೋರಿಸಿ'), key: const ValueKey('showMe'), icon: Icons.pan_tool_alt_rounded, bg: S.violet, height: 150, size: 46, shadow: true, onTap: () => Navigator.pop(context, true)),
                ],
              ]),
            ),
            const SizedBox(height: 40),
            _row(
              l,
              Icons.undo_rounded,
              S.peach,
              tr(l, 'Undo last action', 'ಕೊನೆಯ ಕೆಲಸ ರದ್ದುಮಾಡಿ'),
              undoWhat?.t(l) ?? tr(l, 'Nothing to undo yet', 'ರದ್ದುಮಾಡಲು ಏನೂ ಇಲ್ಲ'),
              tr(l, 'Undo', 'ರದ್ದು'),
              const ValueKey('helpUndo'),
              undoWhat == null
                  ? null
                  : () {
                      if (local != null) {
                        local.run();
                      } else {
                        s.school.undo();
                      }
                      toast(context, tr(l, 'Undone: ${undoWhat.en}', 'ರದ್ದಾಯಿತು: ${undoWhat.t(l)}'));
                    },
            ),
            const SizedBox(height: 24),
            _row(
              l,
              Icons.call_rounded,
              S.mint,
              tr(l, 'Call for help', 'ಸಹಾಯಕ್ಕೆ ಕರೆ ಮಾಡಿ'),
              contact.isEmpty ? tr(l, 'Your school can add a contact in Settings', 'ಶಾಲೆ ಸೆಟ್ಟಿಂಗ್ಸ್‌ನಲ್ಲಿ ಸಂಪರ್ಕ ಸೇರಿಸಬಹುದು') : contact,
              tr(l, 'Call', 'ಕರೆ'),
              const ValueKey('helpCall'),
              contact.isEmpty
                  ? null
                  : () => showZxDialog<void>(
                      context,
                      title: tr(l, 'Call for help', 'ಸಹಾಯಕ್ಕೆ ಕರೆ ಮಾಡಿ'),
                      body: (_) => Text(contact, style: hd(72)),
                      actions: (ctx) => [ZxButton(tr(l, 'Close', 'ಮುಚ್ಚಿ'), onTap: () => Navigator.pop(ctx))],
                    ),
            ),
            const Spacer(),
            SafeLine(tr(l, 'You can’t break anything. Every action can be undone.', 'ನೀವು ಏನನ್ನೂ ಹಾಳುಮಾಡಲು ಸಾಧ್ಯವಿಲ್ಲ. ಪ್ರತಿ ಕೆಲಸವನ್ನೂ ರದ್ದುಮಾಡಬಹುದು.'), size: phone ? 28 : 36),
          ]))))),
        );
      },
    );
  }

  Widget _row(Lang l, IconData icon, Color bg, String t, String sub, String btn, Key key, VoidCallback? onTap) => Container(
    padding: const EdgeInsets.fromLTRB(36, 30, 30, 30),
    decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(44)),
    child: Row(children: [
      Container(width: 104, height: 104, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(32)), child: Icon(icon, size: 56, color: S.ink)),
      const SizedBox(width: 32),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: tx(44, c: S.ink, w: FontWeight.w700, h: 1.2)),
          Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(32, c: S.muted)),
        ]),
      ),
      ZxButton(btn, key: key, icon: icon, bg: S.ink, height: 120, size: 36, onTap: onTap),
    ]),
  );
}

/// Points at [target]: the screen dims around it, a ring and a pointing hand on it and a
/// caption. Any tap closes it.
Future<void> spotlight(BuildContext context, GlobalKey target, L10n caption) async {
  final box = target.currentContext?.findRenderObject() as RenderBox?;
  final overlay = Overlay.maybeOf(context);
  if (box == null || overlay == null || !box.attached) return;
  final ob = overlay.context.findRenderObject() as RenderBox;
  final rect = rectIn(ob, box);
  final l = ServicesScope.of(context).config.lang;
  late OverlayEntry e;
  e = OverlayEntry(
    builder: (ctx) => GestureDetector(
      key: const ValueKey('spotlight'),
      behavior: HitTestBehavior.opaque,
      onTap: () => e.remove(),
      child: SpotLayer(hole: rect, caption: caption.t(l), lang: l),
    ),
  );
  overlay.insert(e);
}

/// [box]'s rectangle in [ancestor]'s coordinates (through any scaling between them).
Rect rectIn(RenderBox ancestor, RenderBox box) =>
    Rect.fromPoints(ancestor.globalToLocal(box.localToGlobal(Offset.zero)), ancestor.globalToLocal(box.localToGlobal(box.size.bottomRight(Offset.zero))));

/// The dim with a hole, the pointing hand and a caption card under (or over) the hole.
class SpotLayer extends StatelessWidget {
  const SpotLayer({super.key, required this.hole, required this.caption, required this.lang, this.card});
  final Rect hole;
  final String caption;
  final Lang lang;

  /// A full caption card (the guided tour) instead of the plain caption.
  final Widget? card;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = hole.inflate(24);
      final below = box.maxHeight - h.bottom >= h.top;
      final w = (box.maxWidth - 80).clamp(200.0, 1640.0);
      final left = card != null && box.maxWidth > 2000 ? 140.0 : ((h.center.dx - w / 2).clamp(40.0, box.maxWidth - w - 40)).toDouble();
      final gap = card != null ? 70.0 : 200.0;
      return Stack(children: [
        Positioned.fill(child: CustomPaint(painter: SpotPainter(h))),
        Positioned(
          left: h.center.dx - 40,
          top: below ? h.bottom - 36 : h.top - 220,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: below ? -.35 : 2.8,
              child: const Icon(Icons.pan_tool_alt_rounded, size: 240, color: Colors.white, shadows: [Shadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 10))]),
            ),
          ),
        ),
        Positioned(
          left: left,
          width: w,
          top: below ? h.bottom + gap : 20,
          bottom: below ? 20 : box.maxHeight - h.top + gap,
          child: Align(
            alignment: below ? Alignment.topLeft : Alignment.bottomLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: below ? Alignment.topLeft : Alignment.bottomLeft,
              child: SizedBox(
                width: w,
                child: card ??
                    Container(
                      padding: const EdgeInsets.fromLTRB(56, 44, 56, 44),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(56), boxShadow: S.shadow),
                      child: Text(caption, style: hd(72, l: lang)),
                    ),
              ),
            ),
          ),
        ),
      ]);
    },
  );
}

class SpotPainter extends CustomPainter {
  SpotPainter(this.hole);
  final Rect hole;
  @override
  void paint(Canvas canvas, Size s) {
    final rr = RRect.fromRectAndRadius(hole, Radius.circular((hole.shortestSide / 2).clamp(0, 120)));
    final dim = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & s), Path()..addRRect(rr));
    canvas.drawPath(dim, Paint()..color = const Color(0xE60B0D33));
    canvas.drawRRect(rr.inflate(8), Paint()..color = const Color(0x66FFC857)..style = PaintingStyle.stroke..strokeWidth = 28..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFC857)..style = PaintingStyle.stroke..strokeWidth = 10);
  }

  @override
  bool shouldRepaint(SpotPainter old) => old.hole != hole;
}
