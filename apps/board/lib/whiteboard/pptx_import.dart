import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import 'package:kinetix_ink/kinetix_ink.dart';

/// Measured size of a line of slide text on the board.
Size measureText(String text, double size, {bool bold = false}) {
  final p = layoutBoardText(text, size, const Color(0xFF000000), bold: bold);
  final out = p.size;
  p.dispose();
  return out;
}

/// One imported slide: its elements and its paper.
class PptxPage {
  const PptxPage(this.elements, this.background);
  final List<BoardElement> elements;
  final BoardBackground background;
}

/// A shape from a slide, before it becomes a board stroke.
enum ShapeType { rect, roundRect, ellipse, triangle, diamond, parallelogram, arrow, line }

/// A PowerPoint deck as board pages (ported from KINETIX TeachBoard's importer).
class PptxImport {
  final String title;
  final List<PptxPage> pages;

  /// Pictures, charts and diagrams that could not come across (old picture
  /// formats, charts, SmartArt).
  final int skipped;
  const PptxImport(this.title, this.pages, this.skipped);
}

/// Width of an imported slide on the board, in board units.
const pptxPageWidth = 2200.0;

const _emuPerInch = 914400.0;

/// Turns a .pptx file into editable board pages: text keeps its size,
/// weight, colour and place; pictures, simple shapes, lines and tables come
/// across as board elements the teacher can move, resize and write over.
/// Positions follow each slide's layout and master; colours follow the
/// deck's theme. Dark slides open on the chalkboard so light text stays
/// readable. Old .ppt files are not read (save them as .pptx or PDF).
Future<PptxImport> importPptx(Uint8List bytes, {String fallbackTitle = 'Slides', int maxSlides = 80}) async {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('not a .pptx file');
  }
  final deck = _Deck(zip);
  final pres = deck.xml('ppt/presentation.xml');
  if (pres == null) throw const FormatException('not a PowerPoint deck');
  final size = pres.findAllElements('p:sldSz').firstOrNull;
  final cx = double.tryParse(size?.getAttribute('cx') ?? '') ?? 12192000;
  final cy = double.tryParse(size?.getAttribute('cy') ?? '') ?? 6858000;
  final k = pptxPageWidth / cx;
  final rels = deck.rels('ppt/presentation.xml');
  final slidePaths = [for (final s in pres.findAllElements('p:sldId')) ?rels[s.getAttribute('r:id')]];
  deck.loadTheme(rels.values.where((t) => t.contains('theme')).firstOrNull);

  final pages = <PptxPage>[];
  String? firstTitle;
  for (final path in slidePaths.take(maxSlides)) {
    final slide = _Slide(deck, path, k, cx, cy);
    pages.add(slide.build());
    firstTitle ??= slide.title;
    // Let the screen draw between slides.
    await Future<void>.delayed(Duration.zero);
  }
  final core = deck.xml('docProps/core.xml');
  final docTitle = core?.findAllElements('dc:title').firstOrNull?.innerText.trim();
  final title = (docTitle?.isNotEmpty ?? false) ? docTitle! : ((firstTitle?.isNotEmpty ?? false) ? firstTitle! : fallbackTitle);
  return PptxImport(title, pages, deck.skipped);
}

class _Deck {
  final Archive zip;
  int skipped = 0;
  final _xmlCache = <String, XmlDocument?>{};
  final theme = <String, Color>{};

  _Deck(this.zip);

  Uint8List? bytes(String path) => zip.findFile(path)?.content;

  XmlDocument? xml(String path) => _xmlCache.putIfAbsent(path, () {
    final b = bytes(path);
    if (b == null) return null;
    try {
      return XmlDocument.parse(utf8.decode(b, allowMalformed: true));
    } catch (_) {
      return null;
    }
  });

  /// Relationship id → part path, for the part at [path].
  Map<String, String> rels(String path) {
    final dir = path.substring(0, path.lastIndexOf('/') + 1);
    final name = path.substring(path.lastIndexOf('/') + 1);
    final doc = xml('${dir}_rels/$name.rels');
    if (doc == null) return const {};
    return {
      for (final r in doc.findAllElements('Relationship'))
        if (r.getAttribute('Id') case final id?)
          if (r.getAttribute('TargetMode') != 'External') id: _resolve(dir, r.getAttribute('Target') ?? ''),
    };
  }

