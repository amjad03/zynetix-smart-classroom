import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:kinetix_ink/kinetix_ink.dart' hide Lesson;

import 'wb_widgets.dart';

/// A number line from [from] to [to] centred at [at]: an arrowed line, a tick and a number at
/// each whole step. Plain strokes and text, so the teacher can mark points and jumps on it.
List<BoardElement> numberLine(Offset at, {int from = -10, int to = 10, double width = 1600, Color color = wbInk}) {
  final n = to - from;
  final step = width / n;
  final left = at.dx - width / 2;
  final out = <BoardElement>[
    Stroke(
      id: newElementId(),
      style: InkStyle(tool: InkTool.shape, color: color, width: 6, shape: ShapeKind.doubleArrow),
      points: [InkPoint(left - 60, at.dy), InkPoint(left + width + 60, at.dy)],
      shape: ShapeKind.doubleArrow,
    ),
  ];
  for (var i = 0; i <= n; i++) {
    final x = left + i * step;
    final major = (from + i) % 5 == 0;
    out.add(lineStroke(Offset(x, at.dy - (major ? 26 : 16)), Offset(x, at.dy + (major ? 26 : 16)), color: color, width: major ? 5 : 3));
    final label = '${from + i}';
    final p = layoutBoardText(label, 34, color);
    out.add(TextElement(id: newElementId(), position: Offset(x - p.width / 2, at.dy + 36), text: label, color: color, fontSize: 34, size: p.size));
    p.dispose();
  }
  return out;
}

/// A graph ready to type into: y = 2x + 1 on axes from −10 to 10.
GraphElement newGraph(Offset at, {Color color = wbBlue}) => GraphElement(
  id: newElementId(),
  rect: Rect.fromCenter(center: at, width: 1000, height: 760),
  expression: 'm*x + c',
  params: const {'m': 2, 'c': 1},
  color: color,
  xLabel: 'x',
  yLabel: 'y',
);

/// A picture from a file, scaled to fit [maxSide] board units, centred at [at].
Future<ImageElement?> pictureElement(Uint8List bytes, Offset at, {double maxSide = 1100}) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width.toDouble(), h = frame.image.height.toDouble();
    frame.image.dispose();
    codec.dispose();
    final k = (maxSide / (w > h ? w : h)).clamp(0.05, 2.0);
    return ImageElement(
      id: newElementId(),
      rect: Rect.fromCenter(center: at, width: w * k, height: h * k),
      bytes: bytes,
    );
  } catch (_) {
    return null; // not a picture this board can read
  }
}

/// The words on a page, top to bottom, left to right, for Read aloud.
String pageText(List<BoardElement> els) {
  final texts = <(Offset, String)>[
    for (final e in els)
      if (e is TextElement) (e.position, e.text) else if (e is NoteElement && !e.hidden) (e.rect.topLeft, e.text),
  ];
  texts.sort((a, b) => (a.$1.dy - b.$1.dy).abs() < 20 ? a.$1.dx.compareTo(b.$1.dx) : a.$1.dy.compareTo(b.$1.dy));
  return texts.map((t) => t.$2.replaceAll('•', '').trim()).where((t) => t.isNotEmpty).join('. ');
}
