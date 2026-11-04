import { Ans, Mastery, dayKey, leaguePoints, readiness, step, weekStart } from '../src/outcomes';

const a = (t: string, ok: boolean, r: number | null = null, exams = ['JEE']): Ans => ({ s: 's', t, sub: 'physics', r, ok, src: 'roll_call', ms: 0, exams });

describe('Outcomes maths (same as the board mastery store)', () => {
  it('moves an estimate 35% of the way per answer from 0.5, and judges a level only after 2 answers', () => {
    expect(step(undefined, true).p).toBeCloseTo(0.675);
    expect(step(step(undefined, false), false).p).toBeCloseTo(0.21125);
  });

  it('class on a topic is the mean of the roll numbers when 3+ are assessed', () => {
    const m = new Mastery();
    for (const r of [1, 2, 3, 4]) for (let i = 0; i < 3; i++) m.apply(a('t', r <= 2, r));
    expect(m.classTopic('t')!.p).toBeCloseTo(0.5, 5);
    expect(m.classTopic('t')!.n).toBe(12);
    expect(m.rollsOn('t')).toMatchObject({ assessed: 4, stuck: [3, 4], mastered: 2 });
  });

  it('readiness bands are honest: not enough data, needs work, on track, and exam-ready only with coverage', () => {
    const topics = new Set(['t1', 't2', 't3', 't4', 't5']);
    const many = (ts: string[], ok: boolean) => ts.flatMap((t) => Array.from({ length: 6 }, () => a(t, ok)));
    expect(readiness(many(['t1'], true), 'JEE', topics).band).toBe('not_enough_data'); // 20% would pass, but only 6 answers
    expect(readiness(many(['t1', 't2'], false), 'JEE', topics).band).toBe('not_enough_data');
    expect(readiness(many(['t1', 't2', 't3', 't4'], false), 'JEE', topics)).toMatchObject({ band: 'needs_work', label: 'Needs work' });
    expect(readiness(many(['t1', 't2', 't3', 't4'], true), 'JEE', topics)).toMatchObject({ band: 'exam_ready', coverage: 0.8 });
    expect(readiness(many(['t1', 't2', 't3', 't4'], true), 'NEET', topics).band).toBe('not_enough_data'); // only JEE-tagged answers count
    const big = new Set([...topics, 't6', 't7', 't8', 't9', 't10']);
    expect(readiness(many(['t1', 't2', 't3', 't4'], true), 'JEE', big)).toMatchObject({ band: 'on_track', coverage: 0.4 }); // strong, but too little seen
  });

  it('league points: scaled to a class of 40, stars count double extra, plus the longest teaching streak', () => {
    const w = weekStart(Date.UTC(2026, 10, 4, 6)); // Wed 4 Nov 2026 → Mon 2 Nov (IST)
    expect(dayKey(w)).toBe('2026-11-02');
    const days = new Set(['2026-11-02', '2026-11-03', '2026-11-05', '2026-11-06', '2026-11-07']);
    expect(leaguePoints(50, 5, 80, days, w)).toEqual({ points: 30 + 30, correct: 50, stars: 5, streakDays: 3 });
  });
});