  static String _resolve(String dir, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final parts = [...dir.split('/').where((p) => p.isNotEmpty)];
    for (final p in target.split('/')) {
      if (p == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (p != '.' && p.isNotEmpty) {
        parts.add(p);
      }
    }
    return parts.join('/');
  }

  void loadTheme(String? path) {
    final doc = path == null ? xml('ppt/theme/theme1.xml') : xml(path);
    final scheme = doc?.findAllElements('a:clrScheme').firstOrNull;
    if (scheme == null) return;
    for (final c in scheme.childElements) {
      final name = c.localName;
      final srgb = c.findElements('a:srgbClr').firstOrNull?.getAttribute('val');
      final sys = c.findElements('a:sysClr').firstOrNull?.getAttribute('lastClr');
      final hex = srgb ?? sys;
      if (hex != null) theme[name] = _hex(hex);
    }
  }

  /// A colour element's colour: an RGB value or a theme colour, with
  /// lightening and darkening applied.
  Color? color(XmlElement? fill) {
    if (fill == null) return null;
    final el = fill.childElements.firstOrNull;
    if (el == null) return null;
    Color? c;
    switch (el.localName) {
      case 'srgbClr':
        c = _hex(el.getAttribute('val') ?? '000000');
      case 'schemeClr':
        final v = el.getAttribute('val') ?? 'tx1';
        final name = switch (v) {
          'tx1' => 'dk1',
          'tx2' => 'dk2',
          'bg1' => 'lt1',
          'bg2' => 'lt2',
          _ => v,
        };
        c = theme[name] ?? (name.startsWith('lt') ? Colors.white : Colors.black);
      case 'sysClr':
        c = _hex(el.getAttribute('lastClr') ?? '000000');
      case 'prstClr':
        c = switch (el.getAttribute('val')) {
          'white' => Colors.white,
          'red' => Colors.red,
          'blue' => Colors.blue,
          'green' => Colors.green,
          _ => Colors.black,
        };
      default:
        return null;
    }
    // lumMod / lumOff (e.g. "a lighter shade of accent 1").
    double? mod, off;
    for (final m in el.childElements) {
      final v = (double.tryParse(m.getAttribute('val') ?? '') ?? 100000) / 100000;
      if (m.localName == 'lumMod') mod = v;
      if (m.localName == 'lumOff') off = v;
    }
    if (mod != null || off != null) {
      final hsl = HSLColor.fromColor(c);
      c = hsl.withLightness((hsl.lightness * (mod ?? 1) + (off ?? 0)).clamp(0.0, 1.0)).toColor();
    }
    return c;
  }

  static Color _hex(String hex) => Color(0xFF000000 | (int.tryParse(hex, radix: 16) ?? 0));
}

/// Maps a slide's EMU coordinates to board units, through any groups.
class _Space {
  final double k;
  final Offset shift;
  final double sx, sy;
  const _Space(this.k, [this.shift = Offset.zero, this.sx = 1, this.sy = 1]);

  Offset point(double x, double y) => Offset((shift.dx + x * sx) * k, (shift.dy + y * sy) * k);
  Rect rect(double x, double y, double w, double h) => Rect.fromPoints(point(x, y), point(x + w, y + h));
  double length(double emu) => emu * k * (sx + sy) / 2;
}

class _Slide {
  final _Deck deck;
  final String path;
  final double k, cx, cy;
  late final Map<String, String> rels = deck.rels(path);
  late final String? layoutPath = rels.values.where((t) => t.contains('slideLayout')).firstOrNull;
  late final String? masterPath = layoutPath == null ? null : deck.rels(layoutPath!).values.where((t) => t.contains('slideMaster')).firstOrNull;
  String? title;
  bool dark = false;
  final els = <BoardElement>[];

  _Slide(this.deck, this.path, this.k, this.cx, this.cy);

