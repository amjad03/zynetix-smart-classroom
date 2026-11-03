import { BadRequestException, Body, ConflictException, Controller, Delete, Get, Inject, NotFoundException, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { Chapter, Exam, Lesson, Question } from '@zynetix/lesson-schema';
import { buildPack } from '@zynetix/pack-builder';
import { z } from 'zod';
import { CurrentStaff, Roles, Staff, StaffGuard } from './auth';
import { DB, Db } from './db/db';
import { KEYS, Keys, STORAGE, Storage, Zod, sha256 } from './infra';
import { cmpVersion } from './board.controller';

const NewPack = z.object({ id: z.string().regex(/^[a-z0-9][a-z0-9._-]*$/), chapterId: z.string() }).strict();
const Media = z.object({ path: z.string().regex(/^media\/[A-Za-z0-9_\-./]+$/).refine((p) => !p.includes('..')), base64: z.string().max(30_000_000) }).strict();
const Publish = z.object({ bump: z.enum(['major', 'minor', 'patch']).default('minor'), notes: z.string().max(500).optional() }).strict();

/** Content CMS: question bank, block editor drafts, media and versioned pack publishing. */
@Controller('v1/cms')
@UseGuards(StaffGuard)
@Roles('editor')
export class CmsController {
  constructor(@Inject(DB) private db: Db, @Inject(STORAGE) private storage: Storage, @Inject(KEYS) private keys: Keys) {}

  @Get('chapters')
  chapters() {
    return this.db.q(`SELECT c.id, c.subject, c.year, c.number, c.title, c.topics, c.exams, p.id AS "packId",
      (SELECT count(*)::int FROM question q WHERE q.chapter_id = c.id) AS questions
      FROM chapter c LEFT JOIN pack p ON p.chapter_id = c.id ORDER BY c.subject, c.year, c.number`);
  }

  /** Topics are part of the syllabus; editors add them when they start a chapter. */
  @Put('chapters/:id/topics')
  async topics(@Param('id') id: string, @Body(new Zod(Chapter.shape.topics)) topics: z.infer<typeof Chapter.shape.topics>) {
    for (const t of topics) if (!t.id.startsWith(`${id}.`)) throw new BadRequestException({ code: 'topic_id_prefix', topic: t.id });
    await this.db.q('UPDATE chapter SET topics = $2 WHERE id = $1', [id, JSON.stringify(topics)]);
    return { saved: topics.length };
  }

  // ---------------------------------------------------------------- question bank

  @Get('questions')
  questions(@Query('chapterId') chapterId?: string, @Query('exam') exam?: string, @Query('difficulty') difficulty?: string, @Query('pyqYear') pyqYear?: string, @Query('q') q?: string) {
    if (exam && !Exam.safeParse(exam).success) throw new BadRequestException({ code: 'bad_exam' });
    return this.db.q(
      `SELECT data, pyq_verified AS "pyqVerified", updated_at AS "updatedAt" FROM question
       WHERE ($1::text IS NULL OR chapter_id = $1) AND ($2::text IS NULL OR $2 = ANY(exams)) AND ($3::text IS NULL OR difficulty = $3)
         AND ($4::int IS NULL OR pyq_year = $4) AND ($5::text IS NULL OR data->'stem'->>'en' ILIKE '%' || $5 || '%')
       ORDER BY id LIMIT 500`,
      [chapterId ?? null, exam ?? null, difficulty ?? null, pyqYear ? Number(pyqYear) : null, q ?? null],
    ).then((rows) => rows.map((r) => ({ ...r.data, pyqVerified: r.pyqVerified, updatedAt: r.updatedAt })));
  }

  @Put('questions/:id')
  async putQuestion(@Param('id') id: string, @Body(new Zod(Question)) b: z.infer<typeof Question>) {
    if (b.id !== id) throw new BadRequestException({ code: 'id_mismatch' });
    if (!(await this.db.one('SELECT 1 FROM chapter WHERE id = $1', [b.chapterId]))) throw new NotFoundException({ code: 'no_such_chapter' });
    await this.db.q(
      `INSERT INTO question(id, chapter_id, topic_id, data, exams, difficulty, pyq_exam, pyq_year, pyq_verified) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       ON CONFLICT (id) DO UPDATE SET chapter_id = $2, topic_id = $3, data = $4, exams = $5, difficulty = $6, pyq_exam = $7, pyq_year = $8, pyq_verified = $9, updated_at = now()`,
      [b.id, b.chapterId, b.topicId ?? null, JSON.stringify(b), b.exams, b.difficulty, b.pyq?.exam ?? null, b.pyq?.year ?? null, b.pyq?.verified ?? false],
    );
    return b;
  }

  @Delete('questions/:id')
  async deleteQuestion(@Param('id') id: string) {
    const used = await this.db.one("SELECT pack_id, topic_id FROM lesson_draft WHERE data::text LIKE '%\"' || $1 || '\"%'", [id]);
    if (used) throw new ConflictException({ code: 'question_in_use', lesson: `${used.pack_id}/${used.topic_id}` });
    await this.db.q('DELETE FROM question WHERE id = $1', [id]);
    return { ok: true };
  }

  // ---------------------------------------------------------------- packs, lessons, media

  @Get('packs')
  packs() {
    return this.db.q(`SELECT p.id, p.chapter_id AS "chapterId", c.title, c.subject, c.year,
      (SELECT count(*)::int FROM lesson_draft d WHERE d.pack_id = p.id) AS lessons,
      (SELECT max(updated_at) FROM lesson_draft d WHERE d.pack_id = p.id) AS "draftUpdatedAt",
      coalesce((SELECT json_agg(json_build_object('version', v.version, 'bytes', v.bytes, 'notes', v.notes, 'publishedAt', v.published_at, 'publishedBy', v.published_by)
        ORDER BY v.published_at DESC) FROM pack_version v WHERE v.pack_id = p.id), '[]') AS versions
      FROM pack p JOIN chapter c ON c.id = p.chapter_id ORDER BY c.subject, c.year, c.number`);
  }

  @Post('packs')
  async newPack(@Body(new Zod(NewPack)) b: z.infer<typeof NewPack>) {
    await this.db.q('INSERT INTO pack(id, chapter_id) VALUES ($1, $2)', [b.id, b.chapterId]);
    return b;
  }

  @Get('packs/:id/lessons')
  async lessons(@Param('id') id: string) {
    return (await this.db.q('SELECT data FROM lesson_draft WHERE pack_id = $1 ORDER BY topic_id', [id])).map((r) => r.data);
  }

  /** Saves one topic's lesson from the block editor. Validated against the schema and the question bank. */
  @Put('packs/:id/lessons/:topicId')
  async putLesson(@Param('id') id: string, @Param('topicId') topicId: string, @Body(new Zod(Lesson)) l: z.infer<typeof Lesson>, @CurrentStaff() s: Staff) {
    if (l.topicId !== topicId) throw new BadRequestException({ code: 'topic_mismatch' });
    const pack = await this.db.one('SELECT chapter_id FROM pack WHERE id = $1', [id]);
    if (!pack || pack.chapter_id !== l.chapterId) throw new BadRequestException({ code: 'chapter_mismatch' });
    const refs = l.blocks.flatMap((b) => (b.type === 'class_quiz' || b.type === 'pyq' ? b.questionIds : b.type === 'recap' ? b.homeworkQuestionIds : []));
    const found = new Set((await this.db.q('SELECT id FROM question WHERE id = ANY($1)', [refs])).map((r) => r.id));
    const missing = refs.filter((r) => !found.has(r));
    if (missing.length) throw new BadRequestException({ code: 'missing_questions', missing });
    await this.db.q(`INSERT INTO lesson_draft(pack_id, topic_id, data, updated_by) VALUES ($1,$2,$3,$4)
      ON CONFLICT (pack_id, topic_id) DO UPDATE SET data = $3, updated_at = now(), updated_by = $4`, [id, topicId, JSON.stringify(l), s.email]);
    return l;
  }

  @Post('packs/:id/media')
  async media(@Param('id') id: string, @Body(new Zod(Media)) b: z.infer<typeof Media>) {
    const key = `media/${id}/${b.path.slice('media/'.length)}`;
    await this.storage.put(key, Buffer.from(b.base64, 'base64'));
    await this.db.q('INSERT INTO pack_media(pack_id, path, storage_key) VALUES ($1,$2,$3) ON CONFLICT (pack_id, path) DO UPDATE SET storage_key = $3', [id, b.path, key]);
    return { path: b.path };
  }

  /** Freezes the drafts into a new signed version. Boards pick it up on their next sync. */
  @Post('packs/:id/versions')
  async publish(@Param('id') id: string, @Body(new Zod(Publish)) b: z.infer<typeof Publish>, @CurrentStaff() s: Staff) {
    const pack = await this.db.one('SELECT c.id, c.subject, c.year, c.number, c.title, c.topics, c.exams FROM pack p JOIN chapter c ON c.id = p.chapter_id WHERE p.id = $1', [id]);
    if (!pack) throw new NotFoundException();
    const versions = (await this.db.q('SELECT version FROM pack_version WHERE pack_id = $1', [id])).map((r) => r.version).sort(cmpVersion);
    const [maj, min, pat] = (versions.at(-1) ?? '0.0.0').split('.').map(Number);
    const version = b.bump === 'major' ? `${maj + 1}.0.0` : b.bump === 'minor' ? `${maj}.${min + 1}.0` : `${maj}.${min}.${pat + 1}`;
    const lessons = (await this.db.q('SELECT data FROM lesson_draft WHERE pack_id = $1', [id])).map((r) => Lesson.parse(r.data));
    if (!lessons.length) throw new BadRequestException({ code: 'no_lessons' });
    const questions = (await this.db.q('SELECT data FROM question WHERE chapter_id = $1', [pack.id])).map((r) => Question.parse(r.data));
    const media: Record<string, Uint8Array> = {};
    for (const m of await this.db.q('SELECT path, storage_key FROM pack_media WHERE pack_id = $1', [id])) media[m.path] = await this.storage.get(m.storage_key);
    const chapter = Chapter.parse(pack);
    let built;
    try {
      built = buildPack({ id, version, chapter, lessons, questions, media }, this.keys.pack);
    } catch (e) {
      throw new BadRequestException({ code: 'pack_invalid', message: (e as Error).message });
    }
    const key = `packs/${id}-${version}.zpack`;
    await this.storage.put(key, built.bytes, 'application/zip');
    await this.db.q('INSERT INTO pack_version(pack_id, version, storage_key, sha256, bytes, notes, published_by) VALUES ($1,$2,$3,$4,$5,$6,$7)', [
      id, version, key, sha256(built.bytes), built.bytes.length, b.notes ?? null, s.email,
    ]);
    return { id, version, bytes: built.bytes.length, lessons: lessons.length, questions: questions.length };
  }
}
