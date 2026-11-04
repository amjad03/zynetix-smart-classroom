import { BadRequestException, Controller, Get, Inject, NotFoundException, Param, ParseIntPipe, Query, UseGuards } from '@nestjs/common';
import { CurrentStaff, Roles, Staff, StaffGuard, collegeOf } from './auth';
import { DB, Db } from './db/db';
import { Ans, Mastery, dayKey, lastWeeks, leaguePoints, level, mean, r2, readiness, snapshots, weekStart } from './outcomes';

type Sec = { id: string; label: string; year: string; board: string; subjects: string[]; rollCount: number };
type TopicInfo = { id: string; title: string; order: number; chapterId: string; chapterNumber: number; chapterTitle: string; subject: string; year: string; boards: string[] };

const WEEK = 7 * 864e5;
const isoDay = (ms: number) => dayKey(ms);

/** Answers of a college (or one section / one roll), oldest first. */
export async function loadAnswers(db: Db, college: string, sectionId?: string, roll?: number): Promise<Ans[]> {
  return db.q<Ans>(
    `SELECT a.section_id AS s, a.topic_id AS t, a.subject AS sub, a.roll AS r, a.correct AS ok, a.source AS src,
            (extract(epoch FROM a.at) * 1000)::float8 AS ms, q.exams
     FROM answer a JOIN section s ON s.id = a.section_id LEFT JOIN question q ON q.id = a.question_id
     WHERE s.college_id = $1 AND ($2::text IS NULL OR a.section_id = $2) AND ($3::int IS NULL OR a.roll = $3)
     ORDER BY a.at, a.log_id, a.idx`, [college, sectionId ?? null, roll ?? null]);
}

async function sectionsOf(db: Db, college: string): Promise<Sec[]> {
  return db.q<Sec>('SELECT id, label, year, board, subjects, roll_count AS "rollCount" FROM section WHERE college_id = $1 ORDER BY year, label', [college]);
}

/** Every syllabus topic with its chapter, in book order. */
async function topicIndex(db: Db) {
  const rows = await db.q<TopicInfo>(
    `SELECT t->>'id' AS id, t->'title'->>'en' AS title, (o - 1)::int AS "order", c.id AS "chapterId", c.number AS "chapterNumber",
            c.title->>'en' AS "chapterTitle", c.subject, c.year, c.boards
     FROM chapter c CROSS JOIN LATERAL jsonb_array_elements(c.topics) WITH ORDINALITY AS x(t, o)
     ORDER BY c.subject, c.year, c.number, o`);
  return new Map(rows.map((r) => [r.id, r]));
}

/** Topics taught (a completed lesson in either mode) per section, with the time they were first taught. */
async function taughtTopics(db: Db, college: string, from?: number, to?: number) {
  const rows = await db.q<{ s: string; t: string; ms: number }>(
    `SELECT l.section_id AS s, l.topic_id AS t, (extract(epoch FROM min(l.started_at)) * 1000)::float8 AS ms
     FROM session_log l JOIN section s ON s.id = l.section_id
     WHERE s.college_id = $1 AND l.completed AND l.started_at >= to_timestamp($2 / 1000.0) AND l.started_at < to_timestamp($3 / 1000.0)
     GROUP BY 1, 2`, [college, from ?? 0, to ?? 4102444800000]);
  const m = new Map<string, Set<string>>();
  for (const r of rows) (m.get(r.s) ?? m.set(r.s, new Set()).get(r.s)!).add(r.t);
  return m;
}

/** The lecturer for a section's subject, from the timetable (staff names only, never students). */
async function teachers(db: Db, college: string) {
  const rows = await db.q<{ s: string; subject: string; teacher: string }>(
    `SELECT DISTINCT ON (t.section_id, t.subject) t.section_id AS s, t.subject, t.teacher
     FROM timetable_slot t JOIN section s ON s.id = t.section_id WHERE s.college_id = $1 AND t.teacher IS NOT NULL
     GROUP BY 1, 2, 3 ORDER BY t.section_id, t.subject, count(*) DESC`, [college]);
  return new Map(rows.map((r) => [`${r.s}|${r.subject}`, r.teacher]));
}

