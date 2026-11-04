/**
 * Outcomes maths, kept the same as the board's MasteryStore (apps/board/lib/engine/mastery.dart)
 * so the principal and the teacher see the same picture:
 * - an estimate starts at 0.5 and each answer moves it RATE of the way towards 1 (right) or 0 (wrong);
 * - with fewer than 2 answers it is "unknown"; 0.75+ is mastered, 0.5+ learning, under 0.5 stuck.
 * Roll numbers only, never names.
 */

export const RATE = 0.35;
export type Est = { p: number; n: number };
export type Level = 'unknown' | 'stuck' | 'learning' | 'mastered';

export const step = (e: Est | undefined, ok: boolean): Est => {
  const p = e?.p ?? 0.5;
  return { p: p + RATE * ((ok ? 1 : 0) - p), n: (e?.n ?? 0) + 1 };
};
export const level = (e?: Est): Level => (!e || e.n < 2 ? 'unknown' : e.p >= 0.75 ? 'mastered' : e.p >= 0.5 ? 'learning' : 'stuck');
export const mean = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
export const r2 = (x: number | null) => (x == null ? null : Math.round(x * 100) / 100);

/** One answer row as the Outcomes queries load it. */
export type Ans = { s: string; t: string; sub: string | null; r: number | null; ok: boolean; src: string; ms: number; exams: string[] | null };

/** Indian Standard Time: weeks run Monday to Sunday in the college's day. */
const IST = 5.5 * 3600e3;
export const weekStart = (ms: number) => {
  const d = new Date(ms + IST);
  const back = (d.getUTCDay() + 6) % 7;
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - back) - IST;
};
export const dayKey = (ms: number) => new Date(ms + IST).toISOString().slice(0, 10);
/** The last `n` week starts (UTC ms of Monday 00:00 IST), oldest first, ending with this week. */
export const lastWeeks = (n: number, now = Date.now()) => {
  const w = weekStart(now);
  return Array.from({ length: n }, (_, i) => w - (n - 1 - i) * 7 * 864e5);
};

/** Class (all answers) and per-roll estimates per topic, built in time order. */
export class Mastery {
  topic = new Map<string, Est>();
  roll = new Map<number, Map<string, Est>>();
  apply(a: Pick<Ans, 't' | 'r' | 'ok'>) {
    this.topic.set(a.t, step(this.topic.get(a.t), a.ok));
    if (a.r != null) {
      let m = this.roll.get(a.r);
      if (!m) this.roll.set(a.r, (m = new Map()));
      m.set(a.t, step(m.get(a.t), a.ok));
    }
  }
  /**
   * The class on a topic. With 3+ roll numbers assessed it is the mean of their own estimates
   * (a whole-class moving average would only reflect the last few answers); otherwise the
   * board's class estimate over every answer, named or not. n is always all answers.
   */
  classTopic(t: string): Est | undefined {
    const e = this.topic.get(t);
    if (!e) return undefined;
    const ps: number[] = [];
    for (const m of this.roll.values()) {
      const r = m.get(t);
      if (r && r.n >= 2) ps.push(r.p);
    }
    return ps.length >= 3 ? { p: mean(ps)!, n: e.n } : e;
  }
  /** Mean class estimate over topics with 2+ answers (optionally only some topics). */
  classMastery(keep: (topicId: string) => boolean = () => true) {
    return mean([...this.topic.keys()].filter((t) => this.topic.get(t)!.n >= 2 && keep(t)).map((t) => this.classTopic(t)!.p));
  }
  /** Roll numbers with 2+ answers on a topic, split by level. */
  rollsOn(topicId: string) {
    const out = { assessed: 0, stuck: [] as number[], learning: 0, mastered: 0 };
    for (const [r, m] of this.roll) {
      const lv = level(m.get(topicId));
      if (lv === 'unknown') continue;
      out.assessed++;
      if (lv === 'stuck') out.stuck.push(r);
      else if (lv === 'learning') out.learning++;
      else out.mastered++;
    }
    out.stuck.sort((a, b) => a - b);
    return out;
  }
}

/**
 * Class mastery at each boundary (answers before it count), e.g. the end of each week.
 * `answers` must be in time order; null where nothing had been answered yet.
 */
export function snapshots(answers: Ans[], boundaries: number[], keep: (a: Ans) => boolean) {
  const m = new Mastery();
  const out: (number | null)[] = [];
  let i = 0;
  for (const b of boundaries) {
    while (i < answers.length && answers[i].ms < b) {
      if (keep(answers[i])) m.apply(answers[i]);
      i++;
    }
    out.push(r2(m.classMastery()));
  }
  return out;
}

export type Band = 'exam_ready' | 'on_track' | 'needs_work' | 'not_enough_data';
export const BAND_LABEL: Record<Band, string> = { exam_ready: 'Exam-ready', on_track: 'On track', needs_work: 'Needs work', not_enough_data: 'Not enough data' };

/**
 * Exam readiness from mastery over an exam's tagged questions only, with honest bands:
 * - Not enough data: under `minAnswers` tagged answers, or under 20% of the exam's topics seen (2+ answers);
 * - otherwise the mean estimate over the topics seen: 0.75+ Exam-ready (only if 60%+ of topics are seen,
 *   else at most On track), 0.5+ On track, under 0.5 Needs work.
 */
export function readiness(answers: Ans[], exam: string, examTopics: Set<string>, minAnswers = 20) {
  const m = new Mastery();
  let answered = 0;
  for (const a of answers) {
    if (!a.exams?.includes(exam) || !examTopics.has(a.t)) continue;
    answered++;
    m.apply(a);
  }
  const seen = [...m.topic.keys()].map((t) => m.classTopic(t)!).filter((e) => e.n >= 2);
  const coverage = examTopics.size ? seen.length / examTopics.size : 0;
  const score = mean(seen.map((e) => e.p));
  let band: Band;
  if (answered < minAnswers || coverage < 0.2 || score == null) band = 'not_enough_data';
  else if (score >= 0.75) band = coverage >= 0.6 ? 'exam_ready' : 'on_track';
  else band = score >= 0.5 ? 'on_track' : 'needs_work';
  return { exam, band, label: BAND_LABEL[band], score: r2(score), coverage: r2(coverage), answered, topicsSeen: seen.length, topics: examTopics.size };
}

/**
 * League points for one section in one week, fair between big and small sections:
 * (correct answers + 2 × challenge stars) scaled to a class of 40, plus 10 per day of the
 * week's longest teaching streak (consecutive school days, Mon–Sat, with a completed lesson).
 */
export function leaguePoints(correct: number, stars: number, rollCount: number, activeDays: Set<string>, week: number) {
  let best = 0, run = 0;
  for (let d = 0; d < 6; d++) {
    run = activeDays.has(dayKey(week + d * 864e5)) ? run + 1 : 0;
    best = Math.max(best, run);
  }
  const points = Math.round(((correct + 2 * stars) * 40) / Math.max(1, rollCount)) + 10 * best;
  return { points, correct, stars, streakDays: best };
}
