import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../blocks/math_text.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import 'analysis.dart';
import 'strings.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String paperDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// A printable sheet: questions for the class (or one roll number), and the answer key.
/// Roll numbers only, never names. Printed in English (the PDF engine cannot shape Kannada).
class Worksheet {
  Worksheet({required this.section, required this.date, required this.questions, this.roll, this.topicNames = const {}});
  final String section;
  final DateTime date;
  final List<Question> questions;
  final int? roll;
  final Map<String, String> topicNames;

  String get title => roll == null ? 'Homework' : 'Practice sheet · Roll $roll';
  String get fileName => 'zynetix-${roll == null ? 'homework' : 'practice-roll-$roll'}-${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}.pdf';
}

/// Fonts for paper: Inter for text, Noto Sans Math for symbols it lacks (from kinetix_ui).
Future<pw.ThemeData> worksheetTheme() async {
  Future<pw.Font> f(String name) async => pw.Font.ttf(await rootBundle.load('packages/kinetix_ui/fonts/$name'));
  return pw.ThemeData.withFont(base: await f('Inter-400.ttf'), bold: await f('Inter-700.ttf'), fontFallback: [await f('NotoSansMath-400.ttf')]);
}

/// The PDF: question pages, then an answer-key page.
/// [withKey]: add the answer key on a page of its own after the questions.
Future<Uint8List> buildWorksheetPdf(Worksheet w, {pw.ThemeData? theme, bool withKey = true}) async {
  final th = theme ?? await worksheetTheme();
  final doc = pw.Document(title: '${w.section} · ${w.title} · ${paperDate(w.date)}', author: 'Zynetix');
  pw.Widget header(String what) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          pw.Expanded(child: pw.Text('${w.section} · $what', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
          pw.Text(paperDate(w.date), style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Text(w.roll == null ? 'Roll no: ________' : 'Roll no: ${w.roll}', style: const pw.TextStyle(fontSize: 11)),
      pw.Divider(),
    ],
  );
  doc.addPage(
    pw.MultiPage(
      theme: th,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (ctx) => ctx.pageNumber == 1 ? header(w.title) : pw.SizedBox(),
      footer: (ctx) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('${ctx.pageNumber}', style: const pw.TextStyle(fontSize: 9))),
      build: (ctx) => [
        for (final (i, q) in w.questions.indexed)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (q.passage != null) pw.Container(padding: const pw.EdgeInsets.all(6), color: PdfColors.grey200, child: pw.Text(plainMath(q.passage!.en), style: const pw.TextStyle(fontSize: 10))),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(width: 22, child: pw.Text('${i + 1}.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(child: pw.Text(plainMath(q.stem.en), style: const pw.TextStyle(fontSize: 12))),
                  ],
                ),
                pw.SizedBox(height: 4),
                if (q.isNumeric)
                  pw.Padding(padding: const pw.EdgeInsets.only(left: 22), child: pw.Text('Answer: ____________'))
                else
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 22),
                    child: pw.Wrap(
                      spacing: 18,
                      runSpacing: 3,
                      children: [for (final (j, o) in q.options.indexed) pw.Text('(${String.fromCharCode(65 + j)}) ${plainMath(o.en)}', style: const pw.TextStyle(fontSize: 11))],
                    ),
                  ),
                if (q.isMulti) pw.Padding(padding: const pw.EdgeInsets.only(left: 22, top: 2), child: pw.Text('More than one option may be correct.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic))),
              ],
            ),
          ),
      ],
    ),
  );
  if (withKey) {
    doc.addPage(
      pw.MultiPage(
        theme: th,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          header('Answer key'),
          for (final (i, q) in w.questions.indexed)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: 22, child: pw.Text('${i + 1}.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: 70, child: pw.Text(answerKey(q), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(
                    child: pw.Text(
                      [if (w.topicNames[q.topicId] != null) w.topicNames[q.topicId]!, if (q.explanation != null) plainMath(q.explanation!.en)].join(' · '),
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  return doc.save();
}

/// Roll numbers to offer a practice sheet to: stuck on any of the class's weak topics, or
/// under half overall.
List<int> stuckRolls(Services s) {
  final m = s.mastery;
  final out = <int>{
    for (final t in m.weakTopics(n: 10)) ...m.stuck(t),
    for (final r in m.rolls)
      if ((m.rollOverall(r) ?? 1) < 0.5) r,
  };
  return out.toList()..sort();
}

/// Homework sheet: 8–10 questions weighted to the class's weak topics (or a stuck roll
/// number's), previewed, then printed or shared as a PDF with an answer key.
class WorksheetScreen extends StatefulWidget {
  const WorksheetScreen({super.key, this.roll});
  final int? roll;
  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen> {
  late final Services s = ServicesScope.of(context);
  late int? roll = widget.roll;
  late List<Question> qs = _pick();
  late final Map<String, String> names = {for (final t in sectionTopics(s)) t.id: t.topic.title.en};
  final _rnd = Random();
  bool busy = false;

  List<Question> _pick() => pickWorksheet(s, roll: roll, count: 10, rnd: _rnd);

  Worksheet get sheet => Worksheet(section: s.config.sectionLabel, date: s.clock(), questions: qs, roll: roll, topicNames: names);

  Future<void> _out(bool share) async {
    setState(() => busy = true);
    final l = s.config.lang, messenger = ScaffoldMessenger.of(context);
    try {
      final w = sheet, bytes = await buildWorksheetPdf(w);
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: w.fileName);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: w.fileName);
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(it('printFailed', l), style: zText(26))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = s.config.lang, text = Theme.of(context).textTheme;
    final rolls = stuckRolls(s);
    final actions = [
      BigButton(key: const ValueKey('printSheet'), icon: Icons.print_outlined, label: it('print', l), onPressed: qs.isEmpty || busy ? null : () => _out(false)),
      BigButton(key: const ValueKey('shareSheet'), icon: Icons.share_outlined, label: it('share', l), filled: false, onPressed: qs.isEmpty || busy ? null : () => _out(true)),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Z.tap + 16,
        leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(roll == null ? it('worksheet', l) : '${it('practiceSheet', l)} · ${it('roll', l)} $roll', style: text.headlineLarge, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(key: const ValueKey('reshuffle'), iconSize: 56, icon: const Icon(Icons.shuffle), onPressed: () => setState(() => qs = _pick())),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(context.narrow ? 24 : 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${s.config.sectionLabel} · ${paperDate(s.clock())} · ${qs.length} ${it('questions', l)} · ${it('pdfEnglish', l)}', style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      key: const ValueKey('sheetClass'),
                      label: Text(it('wholeClass', l), style: zText(26)),
                      selected: roll == null,
                      onSelected: (_) => setState(() {
                        roll = null;
                        qs = _pick();
                      }),
                    ),
                  ),
                  for (final r in {...rolls, ?widget.roll})
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        key: ValueKey('sheetRoll:$r'),
                        label: Text('${it('roll', l)} $r', style: zText(26)),
                        selected: roll == r,
                        onSelected: (_) => setState(() {
                          roll = r;
                          qs = _pick();
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: qs.isEmpty
                  ? Center(child: Text(it('noQuestions', l), style: text.headlineMedium))
                  : ListView.builder(
                      itemCount: qs.length,
                      itemBuilder: (context, i) {
                        final q = qs[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(radius: 24, child: Text('${i + 1}', style: const TextStyle(fontSize: 24))),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MathText(q.stem.t(l), style: text.bodyLarge),
                                    Text(names[q.topicId] ?? '', style: text.bodyMedium?.copyWith(color: Z.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            context.portrait
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [actions[0], const SizedBox(height: 12), actions[1]])
                : Row(mainAxisAlignment: MainAxisAlignment.end, children: [actions[1], const SizedBox(width: 20), actions[0]]),
          ],
        ),
      ),
    );
  }
}
