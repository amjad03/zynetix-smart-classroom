import { Body, Controller, Delete, Get, Inject, NotFoundException, Param, ParseIntPipe, Post, Put, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { Board, Subject } from '@zynetix/lesson-schema';
import { CurrentStaff, Roles, Staff, StaffGuard, collegeOf } from './auth';
import { DB, Db } from './db/db';
import { Zod, sha256, token } from './infra';

const hm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);
const Section = z.object({ id: z.string().regex(/^[a-z0-9-]+$/), label: z.string().min(1), year: z.enum(['puc1', 'puc2']), rollCount: z.number().int().min(1).max(300), periodMinutes: z.number().int().min(20).max(90).default(40), board: Board.default('kar_pu'), subjects: z.array(Subject).min(1).default(['physics', 'chemistry', 'maths', 'biology']) }).strict();
const Slot = z.object({ day: z.number().int().min(1).max(6), period: z.number().int().min(1).max(12), start: hm, end: hm, subject: z.string(), teacher: z.string().max(80).optional() }).strict();
const Booking = z.object({ sectionId: z.string(), date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/), start: hm, end: hm, topicId: z.string(), reason: z.string().max(200).optional() }).strict()
  .refine((b) => b.start < b.end, 'end must be after start');
const Pin = z.object({ pin: z.string().regex(/^\d{4,6}$/) }).strict();

/** College Admin: sections, boards, timetable, Self-Learning scheduler, reports. Scoped to the admin's college. */
@Controller('v1/admin')
@UseGuards(StaffGuard)
@Roles('admin')
export class AdminController {
  constructor(@Inject(DB) private db: Db) {}

  private async ownSection(s: Staff, sectionId: string, college?: string) {
    const c = collegeOf(s, college);
    const sec = await this.db.one('SELECT * FROM section WHERE id = $1 AND college_id = $2', [sectionId, c]);
    if (!sec) throw new NotFoundException({ code: 'no_such_section' });
    return sec;
  }

  @Get('sections')
  sections(@CurrentStaff() s: Staff, @Query('college') college?: string) {
    return this.db.q('SELECT id, label, year, board, roll_count AS "rollCount", period_minutes AS "periodMinutes", subjects FROM section WHERE college_id = $1 ORDER BY year, label', [collegeOf(s, college)]);
  }

  @Post('sections')
  async addSection(@CurrentStaff() s: Staff, @Body(new Zod(Section)) b: z.infer<typeof Section>, @Query('college') college?: string) {
    await this.db.q('INSERT INTO section(id, college_id, label, year, board, roll_count, period_minutes, subjects) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)', [b.id, collegeOf(s, college), b.label, b.year, b.board, b.rollCount, b.periodMinutes, b.subjects]);
    return b;
  }

  @Get('boards')
  boards(@CurrentStaff() s: Staff, @Query('college') college?: string) {
    return this.db.q(`SELECT d.id, d.name, d.section_id AS "sectionId", s.label AS section, d.activated_at AS "activatedAt", d.last_seen_at AS "lastSeenAt",
      (SELECT count(*)::int FROM session_log l WHERE l.device_id = d.id) AS sessions
      FROM device d JOIN section s ON s.id = d.section_id WHERE d.college_id = $1 ORDER BY s.label`, [collegeOf(s, college)]);
  }

  /** A one-time code to type on a new board (valid 7 days). */
  @Post('sections/:id/activation-code')
  async code(@CurrentStaff() s: Staff, @Param('id') id: string, @Query('college') college?: string) {
    const sec = await this.ownSection(s, id, college);
    const code = token(6).replace(/[^A-Za-z0-9]/g, 'X').slice(0, 8).toUpperCase();
    await this.db.q("INSERT INTO activation_code(code, college_id, section_id, expires_at) VALUES ($1,$2,$3, now() + interval '7 days')", [code, sec.college_id, id]);
    return { code, section: sec.label, expiresInDays: 7 };
  }

  /** New teacher PIN for a board; reaches it on its next sync. */
  @Put('boards/:id/pin')
  async pin(@CurrentStaff() s: Staff, @Param('id') id: string, @Body(new Zod(Pin)) b: z.infer<typeof Pin>, @Query('college') college?: string) {
    const salt = token(8);
    const r = await this.db.q('UPDATE device SET pin_hash = $1, pin_salt = $2 WHERE id = $3 AND college_id = $4 RETURNING id', [sha256(`${salt}:${b.pin}`), salt, id, collegeOf(s, college)]);
    if (!r.length) throw new NotFoundException();
    return { ok: true };
  }

  @Get('sections/:id/timetable')
  async timetable(@CurrentStaff() s: Staff, @Param('id') id: string, @Query('college') college?: string) {
    await this.ownSection(s, id, college);
    return this.db.q('SELECT day, period, start_time AS start, end_time AS end, subject, teacher FROM timetable_slot WHERE section_id = $1 ORDER BY day, period', [id]);
  }

  /** Replaces a section's whole weekly timetable. */
  @Put('sections/:id/timetable')
  async setTimetable(@CurrentStaff() s: Staff, @Param('id') id: string, @Body(new Zod(z.array(Slot).max(80))) slots: z.infer<typeof Slot>[], @Query('college') college?: string) {
    await this.ownSection(s, id, college);
    await this.db.tx(async (c) => {
      await c.query('DELETE FROM timetable_slot WHERE section_id = $1', [id]);
      for (const t of slots) await c.query('INSERT INTO timetable_slot(section_id, day, period, start_time, end_time, subject, teacher) VALUES ($1,$2,$3,$4,$5,$6,$7)', [id, t.day, t.period, t.start, t.end, t.subject, t.teacher ?? null]);
    });
    return { saved: slots.length };
  }