/** For each exam, the topics with tagged questions in a section's syllabus. */
async function examTopics(db: Db, sec: Sec) {
  const rows = await db.q<{ exam: string; topics: string[] }>(
    `SELECT e AS exam, array_agg(DISTINCT q.topic_id) AS topics
     FROM question q JOIN chapter c ON c.id = q.chapter_id CROSS JOIN LATERAL unnest(q.exams) e
     WHERE c.year = $1 AND c.subject = ANY($2) AND $3 = ANY(c.boards) AND q.topic_id IS NOT NULL GROUP BY e ORDER BY e`,
    [sec.year, sec.subjects, sec.board]);
  const order = ['PUC', 'CBSE', 'KCET', 'COMEDK', 'NEET', 'JEE', 'JEE_ADV', 'CUET'];
  // Each board's own board exam only (a Karnataka PU section is not sitting the CBSE board exam).
  const other = sec.board === 'cbse' ? ['PUC'] : ['CBSE'];
  return rows.filter((r) => !other.includes(r.exam)).sort((a, b) => order.indexOf(a.exam) - order.indexOf(b.exam)).map((r) => ({ exam: r.exam, topics: new Set(r.topics) }));
}

async function collegeInfo(db: Db, college: string) {
  return db.one<{ id: string; name: string; district: string | null; demo: boolean }>('SELECT id, name, district, demo FROM college WHERE id = $1', [college]);
}

/** League points per section for each week (oldest first). */
export async function league(db: Db, college: string, weeks: number[]) {
  const secs = await sectionsOf(db, college);
  const from = weeks[0], to = weeks[weeks.length - 1] + WEEK;
  const ans = await db.q<{ s: string; w: number; correct: number; stars: number }>(
    `SELECT a.section_id AS s, (extract(epoch FROM date_trunc('week', a.at AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata') * 1000)::float8 AS w,
            count(*) FILTER (WHERE a.correct)::int AS correct, count(*) FILTER (WHERE a.correct AND a.source = 'challenge')::int AS stars
     FROM answer a JOIN section s ON s.id = a.section_id
     WHERE s.college_id = $1 AND a.at >= to_timestamp($2 / 1000.0) AND a.at < to_timestamp($3 / 1000.0) GROUP BY 1, 2`, [college, from, to]);
  const days = await db.q<{ s: string; d: string }>(
    `SELECT DISTINCT l.section_id AS s, to_char(l.started_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD') AS d
     FROM session_log l JOIN section s ON s.id = l.section_id
     WHERE s.college_id = $1 AND l.completed AND l.started_at >= to_timestamp($2 / 1000.0) AND l.started_at < to_timestamp($3 / 1000.0)`, [college, from, to]);
  return secs.map((sec) => ({
    sectionId: sec.id,
    label: sec.label,
    weeks: weeks.map((w) => {
      const a = ans.find((x) => x.s === sec.id && Math.abs(x.w - w) < 3600e3);
      const active = new Set(days.filter((d) => d.s === sec.id).map((d) => d.d));
      return { week: isoDay(w), ...leaguePoints(a?.correct ?? 0, a?.stars ?? 0, sec.rollCount, active, w) };
    }),
  }));
}

/** This week's league for a college, as the board receives it in its config (a JSON string). */
export async function leagueConfig(db: Db, college: string, now = Date.now()) {
  const rows = await league(db, college, [weekStart(now)]);
  return JSON.stringify(rows.map((r) => ({ sectionId: r.sectionId, label: r.label, points: r.weeks[0].points })).sort((a, b) => b.points - a.points));
}

const pct = (x: number, n: number) => (n ? Math.round((100 * x) / n) / 100 : null);

/**
 * Outcomes for the principal: what each section understands, not just what was taught.
 * Scoped to the admin's college; roll numbers only.
 */
@Controller('v1/admin/outcomes')
@UseGuards(StaffGuard)
@Roles('admin')
export class OutcomesController {
  constructor(@Inject(DB) private db: Db) {}

  private async ownSection(s: Staff, id: string, college?: string) {
    const c = collegeOf(s, college);
    const sec = (await sectionsOf(this.db, c)).find((x) => x.id === id);
    if (!sec) throw new NotFoundException({ code: 'no_such_section' });
    return { c, sec };
  }

