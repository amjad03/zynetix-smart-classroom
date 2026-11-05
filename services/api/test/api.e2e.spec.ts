import { createPublicKey, generateKeyPairSync, verify } from 'node:crypto';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { unzipSync } from 'fflate';
import { AppModule } from '../src/app.module';
import { DB, Db } from '../src/db/db';
import { seed } from '../src/db/seed';
import { KEYS, LocalStorage, STORAGE, sha256 } from '../src/infra';
import { buildAudioPack } from '@zynetix/pack-builder';

const DB_URL = process.env.TEST_DATABASE_URL ?? 'postgres://zynetix:zynetix@localhost:5432/zynetix_test';
const packKey = { keyId: 'test', privateKey: generateKeyPairSync('ed25519').privateKey };
const licenceKey = generateKeyPairSync('ed25519').privateKey;

describe('Zynetix API', () => {
  let app: INestApplication, db: Db, http: ReturnType<typeof request>;
  let admin: string, editor: string, device: string;

  const log = (over: Record<string, unknown> = {}) => ({
    id: crypto.randomUUID(), sectionId: 'whatever', mode: 'self_learning', chapterId: 'puc1-physics-02-motion-in-a-straight-line',
    topicId: 'puc1-physics-02-motion-in-a-straight-line.t1', lessonId: 'puc1-physics-02-motion-in-a-straight-line.t1.lesson', packVersion: '1.0.0',
    startedAt: new Date(Date.now() - 40 * 60e3).toISOString(), endedAt: new Date().toISOString(), blocksShown: ['intro', 'quiz'], completed: true,
    answers: [{ questionId: 'mot-q01', mode: 'roll_call', roll: 17, chosen: 0, correct: true, at: new Date().toISOString() }], ...over,
  });

  beforeAll(async () => {
    db = new Db(new (require('pg').Pool)({ connectionString: DB_URL }));
    await db.q('DROP SCHEMA public CASCADE; CREATE SCHEMA public');
    const storage = new LocalStorage(mkdtempSync(join(tmpdir(), 'zs-')));
    await seed(db, storage, packKey);
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(DB).useValue(db)
      .overrideProvider(STORAGE).useValue(storage)
      .overrideProvider(KEYS).useValue({ pack: packKey, licence: licenceKey })
      .compile();
    app = mod.createNestApplication();
    await app.init();
    http = request(app.getHttpServer());
    admin = (await http.post('/v1/auth/login').send({ email: 'admin@demo-pu.in', password: 'zynetix123' })).body.token;
    editor = (await http.post('/v1/auth/login').send({ email: 'editor@zynetix.in', password: 'zynetix123' })).body.token;
  }, 180_000); // seeds all 270 packs
  afterAll(async () => {
    await app.close();
    await db.pool.end();
  });

  it('rejects a wrong password', async () => {
    await http.post('/v1/auth/login').send({ email: 'admin@demo-pu.in', password: 'nope' }).expect(401);
  });

  it('activates a board with a one-time code and a PIN chosen on the board', async () => {
    const code = (await http.post('/v1/admin/sections/demo-1puc-a/activation-code').auth(admin, { type: 'bearer' }).expect(201)).body.code;
    const r = await http.post('/v1/devices/activate').send({ code, name: 'Room 12 board', pin: '4321' }).expect(201);
    device = r.body.deviceToken;
    expect(r.body.config).toMatchObject({ sectionId: 'demo-1puc-a', rollCount: 62, year: 'puc1' });
    // The board checks the licence offline with the public key.
    const [body, sig] = r.body.config.licenceToken.split('.');
    expect(verify(null, Buffer.from(body, 'base64url'), createPublicKey(licenceKey), Buffer.from(sig, 'base64url'))).toBe(true);
    await http.post('/v1/devices/activate').send({ code, name: 'again', pin: '1111' }).expect(404); // one-time
  });

  it('sync: accepts logs once, rejects logs with extra (personal) fields, offers signed packs', async () => {
    const good = log();
    const named = { ...log(), studentName: 'Asha' };
    const r = await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({ installed: {}, outbox: [good, named] }).expect(201);
    expect(r.body.accepted).toEqual([good.id]);
    expect(r.body.rejected).toHaveLength(1);
    const again = await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({ installed: {}, outbox: [good] }).expect(201);
    expect(again.body.accepted).toEqual([good.id]);
    expect((await db.q('SELECT section_id FROM session_log'))).toEqual([{ section_id: 'demo-1puc-a' }]);

    const ids: string[] = r.body.packs.map((p: any) => p.id);
    expect(ids).toEqual(expect.arrayContaining(['puc1-physics-motion-in-a-straight-line', 'puc2-chemistry-solutions']));
    // Only the section's subjects and board: no commerce or Karnataka-only Statistics packs for a PCMB section.
    expect(ids.some((i) => /^puc[12]-(accountancy|statistics|english|electronics|economics|business-studies|computer-science)-/.test(i))).toBe(false);
    const p = r.body.packs.find((x: any) => x.id === 'puc2-chemistry-solutions');
    const file = await http.get(new URL(p.url).pathname).buffer(true).parse((res, cb) => {
      const chunks: Buffer[] = [];
      res.on('data', (c: Buffer) => chunks.push(c));
      res.on('end', () => cb(null, Buffer.concat(chunks)));
    }).expect(200);
    const files = unzipSync(new Uint8Array(file.body));
    expect(verify(null, files['manifest.json'], createPublicKey(packKey.privateKey), Buffer.from(files['manifest.sig']))).toBe(true);

    const none = await http.post('/v1/board/sync').auth(device, { type: 'bearer' })
      .send({ installed: Object.fromEntries(r.body.packs.map((x: any) => [x.id, x.version])) }).expect(201);
    expect(none.body.packs).toEqual([]);
  });

  it('an unknown device token is refused', async () => {
    await http.post('/v1/board/sync').auth('nope', { type: 'bearer' }).send({}).expect(401);
  });

  it('admin books a Self-Learning period and the board receives it; PIN changes reach the board', async () => {
    const today = new Date().toISOString().slice(0, 10);
    await http.post('/v1/admin/self-learning').auth(admin, { type: 'bearer' })
      .send({ sectionId: 'demo-1puc-a', date: today, start: '23:00', end: '23:40', topicId: 'puc1-physics-02-motion-in-a-straight-line.t3', reason: 'Physics lecturer on leave' }).expect(201);
    await http.post('/v1/admin/self-learning').auth(admin, { type: 'bearer' })
      .send({ sectionId: 'demo-1puc-a', date: today, start: '10:00', end: '10:40', topicId: 'no-such-topic' }).expect(404);
    const boards = (await http.get('/v1/admin/boards').auth(admin, { type: 'bearer' }).expect(200)).body;
    await http.put(`/v1/admin/boards/${boards[0].id}/pin`).auth(admin, { type: 'bearer' }).send({ pin: '2468' }).expect(200);
    const r = await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({}).expect(201);
    expect(r.body.schedule).toEqual([{ date: today, start: '23:00', end: '23:40', topicId: 'puc1-physics-02-motion-in-a-straight-line.t3' }]);
    const { createHash } = require('node:crypto');
    expect(r.body.config.pinHash).toBe(createHash('sha256').update(`${r.body.config.pinSalt}:2468`).digest('hex'));
    expect(r.body.timetable).toHaveLength(24);
  });

  it('timetable: replace and read back; bad times rejected', async () => {
    const slots = [{ day: 1, period: 1, start: '09:00', end: '09:40', subject: 'physics', teacher: 'R. Kulkarni' }];
    await http.put('/v1/admin/sections/demo-2puc-a/timetable').auth(admin, { type: 'bearer' }).send(slots).expect(200);
    expect((await http.get('/v1/admin/sections/demo-2puc-a/timetable').auth(admin, { type: 'bearer' })).body).toEqual(slots);
    await http.put('/v1/admin/sections/demo-2puc-a/timetable').auth(admin, { type: 'bearer' }).send([{ ...slots[0], start: '9am' }]).expect(400);
  });

  it('reports: syllabus heatmap and usage reflect the synced session', async () => {
    const h = (await http.get('/v1/admin/reports/syllabus').auth(admin, { type: 'bearer' }).expect(200)).body;
    const cell = h.cells.find((c: any) => c.sectionId === 'demo-1puc-a' && c.chapterId === 'puc1-physics-02-motion-in-a-straight-line');
    expect(cell).toMatchObject({ taught: 1, topics: 5, share: 0.2 });
    const u = (await http.get('/v1/admin/reports/usage').auth(admin, { type: 'bearer' }).expect(200)).body;
    expect(u.bySection).toEqual([{ section: '1st PUC · A · PCMB', sessions: 1, selfLearning: 1, answers: 1, correct: 1 }]);
    expect(u.daily[0]).toMatchObject({ mode: 'self_learning', sessions: 1, minutes: 40 });
  });

  it('a CBSE section gets only CBSE-syllabus packs for its subjects, and its board in the config', async () => {
    const code = (await http.post('/v1/admin/sections/demo-12-cbse-sci/activation-code').auth(admin, { type: 'bearer' }).expect(201)).body.code;
    const a = await http.post('/v1/devices/activate').send({ code, name: 'CBSE lab', pin: '5555' }).expect(201);
    expect(a.body.config).toMatchObject({ board: 'cbse', subjects: ['physics', 'chemistry', 'maths', 'computer_science', 'english'] });
    const r = await http.post('/v1/board/sync').auth(a.body.deviceToken, { type: 'bearer' }).send({}).expect(201);
    const ids: string[] = r.body.packs.map((p: any) => p.id);
    expect(ids.some((i) => /^puc[12]-(biology|statistics|electronics|accountancy)-/.test(i))).toBe(false);
    expect(ids).toContain("puc2-physics-wave-optics");
  });

  it('an ISC section can be added (Science or Commerce, Class XI/XII) and activates with its board', async () => {
    const sec = { id: 'test-isc-12-com', label: 'Class XII · ISC · Commerce', year: 'puc2', rollCount: 35, board: 'isc', subjects: ['accountancy', 'commerce', 'economics', 'english'] };
    await http.post('/v1/admin/sections').auth(admin, { type: 'bearer' }).send({ ...sec, board: 'icse' }).expect(400);
    await http.post('/v1/admin/sections').auth(admin, { type: 'bearer' }).send(sec).expect(201);
    try {
      const code = (await http.post(`/v1/admin/sections/${sec.id}/activation-code`).auth(admin, { type: 'bearer' }).expect(201)).body.code;
      const a = await http.post('/v1/devices/activate').send({ code, name: 'ISC room', pin: '6666' }).expect(201);
      expect(a.body.config).toMatchObject({ board: 'isc', year: 'puc2', subjects: sec.subjects });
      const r = await http.post('/v1/board/sync').auth(a.body.deviceToken, { type: 'bearer' }).send({}).expect(201);
      const isc = new Set((await db.q<{ id: string }>("SELECT p.id FROM pack p JOIN chapter c ON c.id = p.chapter_id WHERE 'isc' = ANY(c.boards) AND c.subject = ANY($1)", [sec.subjects])).map((c) => c.id));
      expect(r.body.packs.every((p: any) => isc.has(p.id))).toBe(true); // nothing outside the ISC syllabus or its subjects
      await db.q("INSERT INTO section(id, college_id, label, year, roll_count, board) VALUES ('test-bad', 'demo-pu', 'x', 'puc1', 1, 'icse')").then(() => { throw new Error('board check missing'); }, (e) => expect(String(e)).toMatch(/check/i));
    } finally {
      for (const t of ['activation_code', 'device']) await db.q(`DELETE FROM ${t} WHERE section_id = $1`, [sec.id]).catch(() => undefined);
      await db.q('DELETE FROM section WHERE id = $1', [sec.id]);
    }
  });

  it('roles: admins cannot use the CMS; editors cannot use Admin without naming a college', async () => {
    await http.get('/v1/cms/packs').auth(admin, { type: 'bearer' }).expect(403);
    await http.get('/v1/admin/sections').auth(editor, { type: 'bearer' }).expect(403);
    await http.get('/v1/cms/packs').expect(401);
  });

  it('CMS: question bank filters, lesson validation, and publishing a new version boards then receive', async () => {
    const jeeHard = (await http.get('/v1/cms/questions?exam=JEE&difficulty=hard&chapterId=puc2-chemistry-01-solutions').auth(editor, { type: 'bearer' }).expect(200)).body;
    expect(jeeHard.map((q: any) => q.id)).toEqual(expect.arrayContaining(['sol-q18', 'sol-q20']));
    expect(jeeHard.every((q: any) => q.exams.includes('JEE') && q.difficulty === 'hard' && q.chapterId === 'puc2-chemistry-01-solutions')).toBe(true);
    const cbseCases = (await http.get('/v1/cms/questions?exam=CBSE').auth(editor, { type: 'bearer' })).body.filter((q: any) => q.format === 'case_based');
    expect(cbseCases.length).toBeGreaterThan(0);
    expect(cbseCases.every((q: any) => q.passage?.en)).toBe(true);

    const q = jeeHard[0];
    const { pyqVerified, updatedAt, ...clean } = q;
    await http.put(`/v1/cms/questions/${q.id}`).auth(editor, { type: 'bearer' }).send({ ...clean, pyq: { exam: 'JEE', year: 2019, verified: true } }).expect(200);
    expect((await http.get('/v1/cms/questions?pyqYear=2019').auth(editor, { type: 'bearer' })).body).toHaveLength(1);
    await http.put('/v1/cms/questions/x1').auth(editor, { type: 'bearer' }).send({ ...clean, id: 'x1', options: clean.options.slice(0, 3) }).expect(400);

    const pack = 'puc1-physics-motion-in-a-straight-line';
    const lessons = (await http.get(`/v1/cms/packs/${pack}/lessons`).auth(editor, { type: 'bearer' }).expect(200)).body;
    const l = lessons[0];
    l.blocks.find((b: any) => b.type === 'class_quiz').questionIds.push('not-a-question');
    expect((await http.put(`/v1/cms/packs/${pack}/lessons/${l.topicId}`).auth(editor, { type: 'bearer' }).send(l).expect(400)).body.missing).toEqual(['not-a-question']);
    l.blocks.find((b: any) => b.type === 'class_quiz').questionIds.pop();
    l.title.en = 'Position, displacement and average velocity (revised)';
    await http.put(`/v1/cms/packs/${pack}/lessons/${l.topicId}`).auth(editor, { type: 'bearer' }).send(l).expect(200);

    const v = (await http.post(`/v1/cms/packs/${pack}/versions`).auth(editor, { type: 'bearer' }).send({ notes: 'Revised topic 1' }).expect(201)).body;
    // Publishing bumps the minor version of whatever the seed pack was.
    const seed = JSON.parse(require('fs').readFileSync(require('path').join(__dirname, '../../../content/packs', pack, 'pack.json'), 'utf8')).version as string;
    const [maj, min] = seed.split('.').map(Number);
    const next = `${maj}.${min + 1}.0`;
    expect(v).toMatchObject({ version: next, lessons: 5 });
    expect(v.questions).toBeGreaterThanOrEqual(19);
    const r = await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({ installed: { [pack]: '1.0.0' } }).expect(201);
    expect(r.body.packs.find((x: any) => x.id === pack)).toMatchObject({ version: next });
  });
  // ---- Outcomes: answers stored per roll number, dashboards, readiness, league ----
  const motion = 'puc1-physics-02-motion-in-a-straight-line';
  const ans = (q: string, roll: number | undefined, correct: boolean, extra: Record<string, unknown> = {}) =>
    ({ questionId: q, mode: roll ? 'roll_call' : 'monitor', ...(roll ? { roll } : {}), chosen: correct ? 0 : 1, correct, at: new Date().toISOString(), ...extra });

  it('chapter voice: an editor publishes a signed audio pack; the board downloads it once and sync offers newer ones', async () => {
    const packId = 'puc1-physics-units-and-measurement';
    const audio = (version: string, key = packKey) => buildAudioPack({
      packId, chapterId: 'puc1-physics-01-units-and-measurement', lang: 'en', version,
      voice: { model: 'hexgrad/Kokoro-82M', voice: 'am_michael', licence: 'Apache-2.0' },
      clips: [{ clip: { lessonId: 'puc1-physics-01-units-and-measurement.t1.lesson', blockId: 'hook', step: 1, clip: 'hook.1', file: 'audio/t1/hook.1.opus', ms: 4200, sha: '0123456789abcdef' }, bytes: new TextEncoder().encode('OggS…') }],
    }, key).bytes;
    // The seed publishes any voice rendered in content/audio: start from none.
    await db.q('DELETE FROM audio_pack_version');
    // Before any voice is published the board gets a 404 and lessons stay silent.
    await http.get(`/v1/board/audio/${packId}/en`).auth(device, { type: 'bearer' }).expect(404);
    await http.get(`/v1/board/audio/${packId}/en`).expect(401);
    // A pack signed with another key, or for another chapter, is refused.
    const stranger = { keyId: 'x', privateKey: generateKeyPairSync('ed25519').privateKey };
    await http.post(`/v1/cms/packs/${packId}/audio`).auth(editor, { type: 'bearer' }).send({ base64: Buffer.from(audio('1.0.0', stranger)).toString('base64') }).expect(400);
    await http.post('/v1/cms/packs/puc2-chemistry-solutions/audio').auth(editor, { type: 'bearer' }).send({ base64: Buffer.from(audio('1.0.0')).toString('base64') }).expect(400);
    const up = await http.post(`/v1/cms/packs/${packId}/audio`).auth(editor, { type: 'bearer' }).send({ base64: Buffer.from(audio('1.0.0')).toString('base64') }).expect(201);
    expect(up.body).toMatchObject({ id: `${packId}-audio-en`, version: '1.0.0', clips: 1, seconds: 4 });
    const r = await http.get(`/v1/board/audio/${packId}/en`).auth(device, { type: 'bearer' }).expect(200);
    expect(r.body).toMatchObject({ id: `${packId}-audio-en`, lang: 'en', version: '1.0.0', voice: { licence: 'Apache-2.0' } });
    await http.get(`/v1/board/audio/${packId}/kn`).auth(device, { type: 'bearer' }).expect(404);
    const file = await http.get(new URL(r.body.url).pathname).buffer(true).parse((res, cb) => { const b: Buffer[] = []; res.on('data', (c: Buffer) => b.push(c)); res.on('end', () => cb(null, Buffer.concat(b))); }).expect(200);
    const files = unzipSync(new Uint8Array(file.body));
    expect(verify(null, files['manifest.json'], createPublicKey(packKey.privateKey), Buffer.from(files['manifest.sig']))).toBe(true);
    expect(sha256(new Uint8Array(file.body))).toBe(r.body.sha256);
    // Sync offers a newer version only of voices the board has.
    await http.post(`/v1/cms/packs/${packId}/audio`).auth(editor, { type: 'bearer' }).send({ base64: Buffer.from(audio('1.0.1')).toString('base64') }).expect(201);
    const none = await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({}).expect(201);
    expect(none.body.audio).toEqual([]);
    const s = await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({ installedAudio: { [`${packId}-audio-en`]: '1.0.0' } }).expect(201);
    expect(s.body.audio.map((a: { version: string }) => a.version)).toEqual(['1.0.1']);
  });

  it('sync stores each answer once, with its topic; old logs without topic/source get them from the question bank', async () => {
    const old = log({ answers: [ans('mot-q04', 3, true)] }); // an older board: no topicId/chapterId/source
    const fresh = log({ mode: 'teacher', answers: [ans('mot-q11', undefined, true, { topicId: `${motion}.t5`, chapterId: motion, source: 'challenge' })] });
    const named = log({ answers: [ans('mot-q11', 4, true, { source: 'Asha Rao' })] }); // free text is refused
    const r = await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({ outbox: [old, fresh, named] }).expect(201);
    expect(r.body.accepted).toEqual([old.id, fresh.id]);
    expect(r.body.rejected).toHaveLength(1);
    await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({ outbox: [old, fresh] }).expect(201);
    const rows = await db.q('SELECT log_id, topic_id, chapter_id, subject, roll, source, correct, section_id FROM answer WHERE log_id = ANY($1) ORDER BY roll NULLS LAST', [[old.id, fresh.id]]);
    expect(rows).toEqual([
      { log_id: old.id, topic_id: `${motion}.t2`, chapter_id: motion, subject: 'physics', roll: 3, source: 'roll_call', correct: true, section_id: 'demo-1puc-a' },
      { log_id: fresh.id, topic_id: `${motion}.t5`, chapter_id: motion, subject: 'physics', roll: null, source: 'challenge', correct: true, section_id: 'demo-1puc-a' },
    ]);
  });

  it('outcomes: dashboard, section heatmap and a roll number report (roll numbers only)', async () => {
    // Rolls 1-5 get t1 and t2 right three times, rolls 6-10 wrong three times.
    const answers = [];
    for (let roll = 1; roll <= 10; roll++)
      for (const q of ['mot-q01', 'mot-q02', 'mot-q03', 'mot-q04', 'mot-q05', 'mot-q06']) answers.push(ans(q, roll, roll <= 5, { topicId: `${motion}.${['mot-q01', 'mot-q02', 'mot-q03'].includes(q) ? 't1' : 't2'}`, chapterId: motion, source: 'roll_call' }));
    await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({ outbox: [log({ mode: 'teacher', answers })] }).expect(201);

    const o = (await http.get('/v1/admin/outcomes?weeks=4').auth(admin, { type: 'bearer' }).expect(200)).body;
    expect(o.weeks).toHaveLength(4);
    const row = o.rows.find((r: any) => r.sectionId === 'demo-1puc-a' && r.subject === 'physics');
    expect(row).toMatchObject({ topicsTaught: 1, topicsAssessed: 2, topicsMastered: 0, stuckShare: 0.5, rollsAssessed: 11 }); // rolls 1-10 and 17
    expect(row.trend[3]).toBeCloseTo(0.5, 1); // half the class mastered, half stuck
    expect(o.stuckTopics.find((t: any) => t.topicId === `${motion}.t1`)).toMatchObject({ stuck: 5, assessed: 10, share: 0.5, section: '1st PUC · A · PCMB' });
    expect(JSON.stringify({ ...o, college: null })).not.toMatch(/name"/i); // nothing per student but roll numbers

    const d = (await http.get('/v1/admin/outcomes/sections/demo-1puc-a?subject=physics').auth(admin, { type: 'bearer' }).expect(200)).body;
    expect(d.rolls).toHaveLength(62);
    const t1 = d.topics.find((t: any) => t.id === `${motion}.t1`);
    expect(t1).toMatchObject({ taught: true, stuck: [6, 7, 8, 9, 10], mastered: 5, assessed: 10 });
    expect(d.rolls[0].cells[`${motion}.t1`]).toEqual([0.86, 3]);
    expect(d.rolls[6].cells[`${motion}.t1`]).toEqual([0.14, 3]);

    const r7 = (await http.get('/v1/admin/outcomes/sections/demo-1puc-a/rolls/7').auth(admin, { type: 'bearer' }).expect(200)).body;
    expect(r7).toMatchObject({ roll: 7, answers: 6, correct: 0, overall: 0.14 });
    expect(r7.stuck.map((t: any) => t.id).sort()).toEqual([`${motion}.t1`, `${motion}.t2`]);
    expect(r7.readiness.every((x: any) => x.band === 'not_enough_data')).toBe(true);
    await http.get('/v1/admin/outcomes/sections/demo-1puc-a/rolls/63').auth(admin, { type: 'bearer' }).expect(400);
    await http.get('/v1/admin/outcomes/sections/elsewhere/rolls/1').auth(admin, { type: 'bearer' }).expect(404);
  });

  it('exam readiness per section: honest bands (a few topics answered is not enough data)', async () => {
    const r = (await http.get('/v1/admin/outcomes/readiness').auth(admin, { type: 'bearer' }).expect(200)).body;
    const sec = r.sections.find((s: any) => s.sectionId === 'demo-1puc-a');
    expect(sec.exams.map((e: any) => e.exam)).toEqual(expect.arrayContaining(['PUC', 'KCET', 'NEET', 'JEE']));
    expect(sec.exams.map((e: any) => e.exam)).not.toContain('CBSE'); // a Karnataka PU section does not sit the CBSE board exam
    const jee = sec.exams.find((e: any) => e.exam === 'JEE');
    expect(jee).toMatchObject({ band: 'not_enough_data', label: 'Not enough data', topicsSeen: 2 });
    expect(jee.answered).toBeGreaterThanOrEqual(60);
    expect(r.sections.find((s: any) => s.sectionId === 'demo-12-cbse-sci').exams.every((e: any) => e.band === 'not_enough_data' && e.exam !== 'PUC')).toBe(true);
  });

  it('league: section points per week, and this week in the board sync config as a JSON string', async () => {
    const l = (await http.get('/v1/admin/outcomes/league?weeks=2').auth(admin, { type: 'bearer' }).expect(200)).body;
    const w = l.sections.find((s: any) => s.sectionId === 'demo-1puc-a').weeks[1];
    expect(w.stars).toBe(1); // the one correct challenge answer
    expect(w.correct).toBeGreaterThanOrEqual(33);
    expect(w.points).toBe(Math.round(((w.correct + 2 * w.stars) * 40) / 62) + 10 * w.streakDays);
    const cfg = (await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({}).expect(201)).body.config;
    expect(typeof cfg.league).toBe('string');
    const league = JSON.parse(cfg.league);
    expect(league).toHaveLength(4);
    expect(Object.keys(league[0]).sort()).toEqual(['label', 'points', 'sectionId']);
    expect(league[0]).toEqual({ sectionId: 'demo-1puc-a', label: '1st PUC · A · PCMB', points: w.points });
  });

  it('monthly college report, and Outcomes are admin-only and college-scoped', async () => {
    const month = new Date(Date.now() + 5.5 * 3600e3).toISOString().slice(0, 7);
    const r = (await http.get(`/v1/admin/outcomes/report?month=${month}`).auth(admin, { type: 'bearer' }).expect(200)).body;
    expect(r).toMatchObject({ month, college: { id: 'demo-pu', demo: false } });
    expect(r.totals.answers).toBeGreaterThanOrEqual(63);
    expect(r.sections).toHaveLength(4);
    const physics = r.sections.find((s: any) => s.id === 'demo-1puc-a').subjects.find((x: any) => x.subject === 'physics');
    expect(physics).toMatchObject({ taught: 1, assessed: 2 });
    expect(r.league[0].sectionId).toBe('demo-1puc-a');
    await http.get('/v1/admin/outcomes').auth(editor, { type: 'bearer' }).expect(403);
    await http.get('/v1/admin/outcomes?college=demo-pu').auth(editor, { type: 'bearer' }).expect(403); // editors are content staff, not admins
    await http.get('/v1/admin/outcomes/readiness').expect(401);
  });
});