  PptxPage build() {
    final doc = deck.xml(path);
    final tree = doc?.findAllElements('p:spTree').firstOrNull;
    // The background: this slide's, else its layout's, else its master's.
    for (final p in [path, layoutPath, masterPath]) {
      if (p == null) continue;
      final bg = deck.xml(p)?.findAllElements('p:bg').firstOrNull;
      if (bg == null) continue;
      _background(bg, p);
      break;
    }
    if (tree != null) _tree(tree, _Space(k));
    return PptxPage(els, dark ? BoardBackground.chalkboard : BoardBackground.plain);
  }

  void _background(XmlElement bg, String part) {
    final pr = bg.findElements('p:bgPr').firstOrNull;
    final solid = pr?.findElements('a:solidFill').firstOrNull;
    final c = solid != null ? deck.color(solid) : null;
    if (c != null) dark = c.computeLuminance() < 0.25;
    final blip = pr?.findAllElements('a:blip').firstOrNull;
    if (blip != null) {
      final img = _media(part, blip.getAttribute('r:embed'));
      if (img != null) els.add(ImageElement(id: newElementId(), rect: Rect.fromLTWH(0, 0, cx * k, cy * k), bytes: img, backdrop: true));
    }
    final ref = bg.findElements('p:bgRef').firstOrNull;
    if (c == null && ref != null) {
      final rc = deck.color(ref);
      if (rc != null) dark = rc.computeLuminance() < 0.25;
    }
  }