  /**
   * Dashboard: per section × subject, class mastery by week, topics taught vs mastered,
   * share of roll numbers stuck per topic, and the lecturer (for teacher/section comparison).
   */
  @Get()
  async overview(@CurrentStaff() s: Staff, @Query('weeks') w?: string, @Query('college') college?: string) {
    const c = collegeOf(s, college);
    const n = Math.min(26, Math.max(2, Number(w) || 8));
    const weeks = lastWeeks(n);
    const [info, secs, ans, topics, taught, teach] = await Promise.all([
      collegeInfo(this.db, c), sectionsOf(this.db, c), loadAnswers(this.db, c), topicIndex(this.db), taughtTopics(this.db, c), teachers(this.db, c),
    ]);
    const rows = [];
    const stuckTopics = [];
    for (const sec of secs) {
      const mine = ans.filter((a) => a.s === sec.id);
      const now = new Mastery();
      mine.forEach((a) => now.apply(a));
      for (const subject of sec.subjects) {
        const subj = (t: string) => topics.get(t)?.subject === subject;
        const sa = mine.filter((a) => a.sub === subject || (a.sub == null && subj(a.t)));
        const trend = snapshots(sa, weeks.map((x) => x + WEEK), () => true);
        const perWeek = weeks.map((x) => sa.filter((a) => a.ms >= x && a.ms < x + WEEK).length);
        const taughtHere = [...(taught.get(sec.id) ?? [])].filter(subj);
        const assessed = [...now.topic.keys()].filter((t) => subj(t) && now.topic.get(t)!.n >= 2);
        const mastered = assessed.filter((t) => level(now.classTopic(t)) === 'mastered');
        const shares = [];
        for (const t of assessed) {
          const r = now.rollsOn(t);
          if (r.assessed < 5) continue;
          shares.push(r.stuck.length / r.assessed);
          const ti = topics.get(t);
          stuckTopics.push({ sectionId: sec.id, section: sec.label, subject, topicId: t, title: ti?.title ?? t, chapter: ti ? `${ti.chapterNumber}. ${ti.chapterTitle}` : '', stuck: r.stuck.length, assessed: r.assessed, share: r2(r.stuck.length / r.assessed) });
        }
        if (!sa.length && !taughtHere.length) {
          rows.push({ sectionId: sec.id, subject, teacher: teach.get(`${sec.id}|${subject}`) ?? null, trend: weeks.map(() => null), answersPerWeek: perWeek, mastery: null, change: null, topicsTaught: 0, topicsAssessed: 0, topicsMastered: 0, stuckShare: null, answers: 0, accuracy: null, rollsAssessed: 0 });
          continue;
        }
        const first = trend.find((x) => x != null) ?? null, last = trend[trend.length - 1];
        const rolls = new Set(sa.filter((a) => a.r != null).map((a) => a.r));
        rows.push({
          sectionId: sec.id, subject, teacher: teach.get(`${sec.id}|${subject}`) ?? null, trend, answersPerWeek: perWeek,
          mastery: last, change: first != null && last != null ? r2(last - first) : null,
          topicsTaught: taughtHere.length, topicsAssessed: assessed.length, topicsMastered: mastered.length,
          stuckShare: r2(mean(shares)), answers: sa.length, accuracy: pct(sa.filter((a) => a.ok).length, sa.length), rollsAssessed: rolls.size,
        });
      }
    }
    stuckTopics.sort((a, b) => b.share! - a.share! || b.stuck - a.stuck);
    return {
      college: info, weeks: weeks.map(isoDay),
      sections: secs, rows, stuckTopics: stuckTopics.slice(0, 12),
    };
  }

  /** Section drill-down: topics × roll numbers (estimate and number of answers per cell). */
  @Get('sections/:id')
  async section(@CurrentStaff() s: Staff, @Param('id') id: string, @Query('subject') subject?: string, @Query('college') college?: string) {
    const { c, sec } = await this.ownSection(s, id, college);
    const sub = subject && sec.subjects.includes(subject) ? subject : sec.subjects[0];
    const [ans, topics, taught, teach] = await Promise.all([loadAnswers(this.db, c, id), topicIndex(this.db), taughtTopics(this.db, c), teachers(this.db, c)]);
    const m = new Mastery();
    ans.forEach((a) => m.apply(a));
    const taughtHere = taught.get(id) ?? new Set();
    const list = [...topics.values()]
      .filter((t) => t.subject === sub && t.year === sec.year && t.boards.includes(sec.board) && (taughtHere.has(t.id) || m.topic.has(t.id)))
      .map((t) => {
        const e = m.classTopic(t.id), r = m.rollsOn(t.id);
        return {
          id: t.id, title: t.title, chapterId: t.chapterId, chapterNumber: t.chapterNumber, chapterTitle: t.chapterTitle, taught: taughtHere.has(t.id),
          class: e ? { p: r2(e.p), n: e.n, level: level(e) } : null, assessed: r.assessed, stuck: r.stuck, learning: r.learning, mastered: r.mastered,
        };
      });
    const ids = new Set(list.map((t) => t.id));
    const rolls = Array.from({ length: sec.rollCount }, (_, i) => i + 1).map((roll) => {
      const mm = m.roll.get(roll);
      const cells: Record<string, [number, number]> = {};
      for (const [t, e] of mm ?? []) if (ids.has(t)) cells[t] = [r2(e.p)!, e.n];
      const known = Object.values(cells).filter(([, n]) => n >= 2).map(([p]) => p);
      return { roll, overall: r2(mean(known)), stuck: Object.values(cells).filter(([p, n]) => n >= 2 && p < 0.5).length, cells };
    });
    return { section: sec, subject: sub, teacher: teach.get(`${id}|${sub}`) ?? null, topics: list, rolls };
  }

