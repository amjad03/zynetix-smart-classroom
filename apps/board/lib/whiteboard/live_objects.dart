import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kinetix_ink/kinetix_ink.dart' hide Lesson;

import '../core/services.dart';
import '../engine/model.dart';
import '../features/simple/kit.dart';
import 'wb_widgets.dart' show WbTag;

/// Live board objects: a 3D model, a virtual lab or a lesson simulation placed on a page as a
/// movable, resizable window that keeps working (turn the model, run the lab). Each is stored as
/// a kinetix_ink picture with an [EmbedLink], so it is saved, undone, moved and deleted like any
/// other element; [LiveObjectsLayer] draws the live widget over it.
abstract final class LiveKind {
  static const model3d = EmbedLink.model3d, lab = EmbedLink.lab, sim = 'sim';
  static const all = {model3d, lab, sim};
}

/// A 1 × 1 navy picture: what viewers without live widgets (thumbnails, the saved file) show.
final placeholderPng = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, //
  65, 84, 120, 156, 99, 224, 23, 118, 0, 0, 0, 151, 0, 99, 110, 48, 15, 186, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

/// The element for a live object of [kind] centred at [at]. A model keeps its view in a `v:`
/// preset (so kinetix_ink leaves the flat picture to the live layer).
ImageElement liveObject(String kind, String id, Offset at, {String? preset, Size size = const Size(760, 620)}) => ImageElement(
  id: newElementId(),
  rect: Rect.fromCenter(center: at, width: size.width, height: size.height),
  bytes: placeholderPng,
  link: EmbedLink(kind: kind, id: id, preset: kind == LiveKind.model3d ? (preset ?? 'v:front') : preset),
);

/// A lesson simulation's id: `chapterId|topicId|blockId`.
String simRef(String chapterId, String topicId, String blockId) => '$chapterId|$topicId|$blockId';

bool isLive(BoardElement e) => e is ImageElement && e.link != null && LiveKind.all.contains(e.link!.kind);

/// Short name shown on the object's tag.
String liveLabel(EmbedLink link, Lang l) => switch (link.kind) {
  LiveKind.model3d => '3D · ${link.id}',
  LiveKind.lab => tr(l, 'Lab · ${link.id}', 'ಲ್ಯಾಬ್ · ${link.id}'),
  _ => tr(l, 'Simulation', 'ಸಿಮ್ಯುಲೇಶನ್'),
};

IconData liveIcon(String kind) => switch (kind) {
  LiveKind.model3d => Icons.view_in_ar_rounded,
  LiveKind.lab => Icons.science_outlined,
  _ => Icons.play_circle_outline_rounded,
};

/// Draws each live object of the open page over the board, with its tag, Remove, and corner
/// handles to resize; drag the tag to move it. One undo step per move or resize.
class LiveObjectsLayer extends StatefulWidget {
  const LiveObjectsLayer({super.key, required this.board, required this.view, required this.lang, this.interactive = true});
  final WhiteboardController board;
  final ViewState view;
  final Lang lang;

  /// False on the projector and in recordings: the objects show, without handles.
  final bool interactive;

  @override
  State<LiveObjectsLayer> createState() => _LiveObjectsLayerState();
}

class _LiveObjectsLayerState extends State<LiveObjectsLayer> {
  ImageElement? _before; // the element as it was when a drag began
  String? _focus;

  void _begin(ImageElement e) {
    _before = e;
    setState(() => _focus = e.id);
  }

  void _drag(ImageElement e, Rect r) => widget.board.updateSilently(e.copyWith(rect: r));

  void _end() {
    final before = _before;
    _before = null;
    if (before == null) return;
    final now = widget.board.byId(before.id);
    if (now is! ImageElement || now.rect == before.rect) return;
    widget.board.updateSilently(before);
    widget.board.replace(now); // one undo step for the whole drag
  }

