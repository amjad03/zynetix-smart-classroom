/**
 * Demo data: one college, two sections, an admin and an editor, the NCERT syllabus, the two seed
 * chapters (as CMS drafts + a published v1.0.0 pack), a timetable and a board activation code.
 * Uses the same pack key as the pack builder (dev key in tools/pack-builder/keys) when present,
 * so the APK's seed packs and the API's packs verify with one trusted key.
 */
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import * as bcrypt from 'bcryptjs';
import { buildPack, readSource, validate } from '@zynetix/pack-builder';
import { Chapter } from '@zynetix/lesson-schema';
import { Db } from './db';
import { migrate } from './migrate';
import { LocalStorage, S3Storage, Storage, loadKey, sha256 } from '../infra';

const content = join(__dirname, '../../../../content');

export async function seed(db: Db, storage: Storage, packKey: Parameters<typeof buildPack>[1]) {
  await migrate(db);
  await db.q("INSERT INTO college(id, name, district) VALUES ('demo-pu', 'Demo PU College', 'Bengaluru Urban') ON CONFLICT DO NOTHING");
  await db.q("INSERT INTO licence(college_id, valid_until, max_devices) VALUES ('demo-pu', current_date + 365, 50) ON CONFLICT DO NOTHING");
  await db.q(`INSERT INTO section(id, college_id, label, year, roll_count) VALUES
    ('demo-1puc-a', 'demo-pu', '1st PUC · A · PCMB', 'puc1', 62), ('demo-2puc-a', 'demo-pu', '2nd PUC · A · PCMB', 'puc2', 58) ON CONFLICT DO NOTHING`);
  await db.q(`INSERT INTO section(id, college_id, label, year, roll_count, board, subjects) VALUES
    ('demo-1puc-c', 'demo-pu', '1st PUC · C · Commerce (EBAS)', 'puc1', 70, 'kar_pu', '{economics,business_studies,accountancy,statistics}'),
    ('demo-12-cbse-sci', 'demo-pu', 'Class 12 · CBSE · Science (PCM-CS)', 'puc2', 40, 'cbse', '{physics,chemistry,maths,computer_science,english}')
    ON CONFLICT DO NOTHING`);
  const hash = await bcrypt.hash('zynetix123', 10);
  await db.q(`INSERT INTO staff(email, password_hash, role, college_id) VALUES
    ('admin@demo-pu.in', $1, 'admin', 'demo-pu'), ('editor@zynetix.in', $1, 'editor', NULL) ON CONFLICT DO NOTHING`, [hash]);

  for (const f of readdirSync(join(content, 'syllabus')).filter((f) => f !== 'index.json')) {
    for (const raw of JSON.parse(readFileSync(join(content, 'syllabus', f), 'utf8'))) {
      const c = Chapter.parse(raw);
      await db.q(`INSERT INTO chapter(id, subject, year, number, title, topics, exams, boards, book) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
        ON CONFLICT (id) DO UPDATE SET topics = CASE WHEN jsonb_array_length(chapter.topics) = 0 THEN $6 ELSE chapter.topics END, boards = $8, book = $9`,
        [c.id, c.subject, c.year, c.number, JSON.stringify(c.title), JSON.stringify(c.topics), c.exams, c.boards, c.book ?? null]);
    }
  }

  for (const dir of readdirSync(join(content, 'packs'))) {
    let src;
    try {
      src = readSource(content, dir);
    } catch (e) {
      console.warn(`skipping pack ${dir}: ${(e as Error).message.split('\n')[0]}`);
      continue;
    }
    if (validate(src).length) {
      console.warn(`skipping pack ${dir}: not valid yet`);
      continue;
    }
    await db.q('INSERT INTO pack(id, chapter_id) VALUES ($1,$2) ON CONFLICT DO NOTHING', [src.id, src.chapter.id]);
    for (const q of src.questions)
      await db.q(`INSERT INTO question(id, chapter_id, topic_id, data, exams, difficulty) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING`,
        [q.id, q.chapterId, q.topicId ?? null, JSON.stringify(q), q.exams, q.difficulty]);
    for (const l of src.lessons)
      await db.q('INSERT INTO lesson_draft(pack_id, topic_id, data, updated_by) VALUES ($1,$2,$3,$4) ON CONFLICT DO NOTHING', [src.id, l.topicId, JSON.stringify(l), 'seed']);
    for (const [path, bytes] of Object.entries(src.media)) {
      const key = `media/${src.id}/${path.slice(6)}`;
      await storage.put(key, bytes);
      await db.q('INSERT INTO pack_media(pack_id, path, storage_key) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING', [src.id, path, key]);
    }
    if (!(await db.one('SELECT 1 FROM pack_version WHERE pack_id = $1', [src.id]))) {
      const { bytes } = buildPack(src, packKey);
      const key = `packs/${src.id}-${src.version}.zpack`;
      await storage.put(key, bytes);
      await db.q('INSERT INTO pack_version(pack_id, version, storage_key, sha256, bytes, notes, published_by) VALUES ($1,$2,$3,$4,$5,$6,$7)',
        [src.id, src.version, key, sha256(bytes), bytes.length, 'Seed', 'seed']);
    }
  }

  const slots: [number, number, string, string, string][] = [];
  for (let day = 1; day <= 6; day++)
    ['physics', 'chemistry', 'maths', 'biology'].forEach((sub, i) => slots.push([day, i + 1, `${String(9 + i).padStart(2, '0')}:00`, `${String(9 + i).padStart(2, '0')}:40`, sub]));
  for (const sec of ['demo-1puc-a', 'demo-2puc-a'])
    for (const [day, period, start, end, subject] of slots)
      await db.q('INSERT INTO timetable_slot(section_id, day, period, start_time, end_time, subject) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING', [sec, day, period, start, end, subject]);
  await db.q("INSERT INTO activation_code(code, college_id, section_id, expires_at) VALUES ('DEMO1PUC', 'demo-pu', 'demo-1puc-a', now() + interval '30 days') ON CONFLICT DO NOTHING");
}

if (require.main === module) {
  const db = Db.fromEnv();
  const storage = process.env.S3_BUCKET ? new S3Storage(process.env.S3_BUCKET) : new LocalStorage(join(process.cwd(), 'storage'));
  const devKey = join(__dirname, '../../../../tools/pack-builder/keys/dev-2026.private.pem');
  const key = { keyId: process.env.PACK_KEY_ID ?? 'dev-2026', privateKey: loadKey(process.env.PACK_SIGNING_KEY_FILE || devKey, 'pack') };
  seed(db, storage, key).then(() => db.pool.end()).then(() => console.log('seeded: admin@demo-pu.in / editor@zynetix.in, password zynetix123; board code DEMO1PUC'));
}