  /** One roll number's report: topic by topic, trend, and exam readiness. Roll number only. */
  @Get('sections/:id/rolls/:roll')
  async roll(@CurrentStaff() s: Staff, @Param('id') id: string, @Param('roll', ParseIntPipe) roll: number, @Query('college') college?: string) {
    const { c, sec } = await this.ownSection(s, id, college);
    if (roll < 1 || roll > sec.rollCount) throw new BadRequestException({ code: 'no_such_roll' });
    const [ans, topics, exams] = await Promise.all([loadAnswers(this.db, c, id, roll), topicIndex(this.db), examTopics(this.db, sec)]);
    const weeks = lastWeeks(8);
    const m = new Mastery();
    const last = new Map<string, number>();
    for (const a of ans) {
      m.apply(a);
      last.set(a.t, a.ms);
    }
    const mine = m.roll.get(roll) ?? new Map();
    const list = [...mine].map(([t, e]) => {
      const ti = topics.get(t);
      return { id: t, title: ti?.title ?? t, subject: ti?.subject ?? null, chapterNumber: ti?.chapterNumber ?? null, chapterTitle: ti?.chapterTitle ?? '', p: r2(e.p), n: e.n, level: level(e), last: isoDay(last.get(t)!) };
    }).sort((a, b) => (a.subject ?? '').localeCompare(b.subject ?? '') || (a.chapterNumber ?? 0) - (b.chapterNumber ?? 0));
    const bySubject = sec.subjects.map((subject) => {
      const ts = list.filter((t) => t.subject === subject && t.level !== 'unknown');
      return { subject, mastery: r2(mean(ts.map((t) => t.p!))), topics: ts.length, mastered: ts.filter((t) => t.level === 'mastered').length, stuck: ts.filter((t) => t.level === 'stuck').length };
    });
    return {
      section: { id: sec.id, label: sec.label, rollCount: sec.rollCount }, roll,
      answers: ans.length, correct: ans.filter((a) => a.ok).length,
      overall: r2(mean(list.filter((t) => t.level !== 'unknown').map((t) => t.p!))),
      weeks: weeks.map(isoDay), trend: snapshots(ans, weeks.map((w) => w + WEEK), () => true),
      bySubject, topics: list,
      stuck: list.filter((t) => t.level === 'stuck').sort((a, b) => a.p! - b.p!),
      strong: list.filter((t) => t.level === 'mastered').sort((a, b) => b.p! - a.p!),
      readiness: exams.map((e) => readiness(ans, e.exam, e.topics, 10)),
    };
  }

  /** Exam readiness per section, from class mastery over each exam's tagged questions. */
  @Get('readiness')
  async readinessAll(@CurrentStaff() s: Staff, @Query('college') college?: string) {
    const c = collegeOf(s, college);
    const [secs, ans] = await Promise.all([sectionsOf(this.db, c), loadAnswers(this.db, c)]);
    const out = [];
    for (const sec of secs) {
      const mine = ans.filter((a) => a.s === sec.id);
      const exams = await examTopics(this.db, sec);
      out.push({ sectionId: sec.id, label: sec.label, board: sec.board, year: sec.year, exams: exams.map((e) => readiness(mine, e.exam, e.topics)) });
    }
    return { sections: out };
  }

  /** League: section points per week (correct answers, challenge stars, teaching-streak days). */
  @Get('league')
  async leagueTable(@CurrentStaff() s: Staff, @Query('weeks') w?: string, @Query('college') college?: string) {
    const c = collegeOf(s, college);
    const weeks = lastWeeks(Math.min(26, Math.max(1, Number(w) || 6)));
    return { weeks: weeks.map(isoDay), sections: await league(this.db, c, weeks) };
  }