  @override
  Widget build(BuildContext context) {
    final els = widget.board.elements.whereType<ImageElement>().where(isLive).toList();
    if (els.isEmpty) return const SizedBox.shrink();
    final v = widget.view;
    return LayoutBuilder(
      builder: (context, box) {
        final screen = Offset.zero & box.biggest;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final e in els)
              if (_screenRect(e, v).overlaps(screen)) _object(context, e, _screenRect(e, v)),
          ],
        );
      },
    );
  }

  Rect _screenRect(ImageElement e, ViewState v) => Rect.fromPoints(v.toScreen(e.rect.topLeft), v.toScreen(e.rect.bottomRight));

  Widget _object(BuildContext context, ImageElement e, Rect r) {
    final l = widget.lang, link = e.link!;
    final k = (r.shortestSide / 620).clamp(.45, 1.4); // chrome grows and shrinks with the window
    final focus = _focus == e.id && widget.interactive;
    final small = r.shortestSide < 160;
    final body = small ? Icon(liveIcon(link.kind), size: r.shortestSide * .4, color: Colors.white70) : _live(context, link);
    return Positioned.fromRect(
      key: ValueKey('live-${e.id}'),
      rect: r,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) {
                if (_focus != e.id) setState(() => _focus = e.id);
              },
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1340),
                  borderRadius: BorderRadius.circular(36 * k),
                  border: Border.all(color: focus ? S.violet : const Color(0x33FFFFFF), width: 6 * k),
                ),
                child: Center(child: body),
              ),
            ),
          ),
          if (widget.interactive) ...[
            // The tag: drag it to move the object.
            Positioned(
              left: 24 * k,
              top: 24 * k,
              child: GestureDetector(
                key: ValueKey('liveMove-${e.id}'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _begin(e),
                onPanUpdate: (d) {
                  final cur = widget.board.byId(e.id);
                  if (cur is ImageElement) _drag(cur, cur.rect.shift(d.delta / widget.view.scale));
                },
                onPanEnd: (_) => _end(),
                onPanCancel: _end,
                child: WbTag(liveLabel(link, l), icon: liveIcon(link.kind), bg: const Color(0x40FFFFFF), fg: Colors.white, size: 30 * k),
              ),
            ),
            Positioned(
              right: 24 * k,
              bottom: 24 * k,
              child: GestureDetector(
                key: ValueKey('liveRemove-${e.id}'),
                onTap: () => widget.board.removeIds({e.id}),
                child: WbTag(tr(l, 'Remove', 'ತೆಗೆದುಹಾಕಿ'), icon: Icons.close_rounded, bg: const Color(0x40FFFFFF), fg: Colors.white, size: 30 * k),
              ),
            ),
            if (link.kind == LiveKind.model3d && !small)
              Positioned(
                left: 24 * k,
                bottom: 24 * k,
                child: IgnorePointer(
                  child: WbTag(tr(l, 'Drag to turn', 'ತಿರುಗಿಸಲು ಎಳೆಯಿರಿ'), icon: Icons.threesixty_rounded, bg: Colors.white, size: 28 * k),
                ),
              ),
            if (focus) ...[
              for (final a in const [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight]) _handle(e, a, k),
              Positioned(
                right: 0,
                bottom: -96 * k,
                child: IgnorePointer(
                  child: WbTag(tr(l, 'Drag a corner to resize', 'ಗಾತ್ರ ಬದಲಿಸಲು ಮೂಲೆಯನ್ನು ಎಳೆಯಿರಿ'), icon: Icons.open_in_full_rounded, bg: S.violet, fg: Colors.white, size: 30 * k),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _handle(ImageElement e, Alignment a, double k) {
    final d = 64 * k;
    return Align(
      alignment: a,
      child: FractionalTranslation(
        translation: Offset(a.x * .5, a.y * .5),
        child: GestureDetector(
          key: ValueKey('liveResize-${e.id}-${a.x}-${a.y}'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _begin(e),
          onPanUpdate: (u) {
            final cur = widget.board.byId(e.id);
            if (cur is! ImageElement) return;
            final dd = u.delta / widget.view.scale;
            var rr = cur.rect;
            rr = Rect.fromLTRB(
              a.x < 0 ? math.min(rr.left + dd.dx, rr.right - 200) : rr.left,
              a.y < 0 ? math.min(rr.top + dd.dy, rr.bottom - 160) : rr.top,
              a.x > 0 ? math.max(rr.right + dd.dx, rr.left + 200) : rr.right,
              a.y > 0 ? math.max(rr.bottom + dd.dy, rr.top + 160) : rr.bottom,
            );
            _drag(cur, rr);
          },
          onPanEnd: (_) => _end(),
          onPanCancel: _end,
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: S.violet, width: 8 * k),
            ),
          ),
        ),
      ),
    );
  }

  Widget _live(BuildContext context, EmbedLink link) {
    final s = ServicesScope.of(context), l = widget.lang;
    switch (link.kind) {
      case LiveKind.model3d:
        return s.embeds.model3d(
          Block(BlockType.model3d, {
            'id': 'board-${link.id}',
            'modelId': link.id,
            'caption': {'en': ''},
          }),
          l,
        );
      case LiveKind.lab:
        return s.embeds.lab(link.id, link.preset, l);
      default:
        final parts = link.id.split('|');
        if (parts.length == 3) {
          final pack = s.store.byChapter(parts[0]);
          final block = pack?.lessons[parts[1]]?.blocks.where((b) => b.id == parts[2]).firstOrNull;
          if (pack != null && block != null) return s.embeds.simulation(block, pack, l);
        }
        return Text(tr(l, 'This simulation is not on this board', 'ಈ ಸಿಮ್ಯುಲೇಶನ್ ಈ ಬೋರ್ಡ್‌ನಲ್ಲಿ ಇಲ್ಲ'), style: tx(30, c: Colors.white70));
    }
  }
}