  Uint8List? _media(String part, String? id) {
    if (id == null) return null;
    final target = deck.rels(part)[id];
    if (target == null) return null;
    final ext = target.split('.').last.toLowerCase();
    if (!const {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'}.contains(ext)) {
      deck.skipped++;
      return null;
    }
    return deck.bytes(target);
  }

  void _tree(XmlElement tree, _Space space) {
    for (final node in tree.childElements) {
      switch (node.localName) {
        case 'sp' || 'cxnSp':
          _shape(node, space);
        case 'pic':
          _picture(node, space);
        case 'grpSp':
          _group(node, space);
        case 'graphicFrame':
          _frame(node, space);
      }
    }
  }

  void _group(XmlElement g, _Space space) {
    final x = g.findElements('p:grpSpPr').firstOrNull?.findElements('a:xfrm').firstOrNull;
    if (x == null) return _tree(g, space);
    final off = _pair(x, 'a:off', 'x', 'y'), ext = _pair(x, 'a:ext', 'cx', 'cy');
    final chOff = _pair(x, 'a:chOff', 'x', 'y'), chExt = _pair(x, 'a:chExt', 'cx', 'cy');
    final sx = chExt.$1 == 0 ? 1.0 : ext.$1 / chExt.$1, sy = chExt.$2 == 0 ? 1.0 : ext.$2 / chExt.$2;
    // child → group: off + (p - chOff) * s, then through the outer space.
    final inner = _Space(k, Offset(space.shift.dx + (off.$1 - chOff.$1 * sx) * space.sx, space.shift.dy + (off.$2 - chOff.$2 * sy) * space.sy), space.sx * sx, space.sy * sy);
    _tree(g, inner);
  }

  (double, double) _pair(XmlElement x, String tag, String a, String b) {
    final e = x.findElements(tag).firstOrNull;
    return (double.tryParse(e?.getAttribute(a) ?? '') ?? 0, double.tryParse(e?.getAttribute(b) ?? '') ?? 0);
  }

  /// The box and turn of a shape; a placeholder without its own box takes
  /// the one its layout (or master) gives it.
  (Rect, double)? _box(XmlElement node, _Space space) {
    var x = node.findElements('p:xfrm').firstOrNull ?? node.findAllElements('a:xfrm').firstOrNull;
    final ph = node.findAllElements('p:ph').firstOrNull;
    if (x == null && ph != null) x = _inheritedXfrm(ph);
    if (x == null) return null;
    final off = _pair(x, 'a:off', 'x', 'y'), ext = _pair(x, 'a:ext', 'cx', 'cy');
    final rot = (double.tryParse(x.getAttribute('rot') ?? '') ?? 0) / 60000 * math.pi / 180;
    var r = space.rect(off.$1, off.$2, ext.$1, ext.$2);
    if (x.getAttribute('flipH') == '1' || x.getAttribute('flipV') == '1') r = Rect.fromLTRB(r.left, r.top, r.right, r.bottom);
    return (r, rot);
  }

  XmlElement? _inheritedXfrm(XmlElement ph) {
    for (final sp in _placeholders(ph)) {
      final x = sp.findAllElements('a:xfrm').firstOrNull;
      if (x != null) return x;
    }
    return null;
  }

  /// The layout's and then the master's shapes for placeholder [ph].
  List<XmlElement> _placeholders(XmlElement ph) {
    final type = ph.getAttribute('type') ?? 'body';
    final idx = ph.getAttribute('idx');
    final out = <XmlElement>[];
    for (final part in [layoutPath, masterPath]) {
      if (part == null) continue;
      final tree = deck.xml(part)?.findAllElements('p:spTree').firstOrNull;
      if (tree == null) continue;
      XmlElement? match;
      for (final sp in tree.findAllElements('p:sp')) {
        final other = sp.findAllElements('p:ph').firstOrNull;
        if (other == null) continue;
        final oType = other.getAttribute('type') ?? 'body';
        final sameIdx = idx != null && other.getAttribute('idx') == idx;
        final sameType = oType == type || (type == 'ctrTitle' && oType == 'title') || (type == 'subTitle' && oType == 'body');
        if (sameIdx && part == layoutPath) {
          match = sp;
          break;
        }
        if (sameType) match ??= sp;
      }
      if (match != null) out.add(match);
    }
    return out;
  }

  /// Where a shape's paragraph styles come from, nearest first: its own
  /// list style, its layout's and master's placeholders, then the master's
  /// title, body or other text style.
  List<XmlElement> _styleChain(XmlElement node, XmlElement? ph) {
    final chain = <XmlElement>[];
    void add(XmlElement? sp) {
      final ls = sp?.findAllElements('a:lstStyle').firstOrNull;
      if (ls != null) chain.add(ls);
    }

    add(node);
    if (ph != null) {
      for (final sp in _placeholders(ph)) {
        add(sp);
      }
    }
    final styles = masterPath == null ? null : deck.xml(masterPath!)?.findAllElements('p:txStyles').firstOrNull;
    final type = ph?.getAttribute('type');
    final which = ph == null ? 'p:otherStyle' : (type == 'title' || type == 'ctrTitle' ? 'p:titleStyle' : 'p:bodyStyle');
    final master = styles?.findElements(which).firstOrNull;
    if (master != null) chain.add(master);
    return chain;
  }

  /// The body properties (anchoring) of a shape, or of its placeholder.
  String _anchor(XmlElement node, XmlElement? ph) {
    for (final sp in [node, if (ph != null) ..._placeholders(ph)]) {
      final a = sp.findAllElements('a:bodyPr').firstOrNull?.getAttribute('anchor');
      if (a != null) return a;
    }
    return 't';
  }

  void _picture(XmlElement node, _Space space) {
    final box = _box(node, space);
    final blip = node.findAllElements('a:blip').firstOrNull;
    if (box == null || blip == null) return;
    final img = _media(path, blip.getAttribute('r:embed'));
    if (img == null) return;
    els.add(ImageElement(id: newElementId(), rect: box.$1, bytes: img, rotation: box.$2));
  }

  void _frame(XmlElement node, _Space space) {
    final tbl = node.findAllElements('a:tbl').firstOrNull;
    if (tbl == null) {
      deck.skipped++; // a chart or a diagram
      return;
    }
    final box = _box(node, space);
    if (box == null) return;
    final cols = [for (final g in tbl.findAllElements('a:gridCol')) space.length(double.tryParse(g.getAttribute('w') ?? '') ?? 0)];
    var y = box.$1.top;
    final ink = dark ? Colors.white : const Color(0xFF1B1F24);
    for (final tr in tbl.findElements('a:tr')) {
      final h = space.length(double.tryParse(tr.getAttribute('h') ?? '') ?? 370840);
      var x = box.$1.left;
      var rowH = h;
      final cells = tr.findElements('a:tc').toList();
      for (final (i, tc) in cells.indexed) {
        final w = i < cols.length ? cols[i] : (box.$1.width / math.max(1, cells.length));
        final cell = Rect.fromLTWH(x, y, w, h);
        final used = _text(tc, cell, space, defaultSize: 18, defaultColor: ink, chain: [?tc.findAllElements('a:lstStyle').firstOrNull], insets: true);
        rowH = math.max(rowH, used);
        x += w;
      }
      x = box.$1.left;
      for (final (i, _) in cells.indexed) {
        final w = i < cols.length ? cols[i] : (box.$1.width / math.max(1, cells.length));
        els.add(_stroke(ShapeType.rect, Offset(x, y), Offset(x + w, y + rowH), dark ? Colors.white70 : const Color(0xFF8A939C), 1.5));
        x += w;
      }
      y += rowH;
    }
  }

  void _shape(XmlElement node, _Space space) {
    final ph = node.findAllElements('p:ph').firstOrNull;
    final phType = ph?.getAttribute('type');
    // Date, footer and slide number placeholders are noise on a board.
    if (const {'dt', 'ftr', 'sldNum'}.contains(phType)) return;
    final box = _box(node, space);
    if (box == null) return;
    final (rect, rot) = box;
    final spPr = node.findElements('p:spPr').firstOrNull;
    final geom = spPr?.findElements('a:prstGeom').firstOrNull?.getAttribute('prst');
    final fill = spPr?.findElements('a:solidFill').firstOrNull;
    final line = spPr?.findElements('a:ln').firstOrNull;
    final noLine = line?.findElements('a:noFill').isNotEmpty ?? false;
    final lineColor = line == null ? null : deck.color(line.findElements('a:solidFill').firstOrNull);
    final fillColor = deck.color(fill);
    final isLine = node.localName == 'cxnSp' || geom == 'line' || geom == 'straightConnector1';
    final type = switch (geom) {
      'rect' => ShapeType.rect,
      'roundRect' || 'snipRoundRect' => ShapeType.roundRect,
      'ellipse' => ShapeType.ellipse,
      'triangle' || 'rtTriangle' => ShapeType.triangle,
      'diamond' => ShapeType.diamond,
      'parallelogram' => ShapeType.parallelogram,
      'rightArrow' || 'leftArrow' => ShapeType.arrow,
      'line' || 'straightConnector1' => ShapeType.line,
      _ => null,
    };
    final visible = (fillColor != null || (lineColor != null && !noLine)) && ph == null;
    if (isLine) {
      final head = line?.findElements('a:tailEnd').firstOrNull?.getAttribute('type');
      final w = space.length(double.tryParse(line?.getAttribute('w') ?? '') ?? 19050);
      final x = node.findAllElements('a:xfrm').firstOrNull;
      final fh = x?.getAttribute('flipH') == '1', fv = x?.getAttribute('flipV') == '1';
      final a = Offset(fh ? rect.right : rect.left, fv ? rect.bottom : rect.top);
      final b = Offset(fh ? rect.left : rect.right, fv ? rect.top : rect.bottom);
      els.add(_stroke(head != null && head != 'none' ? ShapeType.arrow : ShapeType.line, a, b, lineColor ?? (dark ? Colors.white : Colors.black), math.max(2, w)));
      return;
    }
    if (visible && type != null) {
      els.add(
        _stroke(
          type,
          rect.topLeft,
          rect.bottomRight,
          (lineColor != null && !noLine) ? lineColor : fillColor!,
          math.max(2, space.length(double.tryParse(line?.getAttribute('w') ?? '') ?? 19050)),
          fill: fillColor,
          rotation: rot,
        ),
      );
    } else if (visible) {
      deck.skipped++; // a shape the board has no match for: its text still comes
    }
    final isTitle = phType == 'title' || phType == 'ctrTitle';
    final size = isTitle ? (phType == 'ctrTitle' ? 44.0 : 36.0) : (ph != null ? 24.0 : 18.0);
    // Text on a solid shape is read against the shape, not the board.
    final onFill = fillColor != null && type != null;
    final fillDark = onFill && fillColor.computeLuminance() < 0.4;
    // Shapes' own text colour (their style's font colour).
    final styleFont = deck.color(node.findElements('p:style').firstOrNull?.findElements('a:fontRef').firstOrNull);
    final ink = styleFont ?? (dark || fillDark ? Colors.white : const Color(0xFF1B1F24));
    final used = _text(
      node,
      rect,
      space,
      defaultSize: size,
      defaultColor: ink,
      chain: _styleChain(node, ph),
      anchor: _anchor(node, ph),
      background: onFill ? fillColor : null,
      insets: true,
      rotation: rot,
    );
    if (isTitle && title == null) {
      final t = node.findAllElements('a:t').map((e) => e.innerText).join(' ').trim();
      if (t.isNotEmpty) title = t;
    }
    if (used == 0 && ph != null) return;
  }

  /// The text of a shape or table cell, laid out in [box]. Returns the
  /// height it took. [chain] gives inherited paragraph styles (nearest
  /// first); [background] is the solid fill behind the text, if any.
  double _text(
    XmlElement node,
    Rect box,
    _Space space, {
    required double defaultSize,
    required Color defaultColor,
    List<XmlElement> chain = const [],
    String anchor = 't',
    Color? background,
    bool insets = false,
    double rotation = 0,
  }) {
    final body = node.findElements('p:txBody').firstOrNull ?? node.findElements('a:txBody').firstOrNull;
    if (body == null) return 0;
    final bodyPr = body.findElements('a:bodyPr').firstOrNull;
    final scale = (double.tryParse(bodyPr?.findElements('a:normAutofit').firstOrNull?.getAttribute('fontScale') ?? '') ?? 100000) / 100000;
    final anchorAt = bodyPr?.getAttribute('anchor') ?? anchor;
    final inset = insets ? space.length(91440) : 0.0;
    final inner = Rect.fromLTRB(box.left + inset, box.top + inset / 2, math.max(box.left + inset + 40, box.right - inset), box.bottom - inset / 2);
    T? inherit<T>(int level, T? Function(XmlElement pPr) read) {
      for (final ls in chain) {
        final e = ls.findElements('a:lvl${level + 1}pPr').firstOrNull;
        if (e == null) continue;
        final v = read(e);
        if (v != null) return v;
      }
      return null;
    }

    // Each paragraph: its lines, size, weight, colour, alignment and indent.
    final paras = <(List<String>, double, bool, Color, String, double)>[];
    for (final p in body.findElements('a:p')) {
      final pPr = p.findElements('a:pPr').firstOrNull;
      final level = int.tryParse(pPr?.getAttribute('lvl') ?? '') ?? 0;
      final runs = [...p.findElements('a:r'), ...p.findElements('a:fld')];
      final text = runs.map((r) => r.findElements('a:t').firstOrNull?.innerText ?? '').join().replaceAll('\u000b', '\n');
      final rPr = runs.firstOrNull?.findElements('a:rPr').firstOrNull ?? p.findElements('a:endParaRPr').firstOrNull;
      final inheritedSz = inherit(level, (e) => double.tryParse(e.findElements('a:defRPr').firstOrNull?.getAttribute('sz') ?? ''));
      final pt = (double.tryParse(rPr?.getAttribute('sz') ?? '') ?? inheritedSz ?? (defaultSize - level * 2) * 100) / 100 * scale;
      // Board units: 1 pt is 1/72 inch.
      final size = (pt * _emuPerInch / 72 * k).clamp(8.0, 200.0);
      if (text.trim().isEmpty) {
        paras.add((const [''], size * 0.6, false, defaultColor, 'l', 0));
        continue;
      }
      final bold = rPr?.getAttribute('b') == '1' || (rPr?.getAttribute('b') == null && inherit(level, (e) => e.findElements('a:defRPr').firstOrNull?.getAttribute('b')) == '1');
      final color =
          deck.color(rPr?.findElements('a:solidFill').firstOrNull) ??
          inherit(level, (e) => deck.color(e.findElements('a:defRPr').firstOrNull?.findElements('a:solidFill').firstOrNull)) ??
          defaultColor;
      final algn = pPr?.getAttribute('algn') ?? inherit(level, (e) => e.getAttribute('algn')) ?? 'l';
      // A bullet when this paragraph (or its style) has one, and nothing
      // nearer says none.
      bool? own(XmlElement? e) => e == null
          ? null
          : e.findElements('a:buNone').isNotEmpty
          ? false
          : (e.findElements('a:buChar').isNotEmpty || e.findElements('a:buAutoNum').isNotEmpty ? true : null);
      final bullet = own(pPr) ?? inherit(level, own) ?? false;
      final indent = level * size * 1.4;
      final mark = bullet ? '•  ' : '';
      final lines = _wrap('$mark$text', size, bold, inner.width - indent);
      paras.add((lines, size, bold, _readable(color, background), algn, indent));
    }
    if (paras.every((p) => p.$1.every((l) => l.trim().isEmpty))) return 0;
    var height = 0.0;
    for (final (lines, size, _, _, _, _) in paras) {
      height += lines.length * size * 1.25 + size * 0.25;
    }
    var y = switch (anchorAt) {
      'ctr' => inner.top + math.max(0, (inner.height - height) / 2),
      'b' => inner.top + math.max(0, inner.height - height),
      _ => inner.top,
    };
    final center = box.center;
    for (final (lines, size, bold, color, algn, indent) in paras) {
      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          final m = measureText(line, size, bold: bold);
          final x = switch (algn) {
            'ctr' => inner.center.dx - m.width / 2,
            'r' => inner.right - m.width,
            _ => inner.left + indent,
          };
          var el = TextElement(id: newElementId(), position: Offset(x, y), text: line, color: color, fontSize: size, size: m, bold: bold);
          if (rotation != 0) el = el.rotated(center, rotation);
          els.add(el);
        }
        y += size * 1.25;
      }
      y += size * 0.25;
    }
    return height + inset;
  }

