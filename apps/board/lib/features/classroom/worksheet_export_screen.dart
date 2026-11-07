import 'package:flutter/material.dart';

import '../../blocks/math_text.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'strings.dart';

/// A worksheet ready to print: question pages with a roll-number line (never a name), and an
/// answer key on the last page. The preview shows two A4 pages at a size the teacher can check
/// from the board; Print and Export PDF make the file on the board, offline.
class WorksheetExportScreen extends StatefulWidget {
  const WorksheetExportScreen({super.key, required this.samples, this.leftPage = 0, this.rightPage = 2});
  final ClassSamples samples;
  final int leftPage, rightPage;

  @override
  State<WorksheetExportScreen> createState() => _WorksheetExportScreenState();
}

class _WorksheetExportScreenState extends State<WorksheetExportScreen> {
  bool key = true, steps = true;
  late int left = widget.leftPage, right = widget.rightPage;

  List<ClassQuestion> get qs => widget.samples.questions;

  /// Questions per page: five on page one (after the header), four on page two.
  List<List<int>> get pages => [
    [for (var i = 0; i < 5 && i < qs.length; i++) i],
    [for (var i = 5; i < qs.length; i++) i],
  ];
  int get pageCount => pages.length + (key ? 1 : 0);

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final config = ServicesScope.of(context).config;
      final chapter = {for (final q in qs) q.chapter.t(l)}.join(' + ');
      Widget page(int p) => AspectRatio(
        aspectRatio: 1 / 1.414,
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: const [BoxShadow(color: Color(0x2915191C), blurRadius: 24, offset: Offset(0, 8))]),
          padding: const EdgeInsets.fromLTRB(56, 52, 56, 40),
          child: p < pages.length ? _questionsPage(p, l, config.collegeName, chapter) : _keyPage(l),
        ),
      );
      final preview = Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Z.track, borderRadius: BorderRadius.circular(Z.panelRadius)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Column(children: [Expanded(child: page(left)), const SizedBox(height: 14), Text(ct('pageN', l, {'n': left + 1, 'm': pageCount}), style: zText(28, FontWeight.w600).copyWith(color: Z.ink2))])),
            const SizedBox(width: 40),
            Flexible(child: Column(children: [Expanded(child: page(right)), const SizedBox(height: 14), Text(right >= pages.length ? '${ct('pageN', l, {'n': right + 1, 'm': pageCount})} · ${ct('answerKey', l)}' : ct('pageN', l, {'n': right + 1, 'm': pageCount}), style: zText(28, FontWeight.w600).copyWith(color: Z.ink2))])),
          ],
        ),
      );
      final exams = {for (final q in qs) ...q.exams}.toList();
      final rail = ZPanel(
        padding: const EdgeInsets.all(44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(ct('worksheetTitle', l, {'c': chapter}), style: zTitle(40), maxLines: 2),
            const SizedBox(height: 8),
            Text('${ct('questionsN', l, {'n': qs.length})} · ${widget.samples.subject.t(l)} · ${widget.samples.year.t(l)}', style: zText(30, FontWeight.w500).copyWith(color: Z.muted)),
            const SizedBox(height: 28),
            Kicker(ct('pages', l)),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var p = 0; p < pageCount; p++) ...[
                  if (p > 0) const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => setState(() => p < pages.length ? left = p : right = p),
                    child: Container(
                      width: 104,
                      height: 146,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: p == left || p == right ? Z.primary : Z.line, width: p == left || p == right ? 5 : 2)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(p >= pages.length ? Icons.key_outlined : Icons.article_outlined, size: 40, color: p >= pages.length ? Z.correct : Z.ink2),
                          Text('${p + 1}', style: zText(30, FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),
            Kicker(ct('options', l)),
            const SizedBox(height: 6),
            ZSwitchRow(label: ct('includeKey', l), value: key, onChanged: (v) => setState(() => key = v)),
            ZSwitchRow(label: ct('withSteps', l), value: steps, onChanged: (v) => setState(() => steps = v)),
            const SizedBox(height: 20),
            Kicker(ct('mix', l)),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: [for (final e in exams) ZTag.neutral(e)]),
            const Spacer(),
            Row(
              children: [
                Expanded(child: BigButton(key: const ValueKey('wsExport'), icon: Icons.picture_as_pdf_outlined, label: ct('exportPdf', l), filled: false, onPressed: () {})),
                const SizedBox(width: 20),
                Expanded(child: BigButton(key: const ValueKey('wsPrint'), icon: Icons.print_outlined, label: ct('print', l), onPressed: () {})),
              ],
            ),
          ],
        ),
      );
      return ClassScaffold(
        crumbs: [widget.samples.subject.t(l), widget.samples.year.t(l)],
        title: ct('worksheets', l),
        trailing: [BarChip(ct('offline', l), icon: Icons.cloud_off_outlined)],
        body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 13, child: preview), const SizedBox(width: 32), Expanded(flex: 6, child: rail)]),
      );
    },
  );

  static const _ink = Color(0xFF111111);
  TextStyle _p(double s, [FontWeight w = FontWeight.w400]) => zText(s, w).copyWith(color: _ink, height: 1.35);

  Widget _questionsPage(int p, Lang l, String college, String chapter) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (p == 0) ...[
        Text(college, style: _p(24, FontWeight.w600).copyWith(color: Z.muted)),
        Text('${widget.samples.subject.t(l)} · ${widget.samples.year.t(l)} · $chapter', style: zTitle(32).copyWith(color: _ink)),
        const SizedBox(height: 10),
        Text(ct('nameLine', l), style: _p(24)),
        const Divider(height: 32, thickness: 2, color: _ink),
      ],
      for (final i in pages[p]) ...[
        MathText('${i + 1}. ${qs[i].stem.t(l)}', style: _p(25, FontWeight.w500)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Wrap(
            spacing: 24,
            runSpacing: 4,
            children: [for (final (k, o) in qs[i].options.indexed) SizedBox(width: 280, child: MathText('(${'abcd'[k]}) ${o.t(l)}', style: _p(24)))],
          ),
        ),
        const SizedBox(height: 22),
      ],
      const Spacer(),
      Text(ct('pageN', l, {'n': p + 1, 'm': pageCount}), textAlign: TextAlign.center, style: _p(20).copyWith(color: Z.muted)),
    ],
  );

  Widget _keyPage(Lang l) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(ct('answerKey', l), style: zTitle(34).copyWith(color: _ink)),
      const Divider(height: 28, thickness: 2, color: _ink),
      for (final (i, q) in qs.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 56, child: Text('${i + 1}.', style: _p(25, FontWeight.w700))),
              SizedBox(width: 60, child: Text('(${'abcd'[q.answer]})', style: _p(25, FontWeight.w700).copyWith(color: Z.correct))),
              Expanded(child: MathText(steps ? q.steps.take(2).map((s) => s.t(l)).join('  ') : q.options[q.answer].t(l), style: _p(22), maxLines: 2)),
            ],
          ),
        ),
      const Spacer(),
      Text(ct('pageN', l, {'n': pageCount, 'm': pageCount}), textAlign: TextAlign.center, style: _p(20).copyWith(color: Z.muted)),
    ],
  );
}
