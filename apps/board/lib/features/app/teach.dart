import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/strings.dart' show subjectName, yearLabel;
import '../../engine/model.dart';
import '../../engine/sync.dart' show SyncError;
import '../exam_practice.dart';
import '../self_learning.dart';
import 'help.dart';
import 'kit.dart';
import 'lesson.dart';
import 'now.dart';
import 'shell.dart';
import 'today.dart' show LessonKit;

const _bgs = [S.lavender, S.sky, S.mint, S.peach, S.butter, S.pink];

/// Teach: every chapter of the section's subjects, then a chapter's topics with what each
/// carries (steps, voice, 3D, labs, questions) and whether it has been taught.
class TeachView extends StatefulWidget {
  const TeachView({super.key});
  @override
  State<TeachView> createState() => _TeachViewState();
}

class _TeachViewState extends State<TeachView> {
  String? subject, year;

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final s = ServicesScope.of(context);
      final phone = usePhoneLayout(context);
      final subj = subject ?? classNow(s).subject;
      final yr = year ?? s.config.year;
      final chapters = s.chapters(subj, yr);
      final taught = s.config.taught.toSet();
      final cols = phone ? 1 : 3;
      return ListView(padding: const EdgeInsets.only(bottom: 60), children: [
        SectionHeader(
          crumb: shortSection(s.config.sectionLabel),
          title: tr(l, 'Teach', 'ಪಾಠ'),
          help: () => const HelpInfo(next: L10n('Pick a chapter, then tap a topic to teach it step by step.', 'ಅಧ್ಯಾಯ ಆರಿಸಿ, ನಂತರ ವಿಷಯವನ್ನು ಒತ್ತಿ ಹಂತ ಹಂತವಾಗಿ ಕಲಿಸಿ.')),
          trailing: [
            if (!phone) ...[
              ZxButton(tr(l, 'Exam practice', 'ಪರೀಕ್ಷಾ ಅಭ್ಯಾಸ'), key: const ValueKey('examPractice'), icon: Icons.assignment_rounded, bg: S.mist, fg: S.ink, height: 100, size: 30, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExamPracticeScreen()))),
              ZxButton(tr(l, 'Self-learning', 'ಸ್ವಯಂ ಕಲಿಕೆ'), key: const ValueKey('selfLearning'), icon: Icons.self_improvement_rounded, bg: S.mist, fg: S.ink, height: 100, size: 30, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SelfLearningStartScreen()))),
            ],
          ],
        ),
        const SizedBox(height: 28),
        Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final sub in s.subjects)
            Press(key: ValueKey('teach-$sub'), onTap: () => setState(() => subject = sub), child: Tag(subjectName(sub, l), bg: sub == subj ? S.ink : S.mist, fg: sub == subj ? Colors.white : S.ink, size: 30)),
          const SizedBox(width: 24),
          for (final y in const ['puc1', 'puc2'])
            Press(key: ValueKey('year-$y'), onTap: () => setState(() => year = y), child: Tag(yearLabel(y, s.config.board, l), bg: y == yr ? S.violet : S.soft, fg: y == yr ? Colors.white : S.violet, size: 28)),
        ]),
        if (phone) ...[
          const SizedBox(height: 24),
          Wrap(spacing: 16, runSpacing: 16, children: [
            ZxButton(tr(l, 'Exam practice', 'ಪರೀಕ್ಷಾ ಅಭ್ಯಾಸ'), icon: Icons.assignment_rounded, bg: S.mist, fg: S.ink, height: 96, size: 28, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExamPracticeScreen()))),
            ZxButton(tr(l, 'Self-learning', 'ಸ್ವಯಂ ಕಲಿಕೆ'), icon: Icons.self_improvement_rounded, bg: S.mist, fg: S.ink, height: 96, size: 28, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SelfLearningStartScreen()))),
          ]),
        ],
        const SizedBox(height: 36),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 36 * (cols - 1)) / cols;
          return Wrap(spacing: 36, runSpacing: 36, children: [
            for (final (i, c) in chapters.indexed)
              SizedBox(
                width: w,
                height: phone ? 300 : 360,
                child: Builder(builder: (context) {
                  final p = s.store.byChapter(c.id);
                  final topics = c.topicsFor(s.config.board);
                  final done = topics.where((t) => taught.contains(t.id)).length;
                  return Press(
                    key: ValueKey('chapter-${c.id}'),
                    radius: 48,
                    onTap: p == null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChapterPage(pack: p))),
                    child: Container(
                      padding: const EdgeInsets.all(44),
                      decoration: BoxDecoration(color: p == null ? S.mist : _bgs[i % _bgs.length], borderRadius: BorderRadius.circular(48)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Tag(tr(l, 'Chapter ${c.number}', 'ಅಧ್ಯಾಯ ${c.number}'), size: 26)),
                          const SizedBox(width: 12),
                          if (p == null) Flexible(child: Tag(tr(l, 'Not installed', 'ಸ್ಥಾಪಿಸಿಲ್ಲ'), bg: Colors.white, fg: S.muted, size: 24)) else ...[const Spacer(), const ArrowChip(size: 68)],
                        ]),
                        const Spacer(),
                        Flexible(child: Text(c.title.t(l), maxLines: 2, overflow: TextOverflow.ellipsis, style: hd(52, l: l))),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: Container(
                              height: 16,
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(color: const Color(0x80FFFFFF), borderRadius: BorderRadius.circular(99)),
                              child: FractionallySizedBox(widthFactor: topics.isEmpty ? 0 : done / topics.length, child: Container(decoration: BoxDecoration(color: S.green, borderRadius: BorderRadius.circular(99)))),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Flexible(child: Text(tr(l, '$done of ${topics.length} taught', '${topics.length} ರಲ್ಲಿ $done'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(26, c: S.cardText, w: FontWeight.w600))),
                        ]),
                      ]),
                    ),
                  );
                }),
              ),
          ]);
        }),
      ]);
    },
  );
}

