/**
 * DEMO DATA for screenshots and sales demos: nine weeks of lessons and quiz answers for the four
 * Demo PU College sections, so the Outcomes pages have something real-looking to show.
 * - Roll numbers only (no names); lecturer names are made up and marked "(demo)".
 * - The college is flagged `demo`, and every Outcomes page shows a "Demo data" badge.
 * - Re-running replaces the previous demo logs (they all come from boards named "DEMO …").
 * Run after `pnpm db:seed`: `pnpm db:seed:demo`.
 */
import { Db } from './db';

/** A small seeded PRNG so every run makes the same demo college. */
function rng(seed: number) {
  return () => {
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const sigmoid = (x: number) => 1 / (1 + Math.exp(-x));
const uuid = (r: () => number) => {
  const h = Array.from({ length: 32 }, () => Math.floor(r() * 16).toString(16));
  h[12] = '4';
  h[16] = '89ab'[Math.floor(r() * 4)];
  const s = h.join('');
  return `${s.slice(0, 8)}-${s.slice(8, 12)}-${s.slice(12, 16)}-${s.slice(16, 20)}-${s.slice(20)}`;
};

/** How strong each section is, and how well each subject is going there (the story the screenshots tell). */
const PROFILE: Record<string, { level: number; subjects: Record<string, { boost: number; teacher: string }> }> = {
  'demo-1puc-a': { level: 0.25, subjects: { physics: { boost: 0.5, teacher: 'R. Kulkarni (demo)' }, chemistry: { boost: 0.1, teacher: 'S. Hegde (demo)' }, maths: { boost: -0.35, teacher: 'M. Rao (demo)' }, biology: { boost: 0.3, teacher: 'A. Shetty (demo)' } } },
  'demo-2puc-a': { level: -0.35, subjects: { physics: { boost: -0.2, teacher: 'R. Kulkarni (demo)' }, chemistry: { boost: 0.35, teacher: 'P. Nayak (demo)' }, maths: { boost: 0.2, teacher: 'M. Rao (demo)' }, biology: { boost: -0.4, teacher: 'V. Bhat (demo)' } } },
  'demo-1puc-c': { level: -0.05, subjects: { economics: { boost: 0.3, teacher: 'K. Murthy (demo)' }, business_studies: { boost: 0.15, teacher: 'L. Joshi (demo)' }, accountancy: { boost: -0.3, teacher: 'G. Pai (demo)' }, statistics: { boost: 0, teacher: 'N. Gowda (demo)' } } },
  'demo-12-cbse-sci': { level: 0.35, subjects: { physics: { boost: 0.2, teacher: 'D. Menon (demo)' }, chemistry: { boost: -0.1, teacher: 'S. Hegde (demo)' }, maths: { boost: 0.45, teacher: 'T. Iyer (demo)' }, computer_science: { boost: 0.3, teacher: 'H. Reddy (demo)' }, english: { boost: 0.1, teacher: 'J. Dsouza (demo)' } } },
};
const WEEKS = 9;
const IST = 5.5 * 3600e3;

export async function seedDemo(db: Db, now = Date.now()) {
  await db.q("UPDATE college SET demo = true WHERE id = 'demo-pu'");
  const sections = await db.q<{ id: string; year: string; board: string; subjects: string[]; roll_count: number }>("SELECT id, year, board, subjects, roll_count FROM section WHERE college_id = 'demo-pu'");
  let total = 0;
  for (const [si, sec] of sections.entries()) {
    const prof = PROFILE[sec.id];
    if (!prof) continue;
    const r = rng(1000 + si);
    const device = `brd_demo_${sec.id.replace(/^demo-/, '').replace(/-/g, '')}`;
    // Replace any earlier demo logs of this section (answers go with them).
    await db.q("DELETE FROM session_log WHERE section_id = $1 AND device_id IN (SELECT id FROM device WHERE name LIKE 'DEMO %' OR id LIKE 'brd_demo_%')", [sec.id]);
    await db.q(`INSERT INTO device(id, college_id, section_id, name, token_hash, pin_hash, pin_salt, last_seen_at) VALUES ($1,'demo-pu',$2,$3,$4,'-','-', now() - interval '2 hours')
      ON CONFLICT (id) DO UPDATE SET name = $3, last_seen_at = now() - interval '2 hours'`, [device, sec.id, `DEMO board · ${sec.id}`, `demo-not-a-token-${device}`]);

    // Lecturers on the timetable (Mon–Sat, one period per subject a day), so Outcomes can compare them.
    for (let day = 1; day <= 6; day++)
      for (const [i, subject] of sec.subjects.entries()) {
        const h = 9 + i;
        await db.q(`INSERT INTO timetable_slot(section_id, day, period, start_time, end_time, subject, teacher) VALUES ($1,$2,$3,$4,$5,$6,$7)
          ON CONFLICT (section_id, day, period) DO UPDATE SET teacher = coalesce(timetable_slot.teacher, $7)`,
          [sec.id, day, i + 1, `${String(h).padStart(2, '0')}:00`, `${String(h).padStart(2, '0')}:40`, subject, prof.subjects[subject]?.teacher ?? null]);
      }

    // The syllabus in book order, with the bank's questions per topic.
    const qs = await db.q<{ id: string; topic_id: string; chapter_id: string; subject: string; number: number; difficulty: string }>(
      `SELECT q.id, q.difficulty, q.topic_id, q.chapter_id, c.subject, c.number FROM question q JOIN chapter c ON c.id = q.chapter_id
       WHERE c.year = $1 AND c.subject = ANY($2) AND $3 = ANY(c.boards) AND q.topic_id IS NOT NULL ORDER BY c.number, q.topic_id, q.id`, [sec.year, sec.subjects, sec.board]);
    const qDiff = new Map(qs.map((q) => [q.id, q.difficulty === 'hard' ? 0.8 : q.difficulty === 'easy' ? -0.5 : 0.1]));
    const bySubject = new Map<string, { topic: string; chapter: string; qs: string[] }[]>();
    for (const q of qs) {
      const list = bySubject.get(q.subject) ?? bySubject.set(q.subject, []).get(q.subject)!;
      const last = list[list.length - 1];
      if (last?.topic === q.topic_id) last.qs.push(q.id);
      else list.push({ topic: q.topic_id, chapter: q.chapter_id, qs: [q.id] });
    }
    const ability = Array.from({ length: sec.roll_count }, () => prof.level + (r() + r() + r() - 1.5) * 1.6);
    const difficulty = new Map<string, number>();
    const practice = new Map<string, number>(); // `${roll}|${topic}` → answers so far (students learn)
    const pointer = new Map<string, number>();
    const taught: Record<string, { topic: string; chapter: string; qs: string[] }[]> = {};

    const logs: any[][] = [], answers: any[][] = [];
    const start = now - WEEKS * 7 * 864e5;
    for (let day = start; day < now - 864e5 / 2; day += 864e5) {
      const dow = new Date(day + IST).getUTCDay();
      if (dow === 0 || r() < 0.06) continue; // Sundays and the odd holiday
      const midnight = Math.floor((day + IST) / 864e5) * 864e5 - IST;
      for (const [pi, subject] of sec.subjects.entries()) {
        if (r() < 0.25) continue; // not every subject every day
        const syl = bySubject.get(subject) ?? [];
        if (!syl.length) continue;
        const sp = prof.subjects[subject] ?? { boost: 0, teacher: '' };
        const selfLearning = r() < 0.12;
        // Mostly the next topic; sometimes a re-teach of a weak earlier one.
        let topic: { topic: string; chapter: string; qs: string[] };
        const done = taught[subject] ?? (taught[subject] = []);
        // Re-teach: the board suggests the class's weakest taught topic.
        if (done.length > 2 && r() < 0.25) topic = [...done].sort((x, y) => (difficulty.get(y.topic) ?? 0) - (difficulty.get(x.topic) ?? 0))[Math.floor(r() * 2)];
        else {
          const i = pointer.get(subject) ?? 0;
          topic = syl[Math.min(i, syl.length - 1)];
          if (r() < 0.6) pointer.set(subject, i + 1);
          if (!done.includes(topic)) done.push(topic);
        }
        if (!difficulty.has(topic.topic)) difficulty.set(topic.topic, (r() - 0.45) * 1.8);
        // Classes improve over the term, faster where the subject is going well.
        const growth = ((day - start) / (7 * 864e5)) * 0.09 * (1 + sp.boost);
        const t0 = midnight + (9 + pi) * 3600e3; // 09:00 IST + period
        const at = (m: number) => new Date(t0 + m * 60e3).toISOString();
        const id = uuid(r);
        const ans: any[] = [];
        const present = sec.roll_count - Math.floor(r() * 6);
        const pick = [...topic.qs].sort(() => r() - 0.5).slice(0, 3 + Math.floor(r() * 3));
        for (const [qi, q] of pick.entries()) {
          const qd = (qDiff.get(q) ?? 0) + (r() - 0.5) * 0.4;
          const named = r() < 0.85;
          const n = named ? 10 + Math.floor(r() * 14) : 1;
          for (let k = 0; k < n; k++) {
            const roll = named ? 1 + Math.floor(r() * sec.roll_count) : undefined;
            const key = `${roll}|${topic.topic}`;
            const seen = roll ? practice.get(key) ?? 0 : 0;
            const a = roll ? ability[roll - 1] : prof.level;
            const ok = r() < sigmoid(1.3 * (a + sp.boost - difficulty.get(topic.topic)! - qd) + 0.25 * Math.min(seen, 5) + growth);
            if (roll) practice.set(key, seen + 1);
            const source = named ? (r() < 0.75 ? 'roll_call' : r() < 0.5 ? 'hands' : 'paper') : 'monitor';
            ans.push({ questionId: q, mode: named ? 'roll_call' : 'monitor', ...(roll ? { roll } : {}), chosen: ok ? 0 : 1 + Math.floor(r() * 3), correct: ok, at: at(25 + qi * 2 + k * 0.05), topicId: topic.topic, chapterId: topic.chapter, source });
          }
        }
        // A class challenge now and then: stars for the league.
        if (r() < 0.3) for (let k = 0; k < 1 + Math.floor(r() * 3); k++) ans.push({ questionId: topic.qs[0], mode: 'monitor', chosen: null, correct: r() < 0.7, at: at(36), topicId: topic.topic, chapterId: topic.chapter, source: 'challenge' });
        const completed = r() < 0.93;
        logs.push([id, device, sec.id, selfLearning ? 'self_learning' : 'teacher', topic.chapter, topic.topic, `${topic.topic}.lesson`, '1.1.0', at(0), at(38 + Math.floor(r() * 4)), completed,
          JSON.stringify(['intro', 'concept', 'class_quiz', 'recap']), JSON.stringify(ans), present]);
        ans.forEach((a, i) => answers.push([id, i, sec.id, a.questionId, a.topicId, a.chapterId, subject, a.roll ?? null, a.mode, a.source, a.correct, a.at]));
      }
    }
    await db.tx(async (c) => {
      for (let i = 0; i < logs.length; i += 200) {
        const chunk = logs.slice(i, i + 200);
        await c.query(`INSERT INTO session_log(id, device_id, section_id, mode, chapter_id, topic_id, lesson_id, pack_version, started_at, ended_at, completed, blocks_shown, answers, present)
          VALUES ${chunk.map((_, j) => `(${Array.from({ length: 14 }, (_, k) => `$${j * 14 + k + 1}`).join(',')})`).join(',')}`, chunk.flat());
      }
      for (let i = 0; i < answers.length; i += 1000) {
        const chunk = answers.slice(i, i + 1000);
        await c.query(`INSERT INTO answer(log_id, idx, section_id, question_id, topic_id, chapter_id, subject, roll, mode, source, correct, at)
          VALUES ${chunk.map((_, j) => `(${Array.from({ length: 12 }, (_, k) => `$${j * 12 + k + 1}`).join(',')})`).join(',')}`, chunk.flat());
      }
    });
    total += answers.length;
    console.log(`${sec.id}: ${logs.length} demo lessons, ${answers.length} answers`);
  }
  return total;
}

if (require.main === module) {
  const db = Db.fromEnv();
  seedDemo(db).then((n) => console.log(`demo data: ${n} answers`)).finally(() => db.pool.end());
}