  /** Everything for the printable monthly college report (YYYY-MM; default this month). */
  @Get('report')
  async report(@CurrentStaff() s: Staff, @Query('month') month?: string, @Query('college') college?: string) {
    const c = collegeOf(s, college);
    const ym = month && /^\d{4}-(0[1-9]|1[0-2])$/.test(month) ? month : dayKey(Date.now()).slice(0, 7);
    const [y, mo] = ym.split('-').map(Number);
    const from = Date.UTC(y, mo - 1, 1) - 5.5 * 3600e3, to = Date.UTC(y, mo, 1) - 5.5 * 3600e3;
    const [info, secs, ans, topics, taught, teach, totals] = await Promise.all([
      collegeInfo(this.db, c), sectionsOf(this.db, c), loadAnswers(this.db, c), topicIndex(this.db), taughtTopics(this.db, c, from, to), teachers(this.db, c),
      this.db.one(
        `SELECT count(*)::int AS lessons, count(*) FILTER (WHERE l.mode = 'self_learning')::int AS "selfLearning",
                round(sum(extract(epoch FROM coalesce(l.ended_at, l.started_at) - l.started_at)) / 3600)::int AS hours
         FROM session_log l JOIN section s ON s.id = l.section_id
         WHERE s.college_id = $1 AND l.started_at >= to_timestamp($2 / 1000.0) AND l.started_at < to_timestamp($3 / 1000.0)`, [c, from, to]),
    ]);
    const inMonth = ans.filter((a) => a.ms >= from && a.ms < to);
    const sections = [];
    for (const sec of secs) {
      const mine = ans.filter((a) => a.s === sec.id && a.ms < to);
      const now = new Mastery();
      mine.forEach((a) => now.apply(a));
      const subjects = sec.subjects.map((subject) => {
        const subj = (t: string) => topics.get(t)?.subject === subject;
        const sa = mine.filter((a) => a.sub === subject || (a.sub == null && subj(a.t)));
        const [start, end] = snapshots(sa, [from, to], () => true);
        const assessed = [...now.topic.keys()].filter((t) => subj(t) && now.topic.get(t)!.n >= 2);
        const shares = assessed.map((t) => now.rollsOn(t)).filter((r) => r.assessed >= 5).map((r) => r.stuck.length / r.assessed);
        return {
          subject, teacher: teach.get(`${sec.id}|${subject}`) ?? null, taught: [...(taught.get(sec.id) ?? [])].filter(subj).length,
          masteryStart: start, masteryEnd: end, mastered: assessed.filter((t) => level(now.classTopic(t)) === 'mastered').length, assessed: assessed.length,
          stuckShare: r2(mean(shares)), answers: sa.filter((a) => a.ms >= from).length,
        };
      }).filter((x) => x.answers || x.taught);
      const weak = [...now.topic.keys()].map((t) => [t, now.classTopic(t)!] as const).filter(([, e]) => e.n >= 2 && e.p < 0.5).sort((a, b) => a[1].p - b[1].p).slice(0, 3)
        .map(([t, e]) => ({ topicId: t, title: topics.get(t)?.title ?? t, subject: topics.get(t)?.subject ?? null, p: r2(e.p), stuck: now.rollsOn(t).stuck.length }));
      const exams = await examTopics(this.db, sec);
      sections.push({ id: sec.id, label: sec.label, rollCount: sec.rollCount, rollsAssessed: new Set(inMonth.filter((a) => a.s === sec.id && a.r != null).map((a) => a.r)).size, subjects, weak, readiness: exams.map((e) => readiness(mine, e.exam, e.topics)) });
    }
    const monthWeeks: number[] = [];
    for (let w = weekStart(from); w < to; w += WEEK) monthWeeks.push(w);
    const lg = (await league(this.db, c, monthWeeks)).map((r) => ({ sectionId: r.sectionId, label: r.label, points: r.weeks.reduce((a, x) => a + x.points, 0) })).sort((a, b) => b.points - a.points);
    return {
      college: info, month: ym, from: isoDay(from), to: isoDay(to - 1),
      totals: { ...totals, answers: inMonth.length, accuracy: pct(inMonth.filter((a) => a.ok).length, inMonth.length), rollsAssessed: sections.reduce((a, x) => a + x.rollsAssessed, 0), topicsTaught: [...taught.values()].reduce((a, x) => a + x.size, 0) },
      sections, league: lg,
    };
  }
}
