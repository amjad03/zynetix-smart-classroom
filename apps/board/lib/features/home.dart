import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/licence.dart';
import '../engine/model.dart';
import 'exam_practice.dart';
import 'game/game_hub.dart';
import 'game/strings.dart';
import 'insight/mastery_map.dart';
import 'insight/strings.dart';
import 'insight/today_plan.dart';
import 'insight/worksheet.dart';
import 'live/live_quiz_screen.dart';
import 'live/paper_marks.dart';
import 'live/strings.dart';
import 'player.dart';
import 'self_learning.dart';
import 'settings.dart';
import 'smartboard.dart';
import 'teacher_mode.dart';

/// Home: three big buttons (Teacher Mode, Self-Learning, Exam Practice) and a one-tap Continue card.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return ListenableBuilder(
      listenable: s.config,
      builder: (context, _) {
        final l = s.config.lang;
        final next = s.nextTopic();
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final portrait = context.portrait, narrow = context.narrow, pad = narrow ? 20.0 : 32.0;
                Widget mode(Widget b) => portrait ? SizedBox(height: narrow ? 200 : 260, child: b) : Expanded(child: b);
                final gap = portrait ? SizedBox(height: pad) : SizedBox(width: pad);
                final modes = [
                  _ModeButton(
                    key: const ValueKey('teacherMode'),
                    icon: Icons.co_present_outlined,
                    title: tr('teacherMode', l),
                    sub: tr('teacherModeSub', l),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeacherModeScreen())),
                  ),
                  _ModeButton(
                    key: const ValueKey('selfLearning'),
                    icon: Icons.smart_display_outlined,
                    title: tr('selfLearning', l),
                    sub: tr('selfLearningSub', l),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SelfLearningStartScreen())),
                  ),
                  _ModeButton(
                    key: const ValueKey('examPractice'),
                    icon: Icons.emoji_events_outlined,
                    title: tr('examPractice', l),
                    sub: tr('examPracticeSub', l),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExamPracticeScreen())),
                  ),
                ];
                // Tall enough: the modes fill the height left. Otherwise everything scrolls.
                final fill = !portrait && box.maxHeight >= 1200;
                final children = <Widget>[
                  StatusBar(lang: l),
                  _LicenceBanner(services: s),
                  SizedBox(height: pad),
                  const TodayPlanCard(),
                  if (next != null) ...[
                    SizedBox(height: pad),
                    _ContinueCard(
                      title: '${subjectName(next.pack.chapter.subject, l)} · ${next.pack.chapter.title.t(l)}',
                      topic: next.lesson.title.t(l),
                      lang: l,
                      onTap: () => openLesson(context, next.pack, next.lesson),
                    ),
                  ],
                  SizedBox(height: pad),
                  if (portrait)
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [mode(modes[0]), gap, mode(modes[1]), gap, mode(modes[2])])
                  else
                    SizedBox(height: 260, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [mode(modes[0]), gap, mode(modes[1]), gap, mode(modes[2])])),
                  SizedBox(height: pad),
                  _ToolStrip(lang: l),
                  const SizedBox(height: 20),
                  Text('${s.config.collegeName} · ${tr('offlineOk', l)}', style: zText(26, FontWeight.w400).copyWith(color: Z.muted), textAlign: TextAlign.center),
                ];
                if (fill) {
                  // A board: the next period and Continue with the class tools on the left, the three
                  // modes stacked on the right; everything fills the screen.
                  return Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatusBar(lang: l),
                        _LicenceBanner(services: s),
                        SizedBox(height: pad),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const TodayPlanCard(),
                                    if (next != null) ...[
                                      SizedBox(height: pad),
                                      _ContinueCard(
                                        title: '${subjectName(next.pack.chapter.subject, l)} · ${next.pack.chapter.title.t(l)}',
                                        topic: next.lesson.title.t(l),
                                        lang: l,
                                        onTap: () => openLesson(context, next.pack, next.lesson),
                                      ),
                                    ],
                                    SizedBox(height: pad),
                                    Expanded(child: _ToolPanel(lang: l, footer: '${s.config.collegeName} · ${tr('offlineOk', l)}')),
                                  ],
                                ),
                              ),
                              SizedBox(width: pad),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [Expanded(child: modes[0]), SizedBox(height: pad), Expanded(child: modes[1]), SizedBox(height: pad), Expanded(child: modes[2])],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final col = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
                return SingleChildScrollView(padding: EdgeInsets.all(pad), child: col);
              },
            ),
          ),
        );
      },
    );
  }
}

