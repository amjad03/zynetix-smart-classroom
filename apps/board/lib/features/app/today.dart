import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/strings.dart' show subjectName;
import '../../engine/model.dart';
import 'help.dart';
import 'home.dart' show startClass;
import 'kit.dart';
import 'lesson.dart';
import 'now.dart';
import 'school.dart';
import 'shell.dart';

/// What a lesson carries, for badges and "Ready for today".
class LessonKit {
  LessonKit(this.pack, this.lesson, this.board);
  final InstalledPack pack;
  final Lesson lesson;
  final String board;
  late final List<Block> blocks = pack.lessonFor(lesson, board).blocks;
  int count(Set<BlockType> t) => blocks.where((b) => t.contains(b.type)).length;
  int get models => count({BlockType.model3d});
  int get labs => count({BlockType.virtualLab});
  int get sims => count({BlockType.simulation, BlockType.interactive, BlockType.challenge});
  int get questions => pack.topicQuestions(lesson.topicId).length;

  /// The things worth opening on their own, with the step they are on.
  List<(int, Block)> get highlights => [
    for (final (i, b) in blocks.indexed)
      if (const {BlockType.model3d, BlockType.virtualLab, BlockType.simulation, BlockType.interactive}.contains(b.type)) (i, b),
  ];
}

/// A block's name for lists: its title, else its caption, else what it is.
String blockTitle(Block b, Lang l) => (L10n.maybe(b.raw['title']) ?? L10n.maybe(b.raw['caption']) ?? L10n.maybe(b.raw['heading']) ?? L10n(b.type.wire)).t(l).split('\n').first;

IconData blockIcon(BlockType t) => switch (t) {
  BlockType.model3d => Icons.view_in_ar_rounded,
  BlockType.virtualLab => Icons.science_rounded,
  BlockType.simulation => Icons.animation_rounded,
  BlockType.interactive || BlockType.challenge => Icons.touch_app_rounded,
  _ => Icons.slideshow_rounded,
};