  /// Light text on a light board (or dark on the chalkboard) is turned so it
  /// can be read.
  Color _readable(Color c, [Color? background]) {
    final l = c.computeLuminance();
    final backDark = background != null ? background.computeLuminance() < 0.4 : dark;
    if (!backDark && l > 0.75) return const Color(0xFF1B1F24);
    if (backDark && l < 0.08) return Colors.white;
    return c;
  }

  /// Breaks [text] into lines no wider than [width].
  static List<String> _wrap(String text, double size, bool bold, double width) {
    final out = <String>[];
    for (final para in text.split('\n')) {
      var line = '';
      for (final word in para.split(' ')) {
        final next = line.isEmpty ? word : '$line $word';
        if (line.isNotEmpty && measureText(next, size, bold: bold).width > width) {
          out.add(line);
          line = word;
        } else {
          line = next;
        }
      }
      out.add(line);
    }
    return out;
  }
}

/// A slide shape as a board stroke (so it moves, erases and undoes like ink).
Stroke _stroke(ShapeType type, Offset a, Offset b, Color color, double width, {Color? fill, double rotation = 0}) {
  final kind = switch (type) {
    ShapeType.rect || ShapeType.roundRect => ShapeKind.rectangle,
    ShapeType.ellipse => ShapeKind.ellipse,
    ShapeType.triangle => ShapeKind.triangle,
    ShapeType.diamond => ShapeKind.rhombus,
    ShapeType.parallelogram => ShapeKind.parallelogram,
    ShapeType.arrow => ShapeKind.arrow,
    ShapeType.line => ShapeKind.line,
  };
  var pts = shapePoints(kind, a, b);
  if (rotation != 0) {
    final c = Rect.fromPoints(a, b).center;
    final cs = math.cos(rotation), sn = math.sin(rotation);
    pts = [for (final p in pts) InkPoint(c.dx + (p.x - c.dx) * cs - (p.y - c.dy) * sn, c.dy + (p.x - c.dx) * sn + (p.y - c.dy) * cs, p.pressure)];
  }
  return Stroke(
    id: newElementId(),
    style: InkStyle(tool: InkTool.shape, color: color, width: width, shape: kind),
    points: pts,
    shape: kind,
    fill: kind == ShapeKind.line || kind == ShapeKind.arrow ? null : fill,
    turn: rotation,
  );
}