/// Opens the lesson player in Teacher Mode.
void openLesson(BuildContext context, InstalledPack pack, Lesson lesson) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => LessonPlayerScreen(pack: pack, lesson: lesson),
  ),
);

/// Section, Smartboard, clock and the EN / ಕನ್ನಡ switch, at the top of Home.
class StatusBar extends StatefulWidget {
  const StatusBar({super.key, required this.lang});
  final Lang lang;
  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), now = s.clock();
    final narrow = context.narrow, gap = SizedBox(width: narrow ? 12 : 20);
    return Container(
      constraints: const BoxConstraints(minHeight: 128),
      padding: EdgeInsets.fromLTRB(narrow ? 28 : 44, 16, 20, 16),
      decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
      child: Row(
        children: [
          if (!context.portrait) ...[Text('Zynetix', style: zTitle(Z.title).copyWith(color: Z.primary)), SizedBox(width: narrow ? 20 : 36)],
          Expanded(
            child: Text(s.config.sectionLabel, style: zText(narrow ? 28 : 32, FontWeight.w500).copyWith(color: Z.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          gap,
          const SmartboardButton(),
          gap,
          // Long press (IT / teacher only, behind the PIN): settings.
          GestureDetector(
            onLongPress: () => openSettings(context),
            child: Text('${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}', style: zText(narrow ? 30 : 36, FontWeight.w600)),
          ),
          if (s.config.kannadaOffered) ...[
          gap,
          ZSegmented<Lang>(
            expand: false,
            height: 68,
            items: const [(Lang.en, 'EN', ValueKey('lang-en')), (Lang.kn, 'ಕನ್ನಡ', ValueKey('lang-kn'))],
            selected: widget.lang,
            onChanged: s.config.setLang,
          ),
          ],
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.title, required this.topic, required this.lang, required this.onTap});
  final String title, topic;
  final Lang lang;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    return Material(
      color: Z.panel,
      borderRadius: BorderRadius.circular(Z.panelRadius),
      child: InkWell(
        key: const ValueKey('continue'),
        borderRadius: BorderRadius.circular(Z.panelRadius),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 28 : 44, vertical: narrow ? 24 : 36),
          child: Row(
            children: [
              Container(
                width: narrow ? 88 : 112,
                height: narrow ? 88 : 112,
                decoration: const BoxDecoration(color: Z.primary, shape: BoxShape.circle),
                child: Icon(Icons.play_arrow, size: narrow ? 52 : 64, color: Colors.white),
              ),
              SizedBox(width: narrow ? 20 : 36),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${tr('continue', lang)} · $title', style: zText(narrow ? 26 : 28, FontWeight.w400).copyWith(color: Z.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(topic, style: zTitle(narrow ? 36 : 44), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (!narrow) const Icon(Icons.arrow_forward, size: 44, color: Z.ink2),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the three modes: a white panel with its icon on a pale blue tile.
class _ModeButton extends StatelessWidget {
  const _ModeButton({super.key, required this.icon, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    return Material(
      color: Z.panel,
      borderRadius: BorderRadius.circular(Z.panelRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(Z.panelRadius),
        onTap: onTap,
        child: LayoutBuilder(builder: (context, box) => Padding(
          padding: EdgeInsets.all(narrow ? 28 : 44),
          child: Row(
            children: [
              Container(
                width: narrow ? 104 : 136,
                height: narrow ? 104 : 136,
                decoration: BoxDecoration(color: Z.tagBg, borderRadius: BorderRadius.circular(32)),
                child: Icon(icon, size: narrow ? 56 : 72, color: Z.primary),
              ),
              SizedBox(width: narrow ? 24 : 36),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: zTitle(narrow ? 42 : 48)),
                      const SizedBox(height: 6),
                      Text(sub, style: zText(narrow ? 26 : 30, FontWeight.w400).copyWith(color: Z.muted)),
                    ],
                  ),
                ),
              ),
              if (!narrow) ...[const SizedBox(width: 24), const Icon(Icons.arrow_forward, size: 44, color: Z.ink2)],
            ],
          ),
        )),
      ),
    );
  }


}

/// Shown only when something needs the college's attention. Teaching never stops.
class _LicenceBanner extends StatelessWidget {
  const _LicenceBanner({required this.services});
  final Services services;

  @override
  Widget build(BuildContext context) => FutureBuilder<LicenceStatus>(
    future: services.licence(),
    builder: (context, snap) {
      final st = snap.data;
      final String? msg = switch (st?.state) {
        LicenceState.grace => 'Licence expired. ${st!.daysLeft} days left to renew; lessons keep working.',
        LicenceState.lapsed => 'Licence expired. Lessons keep working, but new content is paused until the college renews.',
        LicenceState.invalid => 'This board\'s licence could not be verified. Please contact Zynetix support.',
        _ => null,
      };
      if (msg == null) return const SizedBox.shrink();
      return Container(
        key: const ValueKey('licenceBanner'),
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        decoration: BoxDecoration(color: Z.wrongBg, borderRadius: BorderRadius.circular(Z.panelRadius)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Z.wrongText),
            const SizedBox(width: 16),
            Expanded(child: Text(msg, style: zText(30, FontWeight.w500).copyWith(color: Z.wrongText))),
          ],
        ),
      );
    },
  );
}

/// On a board: the class tools as a panel of rows (icon, name, arrow), and the college line.
class _ToolPanel extends StatelessWidget {
  const _ToolPanel({required this.lang, required this.footer});
  final Lang lang;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final tools = _ToolStrip.tools(context, lang);
    return ZPanel(
      padding: const EdgeInsets.fromLTRB(44, 36, 44, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZSectionTitle(tr('classTools', lang)),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                const cols = 2, gap = 20.0;
                final rows = (tools.length / cols).ceil();
                final h = ((box.maxHeight - gap * (rows - 1)) / rows).clamp(Z.tap, 200.0);
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final (k, i, label, onTap) in tools)
                        SizedBox(
                          width: (box.maxWidth - gap) / cols,
                          height: h,
                          child: Material(
                            color: Z.tile,
                            borderRadius: BorderRadius.circular(Z.radius),
                            child: InkWell(
                              key: k,
                              borderRadius: BorderRadius.circular(Z.radius),
                              onTap: onTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 28),
                                child: Row(
                                  children: [
                                    Icon(i, size: 44, color: Z.ink2),
                                    const SizedBox(width: 20),
                                    Expanded(child: Text(label, style: zText(30, FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    const Icon(Icons.chevron_right, size: 40, color: Z.faint),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(footer, style: zText(26, FontWeight.w400).copyWith(color: Z.muted)),
        ],
      ),
    );
  }
}

/// Under the three modes: the class's mastery map, the Game Zone, the phone quiz, paper marks
/// and the homework sheet. Wraps onto more lines on a narrow screen.
class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.lang});
  final Lang lang;

  /// The tools: key, icon, name and what a tap opens.
  static List<(Key, IconData, String, VoidCallback)> tools(BuildContext context, Lang l) {
    void go(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    return [
      (const ValueKey('tool-mastery'), Icons.grid_on_outlined, it('masteryMap', l), () => go(const MasteryMapScreen())),
      (const ValueKey('tool-game'), Icons.sports_esports_outlined, gt('gameHub', l), () => go(const GameHubScreen())),
      (const ValueKey('tool-phones'), Icons.phonelink_ring_outlined, ltr('phones', l), () => go(const LiveQuizScreen())),
      (const ValueKey('tool-paper'), Icons.fact_check_outlined, ltr('paperMarks', l), () => go(const PaperMarksScreen())),
      (const ValueKey('tool-worksheet'), Icons.print_outlined, it('worksheet', l), () => go(const WorksheetScreen())),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tools = _ToolStrip.tools(context, lang);
    return Wrap(
      spacing: 20,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [for (final (k, i, label, onTap) in tools) BigButton(key: k, icon: i, label: label, filled: false, onPressed: onTap)],
    );
  }
}
