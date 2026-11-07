import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/strings.dart' show subjectName;
import '../../engine/model.dart';
import 'help.dart';
import 'kit.dart';
import 'lesson.dart' show editAttendance, editHomework;
import 'now.dart';
import 'shell.dart';

/// Reports: how far the class has got in each subject, the class history (lesson, homework and
/// attendance by roll number), quiz results and mock test averages. All from this board.
class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final s = ServicesScope.of(context);
      final phone = usePhoneLayout(context);
      final taught = s.config.taught.toSet();
      final history = school.history;
      final quizzes = school.quizzes.reversed.toList();
      final tests = school.tests.reversed.toList();

      Widget panel(String title, IconData icon, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 36),
        padding: EdgeInsets.all(phone ? 36 : 52),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), border: Border.all(color: S.line, width: 3)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 52, color: S.violet), const SizedBox(width: 18), Expanded(child: Text(title, style: hd(56, l: l)))]),
          const SizedBox(height: 28),
          ...children,
        ]),
      );

      final syllabus = [
        for (final sub in s.subjects)
          Builder(builder: (context) {
            final topics = [for (final c in s.chapters(sub, s.config.year)) ...c.topicsFor(s.config.board)];
            final done = topics.where((t) => taught.contains(t.id)).length;
            final share = topics.isEmpty ? 0.0 : done / topics.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(children: [
                SizedBox(width: phone ? 220 : 360, child: Text(subjectName(sub, l), style: tx(34, c: S.ink, w: FontWeight.w700))),
                Expanded(
                  child: Container(
                    height: 28,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(99)),
                    child: FractionallySizedBox(widthFactor: share, child: Container(decoration: BoxDecoration(color: S.violet, borderRadius: BorderRadius.circular(99)))),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(width: phone ? 160 : 300, child: Text(tr(l, '$done of ${topics.length} topics', '${topics.length} ರಲ್ಲಿ $done'), textAlign: TextAlign.right, style: tx(30, c: S.cardText))),
              ]),
            );
          }),
      ];

      final classes = [
        if (history.isEmpty) Text(tr(l, 'Finished classes appear here.', 'ಮುಗಿದ ತರಗತಿಗಳು ಇಲ್ಲಿ ಕಾಣುತ್ತವೆ.'), style: tx(32, c: S.muted)),
        for (final r in history.take(30))
          Container(
            key: ValueKey('history-${r.id}'),
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(36)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: phone ? 160 : 260,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(shortDate(l, r.at), style: tx(30, c: S.ink, w: FontWeight.w700)),
                  Text('${r.at.hour}:${r.at.minute.toString().padLeft(2, '0')}', style: tx(26, c: S.muted)),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${subjectName(r.subject, l)} · ${r.topic.t(l)}', style: tx(32, c: S.ink, w: FontWeight.w700)),
                  Text(tr(l, '${r.teacherName} · ${r.stepsSeen} of ${r.stepsTotal} steps · ${r.minutes} min', '${r.teacherName} · ${r.stepsTotal} ರಲ್ಲಿ ${r.stepsSeen} ಹಂತ · ${r.minutes} ನಿಮಿಷ'), style: tx(28, c: S.cardText)),
                  Text(tr(l, '${r.present} of ${r.rollCount} present${r.absent.isEmpty ? '' : ' · absent: ${r.absent.join(', ')}'}', '${r.rollCount} ರಲ್ಲಿ ${r.present} ಹಾಜರು${r.absent.isEmpty ? '' : ' · ಗೈರು: ${r.absent.join(', ')}'}'), style: tx(28, c: S.cardText)),
                  if (r.homework.isNotEmpty) Text(tr(l, 'Homework: ${r.homework}', 'ಮನೆಗೆಲಸ: ${r.homework}'), maxLines: 2, overflow: TextOverflow.ellipsis, style: tx(28, c: S.eyebrow)),
                ]),
              ),
              Wrap(spacing: 12, runSpacing: 12, direction: phone ? Axis.vertical : Axis.horizontal, children: [
                ZxButton(tr(l, 'Homework', 'ಮನೆಗೆಲಸ'), icon: Icons.edit_rounded, bg: Colors.white, fg: S.ink, height: 90, size: 26, onTap: () async {
                  final v = await editHomework(context, r.homework);
                  if (v == null) return;
                  school.updateClass(r.copyWith(homework: v));
                  school.pushUndo(const L10n('A change to the homework', 'ಮನೆಗೆಲಸದ ಬದಲಾವಣೆ'), () => school.updateClass(r));
                }),
                ZxButton(tr(l, 'Attendance', 'ಹಾಜರಾತಿ'), icon: Icons.how_to_reg_rounded, bg: Colors.white, fg: S.ink, height: 90, size: 26, onTap: () async {
                  final v = await editAttendance(context, r.rollCount, r.absent);
                  if (v == null) return;
                  school.updateClass(r.copyWith(absent: v));
                  school.pushUndo(const L10n('A change to the attendance', 'ಹಾಜರಾತಿಯ ಬದಲಾವಣೆ'), () => school.updateClass(r));
                }),
              ]),
            ]),
          ),
      ];

      final quiz = [
        if (quizzes.isEmpty) Text(tr(l, 'Class quiz results appear here, by roll number.', 'ತರಗತಿ ಪ್ರಶ್ನೋತ್ತರ ಫಲಿತಾಂಶಗಳು ರೋಲ್ ನಂಬರ್‌ನಿಂದ ಇಲ್ಲಿ ಕಾಣುತ್ತವೆ.'), style: tx(32, c: S.muted)),
        for (final q in quizzes.take(12))
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(children: [
              SizedBox(width: phone ? 160 : 260, child: Text(shortDate(l, q.at), style: tx(28, c: S.muted))),
              Expanded(child: Text(s.lessonFor(q.topicId)?.lesson.title.t(l) ?? q.topicId, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(30, c: S.ink, w: FontWeight.w600))),
              Tag(tr(l, '${q.right.length} of ${q.asked} right', '${q.asked} ರಲ್ಲಿ ${q.right.length} ಸರಿ'), icon: Icons.check_circle_rounded, bg: S.greenSoft, fg: S.green, size: 26),
            ]),
          ),
      ];

      final testRows = [
        if (tests.isEmpty) Text(tr(l, 'Mock test scores appear here.', 'ಅಣಕು ಪರೀಕ್ಷೆ ಅಂಕಗಳು ಇಲ್ಲಿ ಕಾಣುತ್ತವೆ.'), style: tx(32, c: S.muted)),
        for (final t in tests.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(children: [
              SizedBox(width: phone ? 160 : 260, child: Text(shortDate(l, t.at), style: tx(28, c: S.muted))),
              Expanded(child: Text(t.pattern, style: tx(30, c: S.ink, w: FontWeight.w600))),
              Tag(tr(l, 'Average ${t.average.toStringAsFixed(1)} / ${t.maxMarks} · ${t.scores.length} wrote', 'ಸರಾಸರಿ ${t.average.toStringAsFixed(1)} / ${t.maxMarks} · ${t.scores.length} ಬರೆದರು'), bg: S.sky, size: 26),
            ]),
          ),
      ];

      return ListView(padding: const EdgeInsets.only(bottom: 60), children: [
        SectionHeader(
          crumb: shortSection(s.config.sectionLabel),
          title: tr(l, 'Reports', 'ವರದಿಗಳು'),
          help: () => const HelpInfo(next: L10n('Scroll down to see each finished class. Tap Homework or Attendance to correct it.', 'ಪ್ರತಿ ಮುಗಿದ ತರಗತಿ ನೋಡಲು ಕೆಳಗೆ ಸರಿಸಿ. ಸರಿಪಡಿಸಲು ಮನೆಗೆಲಸ ಅಥವಾ ಹಾಜರಾತಿ ಒತ್ತಿ.')),
          trailing: [if (!phone) offlineTag(l)],
        ),
        const SizedBox(height: 36),
        panel(tr(l, 'Syllabus covered', 'ಮುಗಿದ ಪಠ್ಯ'), Icons.stacked_bar_chart_rounded, syllabus),
        panel(tr(l, 'Class history', 'ತರಗತಿ ಇತಿಹಾಸ'), Icons.history_edu_rounded, classes),
        panel(tr(l, 'Quiz results', 'ಪ್ರಶ್ನೋತ್ತರ ಫಲಿತಾಂಶ'), Icons.quiz_rounded, quiz),
        panel(tr(l, 'Mock tests', 'ಅಣಕು ಪರೀಕ್ಷೆಗಳು'), Icons.timer_rounded, testRows),
        SafeLine(tr(l, 'Students appear only as roll numbers. Nothing here leaves the board.', 'ವಿದ್ಯಾರ್ಥಿಗಳು ರೋಲ್ ನಂಬರ್ ಮಾತ್ರ. ಇಲ್ಲಿನ ಏನೂ ಬೋರ್ಡ್ ಬಿಟ್ಟು ಹೋಗುವುದಿಲ್ಲ.'), size: 30, c: S.muted),
      ]);
    },
  );
}

