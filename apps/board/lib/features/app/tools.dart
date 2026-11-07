import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/strings.dart' show subjectName;
import '../../engine/model.dart';
import '../classroom/class_plan_screen.dart';
import '../classroom/class_quiz_screen.dart';
import '../classroom/coding_lab_screen.dart';
import '../classroom/explainer_screen.dart';
import '../classroom/formula_drill_screen.dart';
import '../classroom/mastery_heatmap_screen.dart';
import '../classroom/mock_test_screen.dart';
import '../classroom/teams_screen.dart';
import '../classroom/worksheet_export_screen.dart';
import '../game/game_hub.dart';
import '../insight/mastery_map.dart';
import '../live/live_quiz_screen.dart';
import '../live/paper_marks.dart';
import 'class_content.dart';
import 'help.dart';
import 'kit.dart';
import 'now.dart';
import 'shell.dart';

/// Class tools: quiz by roll number, mock tests, formula drill, teams, class plan, mastery,
/// worksheets and the coding lab, for one subject at a time. Everything works offline and is
/// saved on this board by roll number.
class ToolsView extends StatefulWidget {
  const ToolsView({super.key});
  @override
  State<ToolsView> createState() => _ToolsViewState();
}

class _ToolsViewState extends State<ToolsView> {
  String? subject;
  late final Future<ClassContent> _content = ClassContent.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<ClassContent>(
    future: _content,
    builder: (context, snap) => SchoolBuilder(
      builder: (context, l, school) {
        final s = ServicesScope.of(context);
        final phone = usePhoneLayout(context);
        final subj = subject ?? classNow(s).subject;
        final data = buildSamples(s, snap.data ?? ClassContent.empty, subject: subj);
        void go(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
        final weeks = data.plan.examDate.difference(data.plan.today).inDays ~/ 7;
        final m = data.mastery;
        final allCells = [for (final r in m.bySkill) for (final v in r) if (v >= 0) v];
        final avg = allCells.isEmpty ? null : (allCells.reduce((a, b) => a + b) / allCells.length).round();
        final xp = data.teams.teams.fold(0, (a, t) => a + t.xp);
        final cs = subj == 'computer_science';
        final cards = <(String, Color, IconData, String, String, List<String>, Widget? Function())>[
          ('quiz', S.mint, Icons.how_to_reg_rounded, tr(l, 'Class quiz', 'ತರಗತಿ ಪ್ರಶ್ನೋತ್ತರ'), tr(l, '${data.questions.length} questions · mark by roll number', '${data.questions.length} ಪ್ರಶ್ನೆಗಳು · ರೋಲ್ ನಂಬರ್‌ನಿಂದ ಗುರುತು'), [tr(l, 'No phones', 'ಫೋನ್ ಬೇಡ'), tr(l, 'Solution steps', 'ಪರಿಹಾರ ಹಂತಗಳು')], () => data.questions.isEmpty ? null : ClassQuizScreen(samples: data)),
          ('mock', S.sky, Icons.timer_rounded, tr(l, 'Mock tests', 'ಅಣಕು ಪರೀಕ್ಷೆ'), tr(l, 'Project a paper: timer, sections, palette, then scores', 'ಪತ್ರಿಕೆ ತೋರಿಸಿ: ಸಮಯ, ವಿಭಾಗ, ನಂತರ ಅಂಕ'), [for (final p in data.mocks.take(3)) p.exam], () => data.mocks.isEmpty ? null : MockTestScreen(samples: data)),
          ('drill', S.lavender, Icons.functions_rounded, tr(l, 'Formula drill', 'ಸೂತ್ರ ಅಭ್ಯಾಸ'), tr(l, '${data.formulas.fold(0, (a, f) => a + f.items.length)} formulas, cover and recall', '${data.formulas.fold(0, (a, f) => a + f.items.length)} ಸೂತ್ರಗಳು, ಮುಚ್ಚಿ ನೆನಪಿಸಿ'), [for (final f in data.formulas.take(2)) f.chapter.t(l)], () => data.formulas.isEmpty ? null : FormulaDrillScreen(samples: data)),
          ('teams', S.peach, Icons.groups_rounded, tr(l, 'Teams', 'ತಂಡಗಳು'), tr(l, 'Houses by roll number · $xp XP · ${data.teams.streakDays}-day streak', 'ರೋಲ್ ನಂಬರ್ ಮನೆಗಳು · $xp XP · ${data.teams.streakDays} ದಿನ'), [for (final t in data.teams.teams) t.name.t(l)], () => TeamsScreen(samples: data)),
          ('plan', S.greenSoft, Icons.event_note_rounded, tr(l, 'Class plan', 'ತರಗತಿ ಯೋಜನೆ'), tr(l, 'Worked back from the exam · $weeks weeks to go', 'ಪರೀಕ್ಷೆಯಿಂದ ಹಿಂದಕ್ಕೆ · ಇನ್ನೂ $weeks ವಾರ'), [tr(l, 'Pacing', 'ವೇಗ'), tr(l, 'Revision', 'ಪುನರಾವರ್ತನೆ')], () => data.plan.chapters.isEmpty ? null : ClassPlanScreen(samples: data)),
          ('mastery', S.pink, Icons.grid_view_rounded, tr(l, 'Mastery heatmap', 'ಪ್ರಾವೀಣ್ಯ ನಕ್ಷೆ'), avg == null ? tr(l, 'Fills in from class quizzes and tests', 'ತರಗತಿ ಪ್ರಶ್ನೋತ್ತರದಿಂದ ತುಂಬುತ್ತದೆ') : tr(l, '${m.chapters.length} chapters · class average $avg%', '${m.chapters.length} ಅಧ್ಯಾಯ · ಸರಾಸರಿ $avg%'), [tr(l, 'By skill', 'ಕೌಶಲ'), tr(l, 'By roll number', 'ರೋಲ್ ನಂಬರ್')], () => m.chapters.isEmpty ? null : MasteryHeatmapScreen(samples: data)),
          ('worksheet', S.butter, Icons.print_rounded, tr(l, 'Worksheets', 'ವರ್ಕ್‌ಶೀಟ್'), tr(l, '${data.questions.length} questions + answer key on its own page', '${data.questions.length} ಪ್ರಶ್ನೆ + ಪ್ರತ್ಯೇಕ ಉತ್ತರ ಸೂಚಿ'), [tr(l, 'Print', 'ಮುದ್ರಿಸಿ'), 'PDF'], () => data.questions.isEmpty ? null : WorksheetExportScreen(samples: data)),
          ('code', cs ? S.mint : S.mist, Icons.terminal_rounded, tr(l, 'Coding lab', 'ಕೋಡಿಂಗ್ ಲ್ಯಾಬ್'), tr(l, 'PUC Computer Science · Python on the board', 'ಪಿಯುಸಿ ಕಂಪ್ಯೂಟರ್ ವಿಜ್ಞಾನ · ಬೋರ್ಡ್‌ನಲ್ಲಿ ಪೈಥಾನ್'), ['Python', tr(l, 'Offline', 'ಆಫ್‌ಲೈನ್')], () => (snap.data?.programs.isEmpty ?? true) ? null : CodingLabScreen(samples: data, programs: snap.data!.programs)),
          if (data.explainers.isNotEmpty)
            ('explainer', S.lavender, Icons.menu_book_rounded, tr(l, 'Explainers', 'ವಿವರಣೆಗಳು'), data.explainers.first.title.t(l), [tr(l, 'Watch', 'ನೋಡಿ'), tr(l, 'Mission', 'ಮಿಷನ್')], () => ExplainerScreen(samples: data, explainer: data.explainers.first)),
        ];
        final more = <(String, IconData, String, Widget)>[
          ('masteryMap', Icons.grid_on_rounded, tr(l, 'Mastery map', 'ಪ್ರಾವೀಣ್ಯ ನಕ್ಷೆ'), const MasteryMapScreen()),
          ('game', Icons.sports_esports_rounded, tr(l, 'Class games', 'ತರಗತಿ ಆಟಗಳು'), const GameHubScreen()),
          ('paper', Icons.fact_check_rounded, tr(l, 'Paper test marks', 'ಪೇಪರ್ ಪರೀಕ್ಷೆ ಅಂಕ'), const PaperMarksScreen()),
          ('phones', Icons.phonelink_ring_rounded, tr(l, 'Quiz on phones (school Wi-Fi)', 'ಫೋನ್‌ನಲ್ಲಿ ಪ್ರಶ್ನೆ (ಶಾಲೆಯ ವೈ-ಫೈ)'), const LiveQuizScreen()),
        ];
        final stats = [
          (S.peach, Icons.local_fire_department_rounded, tr(l, 'Class streak', 'ತರಗತಿ ಸರಣಿ'), tr(l, '${data.teams.streakDays} days', '${data.teams.streakDays} ದಿನ')),
          (S.butter, Icons.bolt_rounded, tr(l, 'Today', 'ಇಂದು'), '${data.teams.periodXp} / ${data.teams.goalXp} XP'),
          (S.lavender, Icons.insights_rounded, tr(l, 'Class mastery', 'ತರಗತಿ ಪ್ರಾವೀಣ್ಯ'), avg == null ? '—' : '$avg%'),
          (S.mint, Icons.flag_rounded, tr(l, 'Exam in', 'ಪರೀಕ್ಷೆಗೆ'), tr(l, '$weeks weeks', '$weeks ವಾರ')),
        ];
        final cols = phone ? 1 : 3;
        return ListView(padding: const EdgeInsets.only(bottom: 60), children: [
          SectionHeader(
            crumb: '${shortSection(s.config.sectionLabel)} · ${subjectName(subj, l)}',
            title: tr(l, 'Class tools', 'ತರಗತಿ ಸಾಧನಗಳು'),
            help: () => const HelpInfo(
              next: L10n('Pick the subject, then a tool. Class quiz is the quickest: ask, then tap who got it right.', 'ವಿಷಯ ಆರಿಸಿ, ನಂತರ ಸಾಧನ. ತರಗತಿ ಪ್ರಶ್ನೋತ್ತರ ಅತಿ ವೇಗ: ಕೇಳಿ, ಸರಿ ಉತ್ತರಕ್ಕೆ ಒತ್ತಿ.'),
              detail: L10n('Results are kept on this board by roll number only.', 'ಫಲಿತಾಂಶಗಳು ರೋಲ್ ನಂಬರ್‌ನಿಂದ ಮಾತ್ರ ಈ ಬೋರ್ಡ್‌ನಲ್ಲಿ ಉಳಿಯುತ್ತವೆ.'),
            ),
            trailing: [if (!phone) offlineTag(l)],
          ),
          const SizedBox(height: 28),
          Wrap(spacing: 16, runSpacing: 16, children: [
            for (final sub in s.subjects)
              Press(
                key: ValueKey('subj-$sub'),
                onTap: () => setState(() => subject = sub),
                child: Tag(subjectName(sub, l), bg: sub == subj ? S.ink : S.mist, fg: sub == subj ? Colors.white : S.ink, size: 30),
              ),
          ]),
          const SizedBox(height: 36),
          LayoutBuilder(builder: (context, box) {
            final n = phone ? 2 : 4;
            final w = (box.maxWidth - 28 * (n - 1)) / n;
            return Wrap(spacing: 28, runSpacing: 28, children: [
              for (final (bg, ic, label, value) in stats)
                Container(
                  width: w,
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(44)),
                  child: Row(children: [
                    Container(width: 96, height: 96, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)), child: Icon(ic, size: 52, color: S.ink)),
                    const SizedBox(width: 28),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(28, c: S.muted, w: FontWeight.w500)),
                        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: hd(56, l: l)),
                      ]),
                    ),
                  ]),
                ),
            ]);
          }),
          const SizedBox(height: 36),
          LayoutBuilder(builder: (context, box) {
            final w = (box.maxWidth - 36 * (cols - 1)) / cols;
            return Wrap(spacing: 36, runSpacing: 36, children: [
              for (final (id, bg, ic, t, sub, tags, open) in cards)
                SizedBox(
                  width: w,
                  height: phone ? 400 : 520,
                  child: Press(
                    key: ValueKey('tool-$id'),
                    radius: 40,
                    onTap: () {
                      final w = open();
                      if (w == null) {
                        toast(context, tr(l, 'Nothing here yet for ${subjectName(subj, Lang.en)}. Install its chapters, or run a class quiz first.', '${subjectName(subj, l)}ಗೆ ಇನ್ನೂ ಏನೂ ಇಲ್ಲ.'));
                      } else {
                        go(w);
                      }
                    },
                    child: ZxCard(bg: bg, icon: ic, title: t, sub: sub, tags: tags, lang: l, titleSize: 58, compact: true),
                  ),
                ),
            ]);
          }),
          const SizedBox(height: 48),
          Text(tr(l, 'More class tools', 'ಇನ್ನಷ್ಟು ಸಾಧನಗಳು'), style: hd(56, l: l)),
          const SizedBox(height: 24),
          Wrap(spacing: 20, runSpacing: 20, children: [
            for (final (id, ic, t, w) in more) ZxButton(t, key: ValueKey('more-$id'), icon: ic, bg: S.mist, fg: S.ink, height: 110, size: 32, onTap: () => go(w)),
          ]),
        ]);
      },
    ),
  );
}