/// A chapter: its topics with badges for what each lesson carries. Tap one to teach it.
class ChapterPage extends StatefulWidget {
  const ChapterPage({super.key, required this.pack});
  final InstalledPack pack;
  @override
  State<ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  bool _downloading = false;

  Future<void> _download(Services s, Lang l) async {
    setState(() => _downloading = true);
    String msg;
    try {
      await s.sync.downloadVoice(widget.pack.id, l);
      msg = tr(l, 'Voice downloaded. Lessons now speak.', 'ಧ್ವನಿ ಡೌನ್‌ಲೋಡ್ ಆಯಿತು.');
    } on SyncError catch (e) {
      msg = e.message;
    } catch (_) {
      msg = tr(l, 'Could not download: the board needs internet for this.', 'ಡೌನ್‌ಲೋಡ್ ಆಗಲಿಲ್ಲ: ಇದಕ್ಕೆ ಇಂಟರ್ನೆಟ್ ಬೇಕು.');
    }
    if (!mounted) return;
    setState(() => _downloading = false);
    toast(context, msg);
  }

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final s = ServicesScope.of(context);
      final phone = usePhoneLayout(context);
      final p = widget.pack;
      final topics = p.chapter.topicsFor(s.config.board);
      final taught = s.config.taught.toSet();
      final firstLesson = topics.map((t) => p.lessons[t.id]).whereType<Lesson>().firstOrNull;
      final hasVoice = firstLesson != null && s.voice?.track(p, firstLesson, l) != null;
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(phone ? 32 : 120, phone ? 24 : 40, phone ? 32 : 120, 0),
            child: ListView(padding: const EdgeInsets.only(bottom: 60), children: [
              Row(children: [
                ZxButton(tr(l, 'Back', 'ಹಿಂದೆ'), key: const ValueKey('chapterBack'), icon: Icons.arrow_back_rounded, bg: S.mist, fg: S.ink, height: phone ? 96 : 112, size: phone ? 28 : 34, onTap: () => Navigator.of(context).maybePop()),
              ]),
              const SizedBox(height: 24),
              SectionHeader(
                crumb: '${subjectName(p.chapter.subject, l)} · ${tr(l, 'Chapter ${p.chapter.number}', 'ಅಧ್ಯಾಯ ${p.chapter.number}')}',
                title: p.chapter.title.t(l),
                help: () => const HelpInfo(next: L10n('Tap a topic to teach it. A green tick means it has been taught.', 'ಕಲಿಸಲು ವಿಷಯ ಒತ್ತಿ. ಹಸಿರು ಗುರುತು ಎಂದರೆ ಕಲಿಸಲಾಗಿದೆ.')),
              ),
              const SizedBox(height: 28),
              Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (hasVoice)
                  Tag(tr(l, 'Voice ready', 'ಧ್ವನಿ ಸಿದ್ಧ'), icon: Icons.record_voice_over_rounded, bg: S.greenSoft, fg: S.green, size: 28)
                else if (s.voice != null)
                  ZxButton(_downloading ? tr(l, 'Downloading…', 'ಡೌನ್‌ಲೋಡ್ ಆಗುತ್ತಿದೆ…') : tr(l, 'Download the voice (needs internet)', 'ಧ್ವನಿ ಡೌನ್‌ಲೋಡ್ (ಇಂಟರ್ನೆಟ್ ಬೇಕು)'), key: const ValueKey('downloadVoice'), icon: Icons.download_rounded, bg: S.peach, fg: S.rust, height: 96, size: 28, onTap: _downloading ? null : () => _download(s, l)),
                Tag(tr(l, '${p.questions.length} exam questions', '${p.questions.length} ಪರೀಕ್ಷಾ ಪ್ರಶ್ನೆಗಳು'), icon: Icons.quiz_rounded, bg: S.mist, size: 28),
              ]),
              const SizedBox(height: 36),
              for (final (i, t) in topics.indexed)
                if (p.lessons[t.id] case final lesson?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Builder(builder: (context) {
                      final kit = LessonKit(p, lesson, s.config.board);
                      final step = school.stepFor(t.id);
                      return Press(
                        key: ValueKey('topic-${t.id}'),
                        radius: 44,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SimpleLessonScreen(pack: p, lesson: lesson))),
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(44)),
                          child: Row(children: [
                            Tick(done: taught.contains(t.id), now: !taught.contains(t.id) && step > 0, n: i + 1, size: phone ? 72 : 96),
                            const SizedBox(width: 32),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(lesson.title.t(l), style: tx(phone ? 34 : 42, c: S.ink, w: FontWeight.w700, h: 1.2)),
                                const SizedBox(height: 14),
                                Wrap(spacing: 12, runSpacing: 12, children: [
                                  Tag(tr(l, '${kit.blocks.length} steps', '${kit.blocks.length} ಹಂತ'), icon: Icons.slideshow_rounded, bg: Colors.white, size: 24),
                                  Tag(tr(l, '${lesson.minutes} min', '${lesson.minutes} ನಿಮಿಷ'), icon: Icons.schedule_rounded, bg: Colors.white, size: 24),
                                  if (kit.models > 0) Tag(tr(l, '${kit.models} 3D', '${kit.models} 3D'), icon: Icons.view_in_ar_rounded, bg: S.butter, size: 24),
                                  if (kit.labs > 0) Tag(tr(l, '${kit.labs} lab', '${kit.labs} ಲ್ಯಾಬ್'), icon: Icons.science_rounded, bg: S.mint, size: 24),
                                  if (kit.sims > 0) Tag(tr(l, '${kit.sims} interactive', '${kit.sims} ಸಂವಾದಾತ್ಮಕ'), icon: Icons.touch_app_rounded, bg: S.sky, size: 24),
                                  if (kit.questions > 0) Tag(tr(l, '${kit.questions} questions', '${kit.questions} ಪ್ರಶ್ನೆ'), icon: Icons.quiz_rounded, bg: S.peach, size: 24),
                                  if (step > 0 && !taught.contains(t.id)) Tag(tr(l, 'Left at step ${step + 1}', 'ಹಂತ ${step + 1} ರಲ್ಲಿ ನಿಂತಿದೆ'), icon: Icons.history_rounded, bg: S.lavender, fg: S.violet, size: 24),
                                ]),
                              ]),
                            ),
                            const SizedBox(width: 20),
                            const ArrowChip(size: 76),
                          ]),
                        ),
                      );
                    }),
                  ),
            ]),
          ),
        ),
      );
    },
  );
}
