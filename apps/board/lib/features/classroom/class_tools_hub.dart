import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import 'ask_ai_screen.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'class_plan_screen.dart';
import 'class_quiz_screen.dart';
import 'coding_lab_screen.dart';
import 'explainer_screen.dart';
import 'formula_drill_screen.dart';
import 'mastery_heatmap_screen.dart';
import 'mock_test_screen.dart';
import 'strings.dart';
import 'teams_screen.dart';
import 'worksheet_export_screen.dart';

/// The whole-class modes in one place: explainers, class quiz, mock test, formula drill, class
/// plan, class mastery, teams, coding lab, worksheets and Ask ZYN-AI. Each opens on [samples]
/// (Zynetix School content); until a content pack carries them, a tile says it is coming.
class ClassToolsHub extends StatelessWidget {
  const ClassToolsHub({super.key, this.samples});
  final ClassSamples? samples;

  static final List<(String, IconData, String, String, bool, Widget Function(ClassSamples))> tools = [
    ('explainers', Icons.play_lesson_outlined, 'explainers', 'explainersSub', true, (s) => ExplainerScreen(samples: s, explainer: s.explainers.first)),
    ('quiz', Icons.how_to_reg_outlined, 'classQuiz', 'classQuizSub', true, (s) => ClassQuizScreen(samples: s)),
    ('mock', Icons.timer_outlined, 'mockTest', 'mockTestSub', true, (s) => MockTestScreen(samples: s)),
    ('formulas', Icons.functions, 'formulaDrill', 'formulaDrillSub', true, (s) => FormulaDrillScreen(samples: s)),
    ('plan', Icons.event_note_outlined, 'classPlan', 'classPlanSub', true, (s) => ClassPlanScreen(samples: s)),
    ('mastery', Icons.grid_view_outlined, 'classMastery', 'classMasterySub', true, (s) => MasteryHeatmapScreen(samples: s)),
    ('teams', Icons.groups_2_outlined, 'teams', 'teamsSub', true, (s) => TeamsScreen(samples: s)),
    ('code', Icons.terminal, 'codingLab', 'codingLabSub', true, (s) => CodingLabScreen(samples: s)),
    ('worksheets', Icons.print_outlined, 'worksheets', 'worksheetsSub', true, (s) => WorksheetExportScreen(samples: s)),
    ('ai', Icons.auto_awesome_outlined, 'askAi', 'askAiSub', false, (s) => AskAiScreen(samples: s)),
  ];

  /// What the sample holds for a tool, in a line ("Gravity and falling", "4 exam patterns").
  static String sampleLine(String id, ClassSamples s, Lang l) => switch (id) {
    'explainers' => s.explainers.first.title.t(l),
    'quiz' => '${s.questions.first.chapter.t(l)} · ${s.questions.first.exams.join(' · ')}',
    'mock' => s.mocks.map((m) => m.exam).join(' · '),
    'formulas' => s.formulas.map((f) => f.chapter.t(l)).join(' · '),
    'plan' => s.plan.exam.t(l),
    'mastery' => '${s.mastery.chapters.length} × ${s.mastery.skills.length} · ${s.mastery.byRoll.first.length} rolls',
    'teams' => s.teams.teams.map((t) => t.name.t(l)).join(' · '),
    'code' => s.code.title.t(l),
    'worksheets' => '${ct('questionsN', l, {'n': s.questions.length})} + ${ct('answerKey', l)}',
    'ai' => s.askAi.question.t(l),
    _ => '',
  };

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final config = ServicesScope.of(context).config;
      void open(Widget Function(ClassSamples) make) {
        final s = samples;
        if (s == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ct('noSample', l))));
          return;
        }
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => make(s)));
      }

      final narrow = context.narrow, portrait = context.portrait;
      final crumbs = [if (samples != null) samples!.subject.t(l), if (samples != null) samples!.year.t(l)];
      return ClassScaffold(
        crumbs: crumbs.isEmpty ? [config.sectionLabel] : crumbs,
        title: ct('hubTitle', l),
        trailing: [if (!narrow) BarChip(ct('offline', l), icon: Icons.cloud_off_outlined)],
        body: LayoutBuilder(
          builder: (context, box) {
            final cols = portrait ? 1 : (narrow ? 2 : 5);
            final rows = (tools.length / cols).ceil();
            const gap = 28.0;
            final fit = !portrait;
            final tileH = fit ? (box.maxHeight - 110 - gap * (rows - 1)) / rows : 176.0;
            final tiles = [
              for (final (id, icon, title, sub, offline, make) in tools)
                SizedBox(
                  width: (box.maxWidth - gap * (cols - 1)) / cols,
                  height: tileH,
                  child: _Tile(key: ValueKey('hub-$id'), icon: icon, title: ct(title, l), sub: ct(sub, l), sample: samples == null ? null : sampleLine(id, samples!, l), badge: offline ? ct('offline', l) : ct('needsOnline', l), offline: offline, compact: portrait, onTap: () => open(make)),
                ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 82,
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 40, color: Z.correct),
                      const SizedBox(width: 16),
                      Expanded(child: Text(narrow ? ct('privacy', l) : '${ct('hubLead', l)}. ${ct('privacy', l)}.', style: zText(narrow ? 26 : 30, FontWeight.w500).copyWith(color: Z.ink2), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(child: SingleChildScrollView(child: Wrap(spacing: gap, runSpacing: gap, children: tiles))),
              ],
            );
          },
        ),
      );
    },
  );
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.icon, required this.title, required this.sub, this.sample, required this.badge, required this.offline, required this.compact, required this.onTap});
  final IconData icon;
  final String title, sub, badge;
  final String? sample;
  final bool offline, compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: compact ? 104 : 128,
      height: compact ? 104 : 128,
      decoration: BoxDecoration(color: offline ? Z.tagBg : Z.highlight, borderRadius: BorderRadius.circular(Z.radius)),
      child: Icon(icon, size: compact ? 52 : 64, color: offline ? Z.primary : Z.wrongText),
    );
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(color: offline ? Z.correctBg : Z.highlight, borderRadius: BorderRadius.circular(Z.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(offline ? Icons.cloud_off_outlined : Icons.wifi, size: 26, color: offline ? Z.correctLabel : Z.wrongText),
          const SizedBox(width: 8),
          Flexible(child: Text(badge, style: zText(24, FontWeight.w600).copyWith(color: offline ? Z.correctLabel : Z.wrongText), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return Material(
      color: Z.panel,
      borderRadius: BorderRadius.circular(Z.panelRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(Z.panelRadius),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 28 : 40),
          child: compact
              ? Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 28),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: zTitle(40), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(sub, style: zText(28, FontWeight.w400).copyWith(color: Z.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 48, color: Z.faint),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [iconBox, const Spacer(), const Icon(Icons.arrow_forward, size: 44, color: Z.faint)],
                    ),
                    const Spacer(),
                    if (sample != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                        decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
                        child: Text(sample!, style: zText(26, FontWeight.w500).copyWith(color: Z.ink2, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      const Spacer(),
                    ],
                    Text(title, style: zTitle(48), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(sub, style: zText(30, FontWeight.w400).copyWith(color: Z.muted, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 18),
                    chip,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Opens the hub (a home-screen class tool).
void openClassTools(BuildContext context, {ClassSamples? samples}) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ClassToolsHub(samples: samples)));

/// The hub's title in [l] (for the home screen's tool list).
String classToolsLabel(Lang l) => ct('hubEntry', l);