/// Today: the class on now with Start class, what happened last time, what is ready for today,
/// and the day's timetable.
class TodayView extends StatelessWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) => SchoolBuilder(
    builder: (context, l, school) {
      final s = ServicesScope.of(context);
      final phone = usePhoneLayout(context);
      final c = classNow(s);
      final now = s.clock();
      final mins = now.hour * 60 + now.minute;
      final today = school.today(now);
      final last = school.history.where((r) => r.subject == c.subject).firstOrNull;
      final kit = c.hasLesson ? LessonKit(c.pack!, c.lesson!, s.config.board) : null;
      void open(int step) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SimpleLessonScreen(pack: c.pack!, lesson: c.lesson!, period: c.period, startStep: step)));
      final startKey = GlobalKey();

      final hero = Container(
        padding: EdgeInsets.all(phone ? 40 : 64),
        decoration: BoxDecoration(color: S.ink, borderRadius: BorderRadius.circular(56), boxShadow: S.shadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Tag(
            c.period == null ? tr(l, 'Next lesson', 'ಮುಂದಿನ ಪಾಠ') : '${c.isNow ? tr(l, 'On now', 'ಈಗ') : tr(l, 'Next', 'ಮುಂದೆ')} · ${Period.clock(c.period!.start)} – ${Period.clock(c.period!.end)}',
            icon: c.isNow ? Icons.circle : Icons.schedule_rounded,
            bg: const Color(0x26FFFFFF),
            fg: Colors.white,
            size: 28,
          ),
          const SizedBox(height: 24),
          Text(classLine(s, c.subject, l, period: c.period), style: tx(34, c: const Color(0xFFC9CBE6), w: FontWeight.w600)),
          Text(c.hasLesson ? c.chapter!.title.t(l) : subjectName(c.subject, l), maxLines: 2, overflow: TextOverflow.ellipsis, style: hd(phone ? 64 : 96, c: Colors.white, l: l)),
          if (c.hasLesson) Text(tr(l, 'Topic ${c.topicNo} of ${c.topicCount} · ${c.lesson!.title.en}', 'ವಿಷಯ ${c.topicNo} / ${c.topicCount} · ${c.lesson!.title.t(l)}'), maxLines: 2, style: tx(36, c: const Color(0xFFE6E8FF))),
          const SizedBox(height: 36),
          Wrap(spacing: 20, runSpacing: 20, children: [
            KeyedSubtree(key: startKey, child: ZxButton(tr(l, 'Start class', 'ತರಗತಿ ಪ್ರಾರಂಭಿಸಿ'), key: const ValueKey('todayStart'), icon: Icons.play_arrow_rounded, bg: Colors.white, fg: S.ink, height: 130, size: 40, onTap: () => startClass(context, c))),
            ZxButton(tr(l, 'Smartboard', 'ಸ್ಮಾರ್ಟ್‌ಬೋರ್ಡ್'), icon: Icons.draw_rounded, bg: const Color(0x26FFFFFF), height: 130, size: 40, onTap: () => openBoard(context, pack: c.pack)),
            if (c.minutesLeft != null) Tag(tr(l, '${c.minutesLeft} min left', 'ಇನ್ನೂ ${c.minutesLeft} ನಿಮಿಷ'), icon: Icons.timer_outlined, bg: const Color(0x26FFFFFF), fg: Colors.white, size: 30),
          ]),
        ]),
      );

      final lastCard = _card(
        l,
        Icons.history_rounded,
        tr(l, 'Last time', 'ಕಳೆದ ಬಾರಿ'),
        last == null
            ? [Text(tr(l, 'No class in this subject on this board yet.', 'ಈ ಬೋರ್ಡ್‌ನಲ್ಲಿ ಈ ವಿಷಯದ ತರಗತಿ ಇನ್ನೂ ಆಗಿಲ್ಲ.'), style: tx(32, c: S.muted))]
            : [
                Text('${shortDate(l, last.at)} · ${last.teacherName}', style: tx(28, c: S.muted)),
                const SizedBox(height: 8),
                Text(last.topic.t(l), style: tx(36, c: S.ink, w: FontWeight.w700)),
                Text(tr(l, '${last.stepsSeen} of ${last.stepsTotal} steps · ${last.present} of ${last.rollCount} present', '${last.stepsTotal} ರಲ್ಲಿ ${last.stepsSeen} ಹಂತ · ${last.rollCount} ರಲ್ಲಿ ${last.present} ಹಾಜರು'), style: tx(30, c: S.cardText)),
                if (last.homework.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(color: S.butter, borderRadius: BorderRadius.circular(32)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(l, 'Homework to check', 'ಪರಿಶೀಲಿಸಬೇಕಾದ ಮನೆಗೆಲಸ'), style: tx(28, c: S.eyebrow, w: FontWeight.w600)),
                      Text(last.homework, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx(30, c: S.ink)),
                    ]),
                  ),
                ],
              ],
      );

      final ready = _card(l, Icons.inventory_2_rounded, tr(l, 'Ready for today', 'ಇಂದಿಗೆ ಸಿದ್ಧ'), [
        if (kit == null)
          Text(tr(l, 'No lesson installed for this subject yet.', 'ಈ ವಿಷಯಕ್ಕೆ ಇನ್ನೂ ಪಾಠ ಇಲ್ಲ.'), style: tx(32, c: S.muted))
        else ...[
          _row(l, Icons.slideshow_rounded, S.lavender, tr(l, 'Lesson · ${kit.blocks.length} steps${s.voice?.track(kit.pack, kit.lesson, l) != null ? ', voice' : ''}', 'ಪಾಠ · ${kit.blocks.length} ಹಂತ'), () => open(c.lastStep)),
          for (final (i, b) in kit.highlights.take(4)) _row(l, blockIcon(b.type), S.mint, blockTitle(b, l), () => open(i)),
          if (kit.questions > 0) _row(l, Icons.quiz_rounded, S.butter, tr(l, '${kit.questions} exam questions', '${kit.questions} ಪರೀಕ್ಷಾ ಪ್ರಶ್ನೆಗಳು'), () => open(kit.blocks.indexWhere((b) => b.type == BlockType.pyq || b.type == BlockType.classQuiz).clamp(0, kit.blocks.length - 1))),
        ],
      ]);

      final timetable = _card(l, Icons.calendar_month_rounded, tr(l, 'Today’s timetable', 'ಇಂದಿನ ವೇಳಾಪಟ್ಟಿ'), [
        if (today.isEmpty)
          Text(tr(l, 'No timetable yet. The school sets it in Settings → Timetable.', 'ವೇಳಾಪಟ್ಟಿ ಇನ್ನೂ ಇಲ್ಲ. ಶಾಲೆ ಸೆಟ್ಟಿಂಗ್ಸ್ → ವೇಳಾಪಟ್ಟಿಯಲ್ಲಿ ಹೊಂದಿಸುತ್ತದೆ.'), style: tx(30, c: S.muted)),
        for (final (i, p) in today.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.fromLTRB(32, 24, 28, 24),
            decoration: BoxDecoration(
              color: p.startMin <= mins && mins < p.endMin ? S.sky : S.mist,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: p.startMin <= mins && mins < p.endMin ? S.violet : Colors.transparent, width: 4),
            ),
            child: Row(children: [
              SizedBox(
                width: 150,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Period.clock(p.start), style: hd(44)),
                  Text('P${i + 1}', style: tx(26, c: S.muted)),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(classLine(s, p.subject, l, period: p), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(32, c: S.ink, w: FontWeight.w700)),
                  if (school.teacher(p.teacherId) case final t?) Text(t.name, style: tx(28, c: S.muted)),
                ]),
              ),
              if (p.endMin <= mins) const Icon(Icons.check_circle_rounded, size: 48, color: S.green),
              if (p.startMin <= mins && mins < p.endMin) Tag(tr(l, 'Now', 'ಈಗ'), bg: S.violet, fg: Colors.white, size: 26),
            ]),
          ),
      ]);

      final help = HelpInfo(
        next: c.hasLesson ? const L10n('Tap Start class to open the lesson where you left off.', 'ನೀವು ನಿಲ್ಲಿಸಿದಲ್ಲಿಂದ ಪಾಠ ತೆರೆಯಲು “ತರಗತಿ ಪ್ರಾರಂಭಿಸಿ” ಒತ್ತಿ.') : const L10n('Open Teach on the left and pick a chapter.', 'ಎಡಭಾಗದ “ಪಾಠ” ತೆರೆಯಿರಿ, ಅಧ್ಯಾಯ ಆರಿಸಿ.'),
        detail: const L10n('Tap anything under Ready for today to open the lesson right at that step.', '“ಇಂದಿಗೆ ಸಿದ್ಧ” ದಲ್ಲಿ ಯಾವುದನ್ನಾದರೂ ಒತ್ತಿದರೆ ಪಾಠ ಆ ಹಂತದಲ್ಲೇ ತೆರೆಯುತ್ತದೆ.'),
        target: startKey,
      );
      final header = SectionHeader(crumb: '${s.config.collegeName} · ${shortDate(l, now)}', title: '${greeting(l, now)}${school.current == null ? '' : ', ${school.current!.firstName}'}', help: () => help, trailing: [if (!phone) offlineTag(l)]);
      if (phone) {
        return ListView(padding: const EdgeInsets.only(bottom: 40), children: [header, const SizedBox(height: 28), hero, const SizedBox(height: 28), ready, const SizedBox(height: 28), timetable, const SizedBox(height: 28), lastCard]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        const SizedBox(height: 36),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 7,
              child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
                hero,
                const SizedBox(height: 36),
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: lastCard), const SizedBox(width: 36), Expanded(child: ready)])),
              ]),
            ),
            const SizedBox(width: 40),
            Expanded(flex: 4, child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 40), child: timetable)),
          ]),
        ),
      ]);
    },
  );

  Widget _card(Lang l, IconData icon, String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), border: Border.all(color: S.line, width: 3)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 48, color: S.violet), const SizedBox(width: 18), Expanded(child: Text(title, style: hd(52, l: l)))]),
      const SizedBox(height: 24),
      ...children,
    ]),
  );

  Widget _row(Lang l, IconData icon, Color bg, String text, VoidCallback onTap) => Press(
    radius: 24,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)), child: Icon(icon, size: 40, color: S.ink)),
        const SizedBox(width: 22),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(32, c: S.ink, w: FontWeight.w500))),
        const Icon(Icons.chevron_right_rounded, size: 48, color: S.muted),
      ]),
    ),
  );
}