  @Get('self-learning')
  bookings(@CurrentStaff() s: Staff, @Query('from') from?: string, @Query('college') college?: string) {
    return this.db.q(`SELECT b.id, b.section_id AS "sectionId", s.label AS section, to_char(b.date,'YYYY-MM-DD') AS date, b.start_time AS start, b.end_time AS end, b.topic_id AS "topicId", b.reason
      FROM self_learning_booking b JOIN section s ON s.id = b.section_id WHERE s.college_id = $1 AND b.date >= coalesce($2::date, current_date) ORDER BY b.date, b.start_time`, [collegeOf(s, college), from ?? null]);
  }

  /** Books a Self-Learning period (teacher absent). The board starts it on its own at that time. */
  @Post('self-learning')
  async book(@CurrentStaff() s: Staff, @Body(new Zod(Booking)) b: z.infer<typeof Booking>, @Query('college') college?: string) {
    await this.ownSection(s, b.sectionId, college);
    const ch = await this.db.one("SELECT id FROM chapter, jsonb_array_elements(topics) t WHERE t->>'id' = $1", [b.topicId]);
    if (!ch) throw new NotFoundException({ code: 'no_such_topic' });
    const r = await this.db.one('INSERT INTO self_learning_booking(section_id, date, start_time, end_time, topic_id, reason, created_by) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id', [b.sectionId, b.date, b.start, b.end, b.topicId, b.reason ?? null, s.email]);
    return { id: r.id };
  }

  @Delete('self-learning/:id')
  async unbook(@CurrentStaff() s: Staff, @Param('id', ParseIntPipe) id: number, @Query('college') college?: string) {
    await this.db.q('DELETE FROM self_learning_booking b USING section s WHERE b.id = $1 AND s.id = b.section_id AND s.college_id = $2', [id, collegeOf(s, college)]);
    return { ok: true };
  }

  /** Syllabus heatmap: for each section × chapter, the share of topics taught (any mode, completed). */
  @Get('reports/syllabus')
  async syllabus(@CurrentStaff() s: Staff, @Query('college') college?: string) {
    const c = collegeOf(s, college);
    const sections = await this.db.q('SELECT id, label, year, board, subjects FROM section WHERE college_id = $1 ORDER BY year, label', [c]);
    const chapters = await this.db.q("SELECT id, subject, year, number, title->>'en' AS title, jsonb_array_length(topics) AS topics, boards FROM chapter ORDER BY subject, year, number");
    const taught = await this.db.q(`SELECT l.section_id AS "sectionId", l.chapter_id AS "chapterId", count(DISTINCT l.topic_id)::int AS taught
      FROM session_log l JOIN section s ON s.id = l.section_id WHERE s.college_id = $1 AND l.completed GROUP BY 1, 2`, [c]);
    const t = new Map(taught.map((r) => [`${r.sectionId}|${r.chapterId}`, r.taught]));
    return {
      sections: sections.map((x) => ({ id: x.id, label: x.label, year: x.year, board: x.board, subjects: x.subjects })),
      chapters,
      cells: sections.flatMap((sec) => chapters.filter((ch) => ch.year === sec.year && sec.subjects.includes(ch.subject) && ch.boards.includes(sec.board)).map((ch) => ({
        sectionId: sec.id, chapterId: ch.id, taught: t.get(`${sec.id}|${ch.id}`) ?? 0, topics: ch.topics,
        share: ch.topics ? Math.min(1, (t.get(`${sec.id}|${ch.id}`) ?? 0) / ch.topics) : null,
      }))),
    };
  }

  /** Usage: sessions and minutes per day and mode, quiz accuracy, boards seen. */
  @Get('reports/usage')
  async usage(@CurrentStaff() s: Staff, @Query('from') from?: string, @Query('to') to?: string, @Query('college') college?: string) {
    const c = collegeOf(s, college);
    const args = [c, from ?? null, to ?? null];
    const where = `s.college_id = $1 AND l.started_at >= coalesce($2::date, current_date - 30) AND l.started_at < coalesce($3::date, current_date) + 1`;
    const daily = await this.db.q(`SELECT to_char(l.started_at::date,'YYYY-MM-DD') AS day, l.mode, count(*)::int AS sessions,
      round(sum(extract(epoch FROM coalesce(l.ended_at, l.started_at) - l.started_at)) / 60)::int AS minutes
      FROM session_log l JOIN section s ON s.id = l.section_id WHERE ${where} GROUP BY 1, 2 ORDER BY 1`, args);
    const bySection = await this.db.q(`SELECT s.label AS section, count(*)::int AS sessions, count(*) FILTER (WHERE l.mode = 'self_learning')::int AS "selfLearning",
      sum(jsonb_array_length(l.answers))::int AS answers,
      sum((SELECT count(*) FROM jsonb_array_elements(l.answers) a WHERE (a->>'correct')::boolean))::int AS correct
      FROM session_log l JOIN section s ON s.id = l.section_id WHERE ${where} GROUP BY s.label ORDER BY s.label`, args);
    const boards = await this.db.one(`SELECT count(*)::int AS total, count(*) FILTER (WHERE last_seen_at > now() - interval '7 days')::int AS active FROM device WHERE college_id = $1`, [c]);
    return { daily, bySection, boards };
  }

  /** Chapters (with topics) for pickers in the Admin app. */
  @Get('syllabus')
  chapters() {
    return this.db.q("SELECT id, subject, year, number, title, topics, boards, EXISTS (SELECT 1 FROM pack_version v JOIN pack p ON p.id = v.pack_id WHERE p.chapter_id = chapter.id) AS \"hasPack\" FROM chapter ORDER BY subject, year, number");
  }
}
