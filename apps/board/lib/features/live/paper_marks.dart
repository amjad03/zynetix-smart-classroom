import 'package:flutter/material.dart';

import '../../blocks/math_text.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import '../../engine/session_log.dart';
import 'chapter_picker.dart';
import 'strings.dart';

/// Marks of a written test: for each roll number and question, right (true), wrong (false) or
/// not entered (null). Blank cells are not recorded.
class PaperMarks {
  PaperMarks({required this.rollCount, required this.questionCount});
  final int rollCount, questionCount;
  final Map<int, List<bool?>> _rows = {};

  bool? at(int roll, int q) => _rows[roll]?[q];
  List<bool?> row(int roll) => _rows[roll] ?? List.filled(questionCount, null);

  /// Blank → right → wrong → blank.
  void cycle(int roll, int q) {
    final r = _rows.putIfAbsent(roll, () => List.filled(questionCount, null));
    r[q] = switch (r[q]) {
      null => true,
      true => false,
      false => null,
    };
  }

  /// Every question of [roll] right; a second tap on a full row clears it.
  void allRight(int roll) {
    final full = row(roll).every((v) => v == true);
    _rows[roll] = List.filled(questionCount, full ? null : true);
  }

  /// Roll numbers with at least one mark.
  List<int> get entered => [
    for (var r = 1; r <= rollCount; r++)
      if (row(r).any((v) => v != null)) r,
  ];

  int rightOf(int roll) => row(roll).where((v) => v == true).length;

  /// Every mark: (roll, question index, right).
  Iterable<(int, int, bool)> get marks sync* {
    for (final r in entered) {
      final cells = row(r);
      for (var q = 0; q < cells.length; q++) {
        if (cells[q] != null) yield (r, q, cells[q]!);
      }
    }
  }

  /// Saves the marks as one teacher session (source 'paper'), into the section's mastery.
  void save(SessionRecorder rec, List<Question> questions) {
    for (final (roll, qi, ok) in marks) {
      final q = questions[qi];
      rec.answer(questionId: q.id, mode: QuizMode.monitor, roll: roll, chosen: null, correct: ok, topicId: q.topicId, chapterId: q.chapterId, source: 'paper');
    }
    rec.setPresent(entered.length);
    rec.close(completed: true);
  }
}

/// Paper test marks: pick a chapter test (questions from the installed pack), then for each roll
/// number tap a box per question (right, wrong, blank) or "All right" for the row, and save.
/// Answers go into the section's mastery with source 'paper'.
///
/// With [pack] and [questions] it opens the grid straight away.
class PaperMarksScreen extends StatefulWidget {
  const PaperMarksScreen({super.key, this.pack, this.questions});
  final InstalledPack? pack;
  final List<Question>? questions;

  @override
  State<PaperMarksScreen> createState() => PaperMarksScreenState();
}

class PaperMarksScreenState extends State<PaperMarksScreen> {
  late final Services s = ServicesScope.of(context);
  InstalledPack? pack;
  List<Question>? questions;
  PaperMarks? marks;
  bool saved = false;

