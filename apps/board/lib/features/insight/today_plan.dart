import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../engine/mastery.dart';
import '../../engine/model.dart';
import '../player.dart';
import 'analysis.dart';
import 'reteach.dart';
import 'strings.dart';

typedef PlayTopic = ({InstalledPack pack, Lesson lesson});

enum PlanSource { timetable, lastChapter, nextTopic }

/// The next period for this section: "5 min revise (the weakest topic in the current chapter),
/// then (the next topic)". The chapter is the next booked period's (timetable) when there is one
/// today, else the one taught last, else the next topic's.
class TodayPlan {
  TodayPlan({required this.source, required this.chapterId, this.revise, this.reviseEstimate, this.next, this.at});
  final PlanSource source;
  final String chapterId;
  final PlayTopic? revise;
  final Estimate? reviseEstimate;
  final PlayTopic? next;

  /// When the booked period starts (timetable only).
  final DateTime? at;

  static const reviseMinutes = 5;

  bool get isEmpty => revise == null && next == null;

  /// Works the plan out from the board's config and mastery; null when there is nothing to teach.
  static TodayPlan? of(Services s) {
    final now = s.clock();
    final booked = [
      for (final p in s.config.schedule)
        if (p.endsAt.isAfter(now) && p.startsAt.year == now.year && p.startsAt.month == now.month && p.startsAt.day == now.day) p,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    PlayTopic? next;
    String? chapter;
    PlanSource source;
    DateTime? at;
    final b = booked.firstOrNull;
    if (b != null && s.lessonFor(b.topicId) != null) {
      next = s.lessonFor(b.topicId);
      chapter = chapterOf(b.topicId);
      source = PlanSource.timetable;
      at = b.startsAt;
    } else if (s.config.taught.isNotEmpty) {
      chapter = chapterOf(s.config.taught.last);
      source = PlanSource.lastChapter;
      final pack = s.store.byChapter(chapter);
      final taught = s.config.taught.toSet();
      for (final t in pack?.chapter.topicsFor(s.config.board) ?? const <Topic>[]) {
        final l = pack!.lessons[t.id];
        if (l != null && !taught.contains(t.id)) {
          next = (pack: pack, lesson: l);
          break;
        }
      }
      next ??= s.nextTopic();
    } else {
      next = s.nextTopic();
      if (next == null) return null;
      chapter = next.pack.chapter.id;
      source = PlanSource.nextTopic;
    }
    final weak = s.mastery.weakTopics(n: 20, where: (t) => chapterOf(t) == chapter && t != next?.lesson.topicId);
    PlayTopic? revise;
    for (final t in weak) {
      revise = s.lessonFor(t);
      if (revise != null) break;
    }
    if (revise == null && next == null) return null;
    return TodayPlan(source: source, chapterId: chapter, revise: revise, reviseEstimate: revise == null ? null : s.mastery.classTopic(revise.lesson.topicId), next: next, at: at);
  }

  /// One tap: the five-minute revision (if any), then the next topic in the lesson player.
  void start(BuildContext context) {
    final s = ServicesScope.of(context), nav = Navigator.of(context), n = next;
    void teachNext() => n == null ? nav.pop() : nav.pushReplacement(MaterialPageRoute<void>(builder: (_) => LessonPlayerScreen(pack: n.pack, lesson: n.lesson)));
    final r = revise;
    if (r == null) {
      if (n != null) nav.push(MaterialPageRoute<void>(builder: (_) => LessonPlayerScreen(pack: n.pack, lesson: n.lesson)));
      return;
    }
    final lesson = r.pack.lessonFor(r.lesson, s.config.board);
    final l = s.config.lang;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ReplayScreen(
          pack: r.pack,
          lesson: lesson,
          blocks: reviseBlocks(lesson, seconds: reviseMinutes * 60),
          title: '${it('revise', l)}: ${lesson.title.t(l)}',
          doneLabel: n == null ? null : it('reviseDone', l),
          onDone: teachNext,
        ),
      ),
    );
  }
}

/// The "next period" card for Home or Teacher Mode: what to revise and what comes next, and a
/// Start button. Renders nothing when there is nothing to plan.
class TodayPlanCard extends StatelessWidget {
  const TodayPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.config, s.mastery]),
      builder: (context, _) {
        final plan = TodayPlan.of(s);
        if (plan == null) return const SizedBox.shrink();
        final l = s.config.lang;
        final at = plan.at;
        final when = switch (plan.source) {
          PlanSource.timetable => '${it('fromTimetable', l)}${at == null ? '' : ' · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'}',
          PlanSource.lastChapter => it('fromLastChapter', l),
          PlanSource.nextTopic => tr('nextTopic', l),
        };
        final steps = [
          if (plan.revise != null)
            '${TodayPlan.reviseMinutes} ${it('min', l)} ${it('revise', l).toLowerCase()} ${plan.revise!.lesson.title.t(l)}${plan.reviseEstimate == null ? '' : ' (${(plan.reviseEstimate!.p * 100).round()}%)'}',
          if (plan.next != null) plan.next!.lesson.title.t(l),
        ];
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${it('todayPlan', l)} · $when', style: zText(28, FontWeight.w400).copyWith(color: Z.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(steps.join(', ${it('thenTeach', l)} '), style: zTitle(context.narrow ? 32 : 36, FontWeight.w500), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        );
        final button = BigButton(key: const ValueKey('startPlan'), icon: Icons.play_arrow, label: it('startPlan', l), onPressed: () => plan.start(context));
        return Card(
          key: const ValueKey('todayPlan'),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.narrow ? 28 : 44, vertical: context.narrow ? 24 : 32),
            child: context.portrait
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [body, const SizedBox(height: 16), button])
                : Row(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(color: Z.segTrack, borderRadius: BorderRadius.circular(28)),
                        child: const Icon(Icons.event_note_outlined, size: 56, color: Z.ink2),
                      ),
                      const SizedBox(width: 36),
                      Expanded(child: body),
                      const SizedBox(width: 20),
                      button,
                    ],
                  ),
          ),
        );
      },
    );
  }
}
