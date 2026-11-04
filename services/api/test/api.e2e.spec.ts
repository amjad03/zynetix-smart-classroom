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
import { KEYS, LocalStorage, STORAGE } from '../src/infra';

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
  });
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
    expect(v).toMatchObject({ version: "1.2.0", lessons: 5 }); // seed packs are 1.1.0
    expect(v.questions).toBeGreaterThanOrEqual(19);
    const r = await http.post('/v1/board/sync').auth(device, { type: 'bearer' }).send({ installed: { [pack]: '1.0.0' } }).expect(201);
    expect(r.body.packs.find((x: any) => x.id === pack)).toMatchObject({ version: '1.2.0' });
  });
});
