import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/mastery.dart';
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/insight/analysis.dart';
import 'package:zynetix_board/features/insight/today_plan.dart';
import 'package:zynetix_board/features/insight/worksheet.dart';

import 'helpers.dart';

const motion = 'puc1-physics-02-motion-in-a-straight-line';
final day = DateTime(2026, 11, 4, 9);

Response resp(int? roll, String topic, bool ok, {DateTime? at}) =>
    Response(roll: roll, questionId: 'q', topicId: topic, chapterId: chapterOf(topic), correct: ok, source: roll == null ? 'monitor' : 'roll_call', at: at ?? day);

Block blk(String id, BlockType t) => Block(t, {'id': id, 'type': t.wire});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quiz outcome: the last answer per question counts; missed questions and rolls', () {
    final answers = [
      {'questionId': 'a', 'correct': false, 'roll': 3},
      {'questionId': 'a', 'correct': true, 'roll': 3}, // went back over it
      {'questionId': 'b', 'correct': false, 'roll': 7},
      {'questionId': 'c', 'correct': false, 'roll': 9},
      {'questionId': 'other', 'correct': false},
    ];
    final o = QuizOutcome.from(answers, ['a', 'b', 'c']);
    expect((o.total, o.correct), (3, 1));
    expect(o.missed, ['b', 'c']);
    expect(o.wrongRolls, {7, 9});
    expect(o.rightRolls, {3});
    expect(o.needsReteach, isTrue);
    expect(QuizOutcome.from([for (final q in ['a', 'b']) {'questionId': q, 'correct': true}], ['a', 'b']).needsReteach, isFalse);
    expect(QuizOutcome.from(const [], ['a']).needsReteach, isFalse, reason: 'nothing answered: nothing to re-teach');
  });

  test('re-teach block: an approach type not yet shown, then a block not shown, then any', () {
    final l = Lesson(id: 'l', chapterId: 'c', topicId: 't', title: const L10n('L'), minutes: 40, blocks: [
      blk('intro', BlockType.intro),
      blk('wb', BlockType.whiteboard),
      blk('sim', BlockType.simulation),
      blk('ex', BlockType.example),
      blk('quiz', BlockType.classQuiz),
    ]);
    expect(reteachBlock(l, ['intro', 'wb', 'quiz'])!.id, 'sim', reason: 'simulation is a type the class has not seen');
    expect(reteachBlock(l, ['intro', 'wb', 'sim', 'quiz'])!.id, 'ex');
    expect(reteachBlock(l, ['intro', 'wb', 'sim', 'ex', 'quiz'])!.id, 'sim', reason: 'all shown: the first approach, again');
    final plain = Lesson(id: 'l', chapterId: 'c', topicId: 't', title: const L10n('L'), minutes: 40, blocks: [blk('c1', BlockType.concept), blk('q', BlockType.classQuiz)]);
    expect(reteachBlock(plain, ['c1', 'q'])!.id, 'c1');
  });

  test('pair up: buddies from mastery plus rolls who just missed it, with someone who got it', () {
    final m = MasteryStore();
    m.recordAll([resp(1, 't', false), resp(1, 't', false), resp(2, 't', true), resp(2, 't', true)]);
    final o = QuizOutcome.from([
      {'questionId': 'a', 'correct': false, 'roll': 5},
      {'questionId': 'b', 'correct': true, 'roll': 6},
    ], ['a', 'b']);
    expect(pairUp(m, 't', o), [(1, 2), (5, 6)]);
    expect(pairUp(MasteryStore(), 't', o), [(5, 6)]);
    expect(pairUp(MasteryStore(), 't', null), isEmpty);
  });

  test('re-teach time fits inside the period, or is skipped', () {
    final sim = Block(BlockType.simulation, {'id': 's', 'type': 'simulation', 'seconds': 90});
    expect(reteachSeconds(sim, secondsLeft: 900, remainingPlanned: 200), 98); // 90 s + 8 s to settle
    expect(reteachSeconds(sim, secondsLeft: 340, remainingPlanned: 200), 80);
    expect(reteachSeconds(sim, secondsLeft: 280, remainingPlanned: 200), 0);
  });

  test('revision blocks: recap first in priority, in lesson order, within the time', () async {
    final s = await testServices();
    final lesson = s.store.byChapter(motion)!.lessons['$motion.t1']!;
    final r = reviseBlocks(lesson);
    expect(r.map((b) => b.type), contains(BlockType.recap));
    expect(r.length, lessThan(lesson.blocks.length));
    final idx = [for (final b in r) lesson.blocks.indexOf(b)];
    expect(idx, [...idx]..sort());
  });

  test('exam readiness: bands from mastery and coverage, never a rank', () async {
    final s = await testServices(prefs: {'subjects': ['physics', 'chemistry', 'maths', 'biology']});
    final scope = ExamScope.of(s);
    expect(scope.exams, containsAll([Exam.kcet, Exam.neet, Exam.jeeMain, Exam.board]));
    expect(scope.byExam[Exam.neet]!.any((t) => t.contains('-maths-')), isFalse, reason: 'NEET has no maths');
    expect(scope.byExam[Exam.jeeMain]!.any((t) => t.contains('-biology-')), isFalse);
    expect(scope.readiness(s.mastery, Exam.kcet).band, Band.noData);

    final kcet = scope.byExam[Exam.kcet]!;
    // Answers on a few topics only: still not enough coverage to judge.
    s.mastery.recordAll([for (final t in kcet.take(3)) ...[resp(4, t, true), resp(4, t, true)]]);
    final few = scope.readiness(s.mastery, Exam.kcet, roll: 4);
    expect(few.evidenced, 3);
    expect(few.band, Band.noData);
    // Strong answers on most of the syllabus: exam-ready.
    s.mastery.recordAll([for (final t in kcet) ...[resp(4, t, true), resp(4, t, true), resp(4, t, true)]]);
    final r = scope.readiness(s.mastery, Exam.kcet, roll: 4);
    expect(r.coverage, 1);
    expect(r.band, Band.ready);
    // Mostly wrong on half of it: needs work.
    s.mastery.recordAll([for (final t in kcet.take(kcet.length ~/ 2)) ...[resp(8, t, false), resp(8, t, false)]]);
    expect(scope.readiness(s.mastery, Exam.kcet, roll: 8).band, Band.needsWork);
  });

  test('weekly trend groups answers by week, oldest first', () {
    final rs = [
      resp(1, 't', false, at: DateTime(2026, 10, 20)),
      resp(1, 't', true, at: DateTime(2026, 10, 21)),
      resp(1, 't', true, at: DateTime(2026, 10, 28)),
      resp(2, 't', false, at: DateTime(2026, 10, 28)),
    ];
    final w = weeklyTrend(rs, roll: 1);
    expect(w.map((p) => p.weekStart), [DateTime(2026, 10, 19), DateTime(2026, 10, 26)]);
    expect(w.map((p) => p.score), [0.5, 1.0]);
    expect(weeklyTrend(rs).last.total, 2);
  });

  test('worksheet: 10 questions, weighted to the weakest topic, with a PDF and answer key', () async {
    final s = await testServices(prefs: {'taught': ['$motion.t1', '$motion.t2']});
    s.mastery.recordAll([
      for (var i = 0; i < 4; i++) resp(null, '$motion.t3', false),
      for (var i = 0; i < 3; i++) resp(null, '$motion.t2', i > 0),
    ]);
    final qs = pickWorksheet(s, count: 10, rnd: Random(1));
    expect(qs, hasLength(10));
    expect(qs.map((q) => q.id).toSet(), hasLength(10), reason: 'no question twice');
    final by = <String?, int>{};
    for (final q in qs) {
      by[q.topicId] = (by[q.topicId] ?? 0) + 1;
    }
    final pool = s.store.byChapter(motion)!.topicQuestions('$motion.t3').length;
    expect(by['$motion.t3'], min(pool, 5), reason: 'the weakest topic gets the biggest share (half of 10), as far as it has questions');
    expect(by['$motion.t2']!, lessThan(by['$motion.t3']!));

    final roll = pickWorksheet(s, roll: 12, count: 8, rnd: Random(2));
    expect(roll, hasLength(8), reason: 'a roll with no answers gets the class\'s weak topics');

    final w = Worksheet(section: '1st PUC · A', date: day, questions: qs, roll: 12);
    final bytes = await buildWorksheetPdf(w);
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(w.fileName, 'zynetix-practice-roll-12-2026-11-04.pdf');
    expect(answerKey(qs.first), matches(RegExp(r'^[A-D]|[0-9-]')));
  });

  test('plain maths for paper', () {
    expect(plainMath(r'$v = \frac{d}{t}$ and $x^{2}$'), 'v = (d)/(t) and x^(2)');
    expect(plainMath(r'$a \times b$'), 'a × b');
    expect(plainMath('no maths'), 'no maths');
  });

  test('today plan: revise the weakest topic in the last chapter, then the next topic', () async {
    final s = await testServices(prefs: {'taught': ['$motion.t1', '$motion.t2']}, now: day);
    s.mastery.recordAll([for (var i = 0; i < 3; i++) resp(null, '$motion.t1', false), for (var i = 0; i < 3; i++) resp(null, '$motion.t2', true)]);
    final p = TodayPlan.of(s)!;
    expect(p.source, PlanSource.lastChapter);
    expect(p.revise!.lesson.topicId, '$motion.t1');
    expect(p.next!.lesson.topicId, '$motion.t3');

    final booked = await testServices(now: day, prefs: {
      'schedule': jsonEncode([{'date': '2026-11-04', 'start': '11:00', 'end': '11:40', 'topicId': '$motion.t4'}]),
    });
    final b = TodayPlan.of(booked)!;
    expect(b.source, PlanSource.timetable);
    expect(b.next!.lesson.topicId, '$motion.t4');
    expect(b.revise, isNull, reason: 'nothing weak yet');
  });
}
