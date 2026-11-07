import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../core/theme.dart';
import '../../engine/model.dart';
import '../../core/services.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'strings.dart';

/// A chapter's formulas with each one hidden: the class says it aloud, then the teacher taps to
/// reveal it (or Reveal next, in order). A self-test for the whole room.
class FormulaDrillScreen extends StatefulWidget {
  const FormulaDrillScreen({super.key, required this.samples});
  final ClassSamples samples;

  @override
  State<FormulaDrillScreen> createState() => _FormulaDrillScreenState();
}

class _FormulaDrillScreenState extends State<FormulaDrillScreen> {
  int sheet = 0;
  final revealed = <int>{};
  late List<int> order = _order();

  FormulaSheetData get data => widget.samples.formulas[sheet];
  List<int> _order() => [for (var i = 0; i < widget.samples.formulas[sheet].items.length; i++) i];

  void _revealNext() {
    final next = order.where((i) => !revealed.contains(i)).firstOrNull;
    if (next == null) return;
    setState(() => revealed.add(next));
    // Remembered on the board: which formulas this class has drilled.
    ServicesScope.of(context).school.setDrilled(data.items[next].tex, true);
  }

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final narrow = context.narrow, portrait = context.portrait;
      final n = data.items.length;
      return ClassScaffold(
        crumbs: [widget.samples.subject.t(l), widget.samples.year.t(l)],
        title: '${ct('formulaDrill', l)} · ${data.chapter.t(l)}',
        trailing: [if (!narrow) BarChip(ct('revealed', l, {'n': revealed.length, 'm': n}), icon: Icons.visibility_outlined, color: Z.primary, background: Z.tagBg)],
        bottomLeft: [
          BigButton(key: const ValueKey('drillHide'), icon: Icons.visibility_off_outlined, label: ct('hideAll', l), filled: false, collapse: true, onPressed: () => setState(revealed.clear)),
          BigButton(
            icon: Icons.shuffle,
            label: ct('shuffle', l),
            filled: false,
            collapse: true,
            onPressed: () => setState(() {
              order = [...order]..shuffle(math.Random());
              revealed.clear();
            }),
          ),
        ],
        bottomRight: [BigButton(key: const ValueKey('drillNext'), icon: Icons.visibility_outlined, label: ct('revealNext', l), onPressed: revealed.length == n ? null : _revealNext)],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: narrow ? null : 1100,
                  child: narrow
                      ? null
                      : ZSegmented<int>(
                          height: 84,
                          fontSize: 30,
                          items: [for (final (i, s) in widget.samples.formulas.indexed) (i, s.chapter.t(l), ValueKey('sheet-$i'))],
                          selected: sheet,
                          onChanged: (v) => setState(() {
                            sheet = v;
                            revealed.clear();
                            order = _order();
                          }),
                        ),
                ),
                if (!narrow) const SizedBox(width: 32),
                const Icon(Icons.record_voice_over_outlined, size: 40, color: Z.primary),
                const SizedBox(width: 14),
                Expanded(child: Text(ct('sayItFirst', l), style: zText(narrow ? 26 : 32, FontWeight.w500).copyWith(color: Z.ink2), maxLines: 2)),
              ],
            ),
            SizedBox(height: narrow ? 20 : 28),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final cols = portrait ? 1 : 2;
                  final rows = (n / cols).ceil();
                  const gap = 24.0;
                  final h = portrait ? 260.0 : (box.maxHeight - gap * (rows - 1)) / rows;
                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final (k, i) in order.indexed)
                          SizedBox(
                            width: (box.maxWidth - gap * (cols - 1)) / cols,
                            height: h,
                            child: _FormulaCard(
                              key: ValueKey('formula-$i'),
                              no: k + 1,
                              item: data.items[i],
                              lang: l,
                              shown: revealed.contains(i),
                              compact: narrow,
                              onTap: () => setState(() => revealed.contains(i) ? revealed.remove(i) : revealed.add(i)),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FormulaCard extends StatelessWidget {
  const _FormulaCard({super.key, required this.no, required this.item, required this.lang, required this.shown, required this.compact, required this.onTap});
  final int no;
  final FormulaItem item;
  final Lang lang;
  final bool shown, compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texSize = compact ? 40.0 : 66.0;
    final hidden = Container(
      decoration: BoxDecoration(color: Z.segTrack, borderRadius: BorderRadius.circular(Z.radius), border: Border.all(color: Z.line, width: 3)),
      child: CustomPaint(
        painter: _Hatch(),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_outlined, size: 40, color: Z.muted),
              const SizedBox(width: 14),
              Text(ct('tapReveal', lang), style: zText(compact ? 28 : 32, FontWeight.w600).copyWith(color: Z.muted)),
            ],
          ),
        ),
      ),
    );
    final formula = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Math.tex(item.tex, textStyle: TextStyle(fontSize: texSize, color: Z.ink), onErrorFallback: (_) => Text(item.tex, style: zText(30))),
            ),
          ),
        ),
        Text(item.note.t(lang), style: zText(compact ? 24 : 28, FontWeight.w500).copyWith(color: Z.correctLabel), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
    return Material(
      color: shown ? Z.panel : Z.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.panelRadius), side: BorderSide(color: shown ? Z.correct : Z.panel, width: 4)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Z.panelRadius),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 24 : 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: compact ? 64 : 76,
                alignment: Alignment.topCenter,
                child: CircleAvatar(radius: compact ? 30 : 36, backgroundColor: shown ? Z.correct : Z.segTrack, child: shown ? Icon(Icons.check, size: compact ? 32 : 40, color: Colors.white) : Text('$no', style: zText(compact ? 28 : 32, FontWeight.w700).copyWith(color: Z.ink2))),
              ),
              SizedBox(width: compact ? 16 : 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(item.name.t(lang), style: zTitle(compact ? 32 : 40), maxLines: 1, overflow: TextOverflow.ellipsis),
                    SizedBox(height: compact ? 10 : 14),
                    Expanded(child: shown ? formula : hidden),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faint diagonal lines over a hidden formula.
class _Hatch extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Z.track
      ..strokeWidth = 3;
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(Z.radius)));
    for (var x = -s.height; x < s.width; x += 28) {
      c.drawLine(Offset(x, s.height), Offset(x + s.height, 0), p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_Hatch old) => false;
}