  @override
  void initState() {
    super.initState();
    if (widget.questions != null && widget.questions!.isNotEmpty) {
      pack = widget.pack;
      questions = widget.questions;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (questions != null) marks ??= PaperMarks(rollCount: s.config.rollCount, questionCount: questions!.length);
  }

  void pick(InstalledPack p, List<Question> qs) {
    if (qs.isEmpty) return;
    setState(() {
      pack = p;
      questions = qs;
      marks = PaperMarks(rollCount: s.config.rollCount, questionCount: qs.length);
      saved = false;
    });
  }

  bool get dirty => !saved && (marks?.entered.isNotEmpty ?? false);

  void save() {
    final qs = questions!, m = marks!;
    if (m.entered.isEmpty) return;
    final first = qs.first;
    final chapterId = pack?.chapter.id ?? first.chapterId ?? '';
    final rec = SessionRecorder.raw(
      outbox: s.outbox,
      sectionId: s.config.sectionId,
      mode: 'teacher',
      chapterId: chapterId,
      topicId: first.topicId ?? pack?.chapter.topics.firstOrNull?.id ?? chapterId,
      lessonId: 'paper.$chapterId',
      packVersion: pack?.version ?? '0.0.0',
      now: s.clock,
      mastery: s.mastery,
    );
    m.save(rec, qs);
    setState(() => saved = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ltr('marksSaved', s.config.lang), style: zText(28))));
  }

  Future<void> _back() async {
    if (questions != null && widget.questions == null && !dirty) {
      setState(() {
        questions = null;
        marks = null;
      });
      return;
    }
    if (dirty) {
      final l = s.config.lang;
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ltr('discard', l), style: zText(36)),
          actions: [
            BigButton(key: const ValueKey('stay'), icon: Icons.edit_outlined, label: ltr('stay', l), filled: false, onPressed: () => Navigator.pop(ctx, false)),
            BigButton(key: const ValueKey('leave'), icon: Icons.logout, label: ltr('leave', l), color: Z.wrong, onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = s.config.lang, text = Theme.of(context).textTheme;
    final qs = questions;
    return PopScope(
      canPop: qs == null || (!dirty && widget.questions != null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: Z.tap + 16,
          leading: IconButton(key: const ValueKey('paperBack'), iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: qs == null ? () => Navigator.pop(context) : _back),
          title: Text(
            qs == null || pack == null ? ltr('paperMarks', l) : '${pack!.chapter.number}. ${pack!.chapter.title.t(l)}',
            style: context.narrow ? text.headlineMedium : text.headlineLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (qs != null) ...[
              BigButton(collapse: true, key: const ValueKey('showQuestions'), icon: Icons.list_alt, label: ltr('printTest', l), filled: false, onPressed: () => _showQuestions(qs, l)),
              const SizedBox(width: 16),
              BigButton(
                collapse: true,
                key: const ValueKey('saveMarks'),
                icon: saved ? Icons.cloud_done_outlined : Icons.save_outlined,
                label: saved ? ltr('saved', l) : ltr('saveMarks', l),
                color: Z.correct,
                onPressed: saved || (marks?.entered.isEmpty ?? true) ? null : save,
              ),
              const SizedBox(width: 24),
            ],
          ],
        ),
        body: Padding(
          padding: EdgeInsets.all(context.narrow ? 16 : 32),
          child: qs == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(ltr('paperMarksSub', l), style: text.bodyLarge),
                    const SizedBox(height: 16),
                    Expanded(child: ChapterTestPicker(onPick: pick)),
                  ],
                )
              : _grid(qs, l, text),
        ),
      ),
    );
  }

  void _showQuestions(List<Question> qs, Lang l) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ltr('printTest', l), style: zText(36)),
      content: SizedBox(
        width: 1200,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var k = 0; k < qs.length; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: MathText('${ltr('q', l)}${k + 1}. ${qs[k].stem.t(l)}', style: Theme.of(ctx).textTheme.bodyLarge),
              ),
          ],
        ),
      ),
      actions: [BigButton(icon: Icons.close, label: MaterialLocalizations.of(ctx).closeButtonLabel, filled: false, onPressed: () => Navigator.pop(ctx))],
    ),
  );

  static const cell = 88.0, gap = 8.0, rollW = 120.0, allW = 220.0, totalW = 110.0;

  Widget _grid(List<Question> qs, Lang l, TextTheme text) {
    final m = marks!;
    final width = rollW + qs.length * (cell + gap) + allW + totalW + gap * 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 24,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(ltr('paperHelp', l), style: text.bodyMedium),
            Text('${m.entered.length} / ${m.rollCount} ${ltr('entered', l)}', key: const ValueKey('enteredCount'), style: text.bodyLarge?.copyWith(color: Z.muted)),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width < c.maxWidth ? c.maxWidth : width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(width: rollW, child: Text(ltr('q', l), style: text.bodyMedium)),
                        for (var k = 0; k < qs.length; k++)
                          Container(
                            width: cell,
                            margin: const EdgeInsets.only(right: gap),
                            alignment: Alignment.center,
                            child: Text('${k + 1}', style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        key: const ValueKey('paperRows'),
                        itemCount: m.rollCount,
                        itemExtent: cell + gap,
                        itemBuilder: (_, i) => _row(i + 1, qs, l),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(int roll, List<Question> qs, Lang l) {
    final m = marks!, scheme = Theme.of(context).colorScheme;
    final cells = m.row(roll);
    return Padding(
      padding: const EdgeInsets.only(bottom: gap),
      child: Row(
        children: [
          SizedBox(
            width: rollW,
            child: Text('$roll', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
          ),
          for (var k = 0; k < qs.length; k++)
            Padding(
              padding: const EdgeInsets.only(right: gap),
              child: SizedBox(
                width: cell,
                height: cell,
                child: Material(
                  color: switch (cells[k]) {
                    true => Z.correct,
                    false => Z.wrong,
                    null => scheme.surfaceContainerHighest,
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: ValueKey('cell-$roll-$k'),
                    borderRadius: BorderRadius.circular(16),
                    // Saved marks are in the class record: the grid is read-only from then on.
                    onTap: saved ? null : () => setState(() => m.cycle(roll, k)),
                    child: Icon(
                      switch (cells[k]) {
                        true => Icons.check,
                        false => Icons.close,
                        null => null,
                      },
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: gap),
          SizedBox(
            width: allW,
            height: cell,
            child: OutlinedButton(
              key: ValueKey('allRight-$roll'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, cell), padding: const EdgeInsets.symmetric(horizontal: 8), textStyle: zText(26)),
              onPressed: saved ? null : () => setState(() => m.allRight(roll)),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(ltr('allRight', l))),
            ),
          ),
          SizedBox(
            width: totalW,
            child: Text(
              cells.any((v) => v != null) ? '${m.rightOf(roll)}/${qs.length}' : '',
              key: ValueKey('total-$roll'),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
