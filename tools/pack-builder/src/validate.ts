/**
 * Content check for authors: `node dist/validate.js [packDir…]` (all packs when none given).
 * Beyond the schema it checks that every topic has a complete lesson, that each topic has at
 * least 3 questions, and that every 3D model, lab, animation and PhET id exists in Kinetix
 * (docs/content-assets.md).
 */
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { readSource, validate } from './build';
import { compile, type Expr } from './expr';
import { PlayModel } from './sim';
import type { Block, Shape } from '@zynetix/lesson-schema';

const repo = resolve(__dirname, '../../..');
const content = join(repo, 'content');
const catalogue = readFileSync(join(repo, 'docs/content-assets.md'), 'utf8');
const section = (title: string) => catalogue.split('## ').find((s) => s.startsWith(title)) ?? '';
const tableIds = (title: string) => new Set([...section(title).matchAll(/^\| ([a-z0-9._-]+) \|/gm)].map((m) => m[1]).filter((x) => x !== 'modelId' && x !== 'labId' && x !== 'simId'));
const models = tableIds('3d_model'), labs = tableIds('virtual_lab'), sims = tableIds('simulation, source `kinetix_sim`'), phet = tableIds('simulation, source `phet`');
const csSims = tableIds('simulation, source `kinetix_cs`');
const anims = new Set([...section('simulation, source `animation`').matchAll(/`([a-z0-9-]+)`/g)].map((m) => m[1]));
const REQUIRED = ['intro', 'concept', 'example', 'class_quiz', 'recap'];

type Playfield = Extract<Block, { type: 'interactive' | 'challenge' }>;
type Challenge = Extract<Block, { type: 'challenge' }>;
type Activity = Extract<Block, { type: 'activity' }>;
type Vars = Record<string, number>;
const truthy = (v: number) => v !== 0 && !Number.isNaN(v);

// ---------------------------------------------------------------- scene shapes

const NUM_KEYS = ['x', 'y', 'r', 'w', 'h', 'x1', 'y1', 'x2', 'y2', 'dx', 'dy', 'from', 'to', 'width', 'size', 'amp', 'angle', 'on', 'opacity'] as const;
const INTERP = /\{([^{}:]+)(?::(\d))?\}/g;

/** A shape's expressions, compiled; `values(env)` gives every drawn number (NaN where it cannot be computed). */
interface CompiledShape { shape: Shape; check(env: Vars, view: [number, number]): string | undefined }

function compileShape(sh: Shape, names: string[], fail: (m: string) => void): CompiledShape | undefined {
  const own = sh.shape === 'particles' ? [...names, 'i'] : names;
  let ok = true;
  const c = (src: string | number, extra: string[] = []): Expr => {
    if (typeof src === 'number') return () => src;
    try { return compile(src, [...own, ...extra]); } catch (e) { ok = false; fail(`${sh.shape}: ${(e as Error).message}`); return () => NaN; }
  };
  const rec = sh as unknown as Record<string, unknown>;
  const nums: [string, Expr][] = [];
  for (const k of NUM_KEYS) if (k in rec && (typeof rec[k] === 'number' || typeof rec[k] === 'string')) nums.push([k, c(rec[k] as string | number)]);
  const visible = sh.visibleIf ? c(sh.visibleIf) : undefined;
  const colorBy = sh.color && typeof sh.color === 'object' ? c(sh.color.by) : undefined;
  const fn = 'fn' in sh && sh.fn ? c(sh.fn, ['x']) : undefined;
  const points = 'points' in sh && sh.points ? sh.points.map(([px, py]) => [c(px), c(py)] as const) : [];
  const texts = 'text' in sh ? [...sh.text.en.matchAll(INTERP), ...(sh.text.kn ?? '').matchAll(INTERP)].map((m) => c(m[1].trim())) : [];
  if (!ok) return undefined;
  const one = (env: Vars, view: [number, number]): string | undefined => {
    if (visible && !truthy(visible(env))) return undefined;
    for (const [k, f] of nums) if (!Number.isFinite(f(env))) return `${k} is not a number`;
    if (colorBy && !Number.isFinite(colorBy(env))) return 'color.by is not a number';
    for (const [px, py] of points) if (!Number.isFinite(px(env)) || !Number.isFinite(py(env))) return 'a point is not a number';
    for (const f of texts) if (!Number.isFinite(f(env))) return 'a {value} in the text is not a number';
    if (fn) {
      const from = nums.find(([k]) => k === 'from')?.[1](env) ?? view[0], to = nums.find(([k]) => k === 'to')?.[1](env) ?? view[1];
      let any = false;
      for (let k = 0; k <= 40 && !any; k++) any = Number.isFinite(fn({ ...env, x: from + ((to - from) * k) / 40 }));
      if (!any) return 'fn is not a number anywhere on its range';
    }
    return undefined;
  };
  return {
    shape: sh,
    check: (env, view) => {
      if (sh.shape !== 'particles') return one(env, view);
      for (let i = 0; i < sh.count; i++) { const p = one({ ...env, i }, view); if (p) return `particle ${i}: ${p}`; }
      return undefined;
    },
  };
}

/** Control settings to try: the defaults, every slider at its min and at its max, toggles flipped, each choice option. */
function settings(m: PlayModel): Vars[] {
  const d = m.defaults();
  const out: Vars[] = [d];
  const sl = m.controls.filter((c) => c.kind === 'slider');
  if (sl.length) {
    out.push({ ...d, ...Object.fromEntries(sl.map((c) => [c.name, c.min!])) });
    out.push({ ...d, ...Object.fromEntries(sl.map((c) => [c.name, c.max!])) });
  }
  const tg = m.controls.filter((c) => c.kind === 'toggle');
  if (tg.length) out.push({ ...d, ...Object.fromEntries(tg.map((c) => [c.name, 1 - c.value])) });
  for (const c of m.controls.filter((c) => c.kind === 'choice')) for (const v of c.values ?? []) if (v !== c.value) out.push({ ...d, [c.name]: v });
  return out;
}

const describe = (v: Vars, m: PlayModel) => m.controls.filter((c) => c.kind !== 'handle').map((c) => `${c.name}=${+v[c.name].toFixed(4)}`).join(' ');

/** The slider playfield of an interactive or a challenge: names, ranges, expressions, required fields. */
export function checkPlayfield(b: Playfield, where: string): string[] {
  const problems: string[] = [];
  const m = new PlayModel(b, where);
  problems.push(...m.problems);
  for (const sl of b.sliders) if (!(sl.min <= sl.value && sl.value <= sl.max)) problems.push(`${where}: slider ${sl.name} value outside min..max`);
  for (const ch of b.choices ?? []) {
    if (!ch.options.some((o) => o.value === ch.value)) problems.push(`${where}: choice ${ch.name} starts at ${ch.value}, which is not one of its options`);
    if (new Set(ch.options.map((o) => o.value)).size !== ch.options.length) problems.push(`${where}: choice ${ch.name} has two options with the same value`);
  }
  for (const ct of b.counters ?? []) if ((ct.min !== undefined && ct.value < ct.min) || (ct.max !== undefined && ct.value > ct.max)) problems.push(`${where}: counter ${ct.name} starts outside min..max`);
  for (const m2 of b.marks ?? []) {
    const inX = !b.x || (b.x[0] <= m2.x && m2.x <= b.x[1]), inY = !b.y || (b.y[0] <= m2.y && m2.y <= b.y[1]);
    if (!inX || !inY) problems.push(`${where}: mark (${m2.x}, ${m2.y}) is outside the plot`);
  }
  // Buttons may change sliders, toggles, choices and counters.
  const settable = new Set(m.controls.filter((c) => c.kind !== 'handle').map((c) => c.name));
  for (const [k, bt] of (b.buttons ?? []).entries()) {
    if (!Object.keys(bt.set).length && !bt.reset && !bt.play) problems.push(`${where}: button ${k + 1} does nothing (give it set, reset or play)`);
    if ((bt.reset || bt.play) && !b.time) problems.push(`${where}: button ${k + 1} resets or plays time, but there is no time`);
    for (const [name, ex] of Object.entries(bt.set)) {
      if (!settable.has(name)) problems.push(`${where}: button ${k + 1} sets "${name}", which is not a slider, toggle, choice or counter`);
      if (typeof ex === 'string') m.compile(ex, m.names, `button ${k + 1} ${name}`);
    }
  }
  problems.push(...m.problems.filter((p) => !problems.includes(p)));
  // Handles live on a scene, inside their box and the view.
  if (b.handles?.length && b.kind !== 'scene') problems.push(`${where}: handles need kind scene`);
  const view = b.view;
  for (const h of b.handles ?? []) {
    const box = h.box ?? view;
    if (box && !(box.x[0] <= h.x && h.x <= box.x[1] && box.y[0] <= h.y && h.y <= box.y[1])) problems.push(`${where}: handle ${h.name} starts outside its box`);
    if (h.axis && h.line) problems.push(`${where}: handle ${h.name} has both axis and line`);
  }
  if (view && (view.x[0] >= view.x[1] || view.y[0] >= view.y[1])) problems.push(`${where}: view ranges must go from low to high`);
  // Expressions of the classic kinds may also use x (as before), vars, state and t.
  const legacy = ['x', ...m.names];
  const exprs = [...(b.fns ?? []).map((f) => f.fn), ...b.readouts.map((r) => r.expr),
    ...[...(b.vectors ?? []).flat(), ...Object.values(b.data ?? {}), ...(b.points ?? [])].filter((v): v is string => typeof v === 'string')];
  const start = m.env(m.defaults(), m.min, m.initState(m.defaults()));
  for (const ex of exprs) {
    try {
      const f = compile(ex, legacy);
      const xs = b.x ? [b.x[0], (b.x[0] + b.x[1]) / 2, b.x[1]] : [1];
      if (xs.every((x) => !Number.isFinite(f({ ...start, x })))) problems.push(`${where}: "${ex}" is not a number at the default slider values`);
    } catch (e) { problems.push(`${where}: ${(e as Error).message}`); }
  }
  // Scenes: compile every shape, then run each setting through the whole time range.
  const shapes: CompiledShape[] = [];
  for (const [k, sh] of (b.shapes ?? []).entries()) {
    const cs = compileShape(sh, m.names, (msg) => problems.push(`${where}: shape ${k + 1} ${msg}`));
    if (cs) shapes.push(cs);
    if (sh.shape === 'trail' && !b.time) problems.push(`${where}: shape ${k + 1} trail needs time`);
  }
  if (b.shapes?.length && b.kind !== 'scene') problems.push(`${where}: shapes need kind scene`);
  if (!problems.length && (shapes.length || b.time)) {
    const vx: [number, number] = view?.x ?? b.x ?? [0, 1];
    const reported = new Set<number>();
    for (const set of settings(m)) {
      m.run(set, (env) => {
        for (const [k, cs] of shapes.entries()) {
          if (reported.has(k)) continue;
          const p = cs.check(env, vx);
          if (p) { reported.add(k); problems.push(`${where}: shape ${k + 1} (${cs.shape.shape}) ${p} at ${m.hasTime ? `t=${+env.t.toFixed(3)} ` : ''}with ${describe(set, m)}`); }
        }
      });
    }
  }
  const need: Record<string, boolean> = {
    function_plot: !!b.fns?.length && !!b.x && !!b.y, vectors: !!b.vectors?.length, bar_chart: !!b.data, pie_chart: !!b.data,
    unit_circle: b.sliders.some((sl) => sl.name === 'theta'), number_line: !!b.points?.length && !!b.x, readouts: b.readouts.length > 0,
    scene: !!view && !!b.shapes?.length,
  };
  if (!need[b.kind]) problems.push(`${where}: ${b.kind} is missing its fields (see lesson-schema InteractiveBlock)`);
  return problems;
}

/**
 * A challenge must be winnable and not won before anyone moves: the goal compiles over the
 * playfield's names, the solution sets every slider to a value the slider can reach (inside
 * min..max, on its step), other controls to values they can take, and puts the goal within
 * tolerance of the target, and the starting values do not. With time, the goal is taken where
 * the model stops (stopWhen or the end of time).
 */
export function checkChallenge(b: Challenge, where: string): string[] {
  const problems: string[] = [];
  const m = new PlayModel(b, where);
  if (m.problems.length) return m.problems;
  let goal: Expr;
  try { goal = compile(b.goal, m.names); } catch (e) { return [`${where}: goal ${(e as Error).message}`]; }
  const sol = b.solution;
  const byName = new Map(m.controls.map((c) => [c.name, c]));
  for (const k of Object.keys(sol)) if (!byName.has(k) || byName.get(k)!.kind === 'counter') problems.push(`${where}: solution sets unknown slider ${k}`);
  for (const sl of b.sliders) {
    const v = sol[sl.name];
    if (v === undefined) { problems.push(`${where}: solution has no value for slider ${sl.name}`); continue; }
    if (v < sl.min - 1e-9 || v > sl.max + 1e-9) problems.push(`${where}: solution ${sl.name} = ${v} is outside ${sl.min}..${sl.max}`);
    const k = (v - sl.min) / sl.step;
    if (Math.abs(k - Math.round(k)) > 1e-6) problems.push(`${where}: solution ${sl.name} = ${v} is not on the slider's step ${sl.step}`);
  }
  for (const c of m.controls) if (c.values && sol[c.name] !== undefined && !c.values.includes(sol[c.name])) problems.push(`${where}: solution ${c.name} = ${sol[c.name]} is not a value it can take`);
  if (problems.length) return problems;
  const value = (controls: Vars) => goal(m.hasTime ? m.run(controls) : m.env(controls, m.min, m.initState(controls)));
  const hit = value({ ...m.defaults(), ...sol });
  if (!Number.isFinite(hit)) problems.push(`${where}: goal is not a number at the solution`);
  else if (Math.abs(hit - b.target) > b.tolerance + 1e-9) problems.push(`${where}: solution gives ${+hit.toFixed(6)}, not ${b.target} ± ${b.tolerance}: not solvable as written`);
  const start = value(m.defaults());
  if (Number.isFinite(start) && Math.abs(start - b.target) <= b.tolerance) problems.push(`${where}: the starting slider values already hit the target`);
  const norm = (s: string) => s.replace(/\s+/g, '');
  if (b.readouts.some((r) => norm(r.expr) === norm(b.goal))) problems.push(`${where}: a readout shows the goal itself (it is revealed after each try)`);
  return problems;
}

// ---------------------------------------------------------------- activities

const inView = (v: { x: [number, number]; y: [number, number] }, t: { x: number; y: number; r?: number; w?: number; h?: number }) => {
  const rx = t.w !== undefined ? t.w / 2 : t.r ?? 0, ry = t.h !== undefined ? t.h / 2 : t.r ?? 0;
  return v.x[0] <= t.x - rx && t.x + rx <= v.x[1] && v.y[0] <= t.y - ry && t.y + ry <= v.y[1];
};

/** The blank numbers in a passage, in the order they appear (`__1__`, `__2__`…). */
export const blanksIn = (text: string) => [...text.matchAll(/__(\d+)__/g)].map((x) => Number(x[1]));

/** An activity must be solvable: every item has exactly one right place, nothing is duplicated, targets sit inside the diagram. */
export function checkActivity(b: Activity, where: string): string[] {
  const p: string[] = [];
  const need = (ok: unknown, what: string) => { if (!ok) p.push(`${where}: ${b.kind} needs ${what}`); return !!ok; };
  const dupes = (xs: string[], what: string) => { if (new Set(xs.map((x) => x.trim().toLowerCase())).size !== xs.length) p.push(`${where}: two ${what} are the same`); };
  switch (b.kind) {
    case 'sort':
      if (need(b.buckets && b.items, 'buckets and items')) {
        const ids = b.buckets!.map((x) => x.id);
        dupes(ids, 'bucket ids');
        dupes(b.buckets!.map((x) => x.label.en), 'bucket labels');
        dupes(b.items!.map((x) => x.text.en), 'items');
        for (const it of b.items!) if (!ids.includes(it.answer)) p.push(`${where}: item "${it.text.en}" goes to unknown bucket ${it.answer}`);
        for (const id of ids) if (!b.items!.some((it) => it.answer === id)) p.push(`${where}: bucket ${id} gets no item`);
      }
      break;
    case 'order':
      if (need(b.steps, 'steps (in the right order)')) dupes(b.steps!.map((x) => x.en), 'steps');
      break;
    case 'match':
      if (need(b.pairs, 'pairs')) { dupes(b.pairs!.map((x) => x.left.en), 'left items'); dupes(b.pairs!.map((x) => x.right.en), 'right items'); }
      break;
    case 'label':
    case 'hotspot':
      if (need(b.view && b.targets, 'a view and targets')) {
        dupes(b.targets!.map((x) => x.id), 'target ids');
        if (b.kind === 'label') dupes([...b.targets!.map((x) => x.label.en), ...(b.distractors ?? []).map((x) => x.en)], 'labels');
        for (const t of b.targets!) {
          if (t.r === undefined && (t.w === undefined || t.h === undefined)) p.push(`${where}: target ${t.id} needs r, or w and h`);
          else if (!inView(b.view!, t)) p.push(`${where}: target ${t.id} is not inside the view`);
        }
        if (b.kind === 'hotspot' && need(b.answer, 'answer (the right target ids)')) {
          for (const a of b.answer!) if (!b.targets!.some((t) => t.id === a)) p.push(`${where}: answer ${a} is not a target`);
          if (new Set(b.answer!).size !== b.answer!.length) p.push(`${where}: answer repeats a target`);
          if (b.answer!.length >= b.targets!.length) p.push(`${where}: every target is right; add wrong ones`);
        }
      }
      for (const [k, sh] of (b.shapes ?? []).entries()) {
        const cs = compileShape(sh, [], (msg) => p.push(`${where}: shape ${k + 1} ${msg}`));
        const bad = cs?.check({}, b.view?.x ?? [0, 1]);
        if (bad) p.push(`${where}: shape ${k + 1} (${sh.shape}) ${bad}`);
      }
      break;
    case 'fill':
      if (need(b.passage && b.blanks, 'a passage and blanks')) {
        const want = b.blanks!.map((_, k) => k + 1).join(',');
        if (blanksIn(b.passage!.en).join(',') !== want) p.push(`${where}: the English passage must have blanks __1__ … __${b.blanks!.length}__, each once and in order`);
        if (b.passage!.kn && blanksIn(b.passage!.kn).sort((x, y) => x - y).join(',') !== want) p.push(`${where}: the Kannada passage must have the same blanks`);
        for (const [k, bl] of b.blanks!.entries()) {
          if (bl.answer >= bl.options.length) p.push(`${where}: blank ${k + 1} answer is not one of its options`);
          dupes(bl.options.map((o) => o.en), `options of blank ${k + 1}`);
        }
      }
      break;
  }
  return p;
}

export function check(dir: string): string[] {
  const problems: string[] = [];
  let src;
  try {
    src = readSource(content, dir);
  } catch (e) {
    return [`${dir}: ${(e as Error).message.split('\n').slice(0, 6).join(' | ')}`];
  }
  problems.push(...validate(src));
  if (!src.chapter.topics.length) problems.push('chapter has no topics (add topics.json)');
  const byTopic = new Map(src.lessons.map((l) => [l.topicId, l]));
  for (const t of src.chapter.topics) {
    const l = byTopic.get(t.id);
    if (!l) { problems.push(`topic ${t.id} has no lesson`); continue; }
    for (const r of REQUIRED) if (!l.blocks.some((b) => b.type === r)) problems.push(`${l.id}: no ${r} block`);
    const n = src.questions.filter((q) => q.topicId === t.id).length;
    if (n < 3) problems.push(`topic ${t.id}: ${n} questions (need ≥ 3)`);
    const topicBoards = t.boards ?? src.chapter.boards;
    for (const bd of topicBoards) if (!src.chapter.boards.includes(bd)) problems.push(`topic ${t.id}: board ${bd} not in the chapter's boards`);
    for (const b of l.blocks) {
      for (const bd of b.boards ?? []) if (!topicBoards.includes(bd)) problems.push(`${l.id}/${b.id}: board ${bd} not taught in this topic`);
      if (b.type === 'whiteboard') {
        for (const [si, st] of b.steps.entries()) {
          const hasAxes = st.draw.some((d) => d.kind === 'axes');
          for (const d of st.draw) {
            if (d.kind !== 'plot') continue;
            if (!hasAxes) problems.push(`${l.id}/${b.id} step ${si + 1}: plot needs axes in the same step`);
            try { compile(d.fn, ['x']); } catch (e) { problems.push(`${l.id}/${b.id} step ${si + 1}: ${(e as Error).message}`); }
          }
        }
      }
      if (b.type === 'interactive' || b.type === 'challenge') problems.push(...checkPlayfield(b, `${l.id}/${b.id}`));
      if (b.type === 'challenge') problems.push(...checkChallenge(b, `${l.id}/${b.id}`));
      if (b.type === 'activity') problems.push(...checkActivity(b, `${l.id}/${b.id}`));
      if (b.type === '3d_model' && !models.has(b.modelId)) problems.push(`${l.id}/${b.id}: unknown 3D model ${b.modelId}`);
      if (b.type === 'virtual_lab' && !labs.has(b.labId)) problems.push(`${l.id}/${b.id}: unknown lab ${b.labId}`);
      if (b.type === 'simulation') {
        const ok = b.source === 'phet' ? phet.has(b.simId) : b.source === 'animation' ? anims.has(b.simId) : b.source === 'kinetix_cs' ? csSims.has(b.simId) : sims.has(b.simId) || labs.has(b.simId);
        if (!ok) problems.push(`${l.id}/${b.id}: unknown ${b.source} sim ${b.simId}`);
      }
    }
  }
  for (const q of src.questions) {
    if (q.chapterId !== src.chapter.id) problems.push(`${q.id}: chapterId ${q.chapterId}`);
    if (q.topicId && !src.chapter.topics.some((t) => t.id === q.topicId)) problems.push(`${q.id}: unknown topic ${q.topicId}`);
    if (q.pyq) problems.push(`${q.id}: do not label PYQ years (unverified)`);
    if (q.format !== 'numeric' && new Set(q.options.map((o) => o.en.trim())).size !== 4) problems.push(`${q.id}: duplicate options`);
    if (q.exams.includes('JEE_ADV') && q.difficulty === 'easy') problems.push(`${q.id}: JEE Advanced questions should not be easy`);
    if (q.format === 'assertion_reason' && !/assertion/i.test(q.stem.en)) problems.push(`${q.id}: assertion_reason stem must state the Assertion (A) and Reason (R)`);
    if (q.format === 'assertion_reason' && !q.options.some((o) => /correct explanation/i.test(o.en))) problems.push(`${q.id}: assertion_reason needs the standard four A–R options`);
    const qt = src.chapter.topics.find((t) => t.id === q.topicId);
    if (q.exams.includes('CBSE') && qt?.boards && !qt.boards.includes('cbse')) problems.push(`${q.id}: tagged CBSE but its topic is not in the CBSE syllabus`);
    if (q.exams.includes('CBSE') && !src.chapter.boards.includes('cbse')) problems.push(`${q.id}: tagged CBSE but the chapter is not in the CBSE syllabus`);
    if (q.exams.includes('ISC') && qt?.boards && !qt.boards.includes('isc')) problems.push(`${q.id}: tagged ISC but its topic is not in the ISC syllabus`);
    if (q.exams.includes('ISC') && !src.chapter.boards.includes('isc')) problems.push(`${q.id}: tagged ISC but the chapter is not in the ISC syllabus`);
  }
  const ids = src.questions.map((q) => q.id);
  if (new Set(ids).size !== ids.length) problems.push('duplicate question ids');
  return problems;
}

if (require.main === module) {
  const dirs = process.argv.slice(2).length ? process.argv.slice(2) : readdirSync(join(content, 'packs')).filter((d) => existsSync(join(content, 'packs', d, 'pack.json')));
  let bad = 0;
  for (const d of dirs) {
    const p = check(d);
    if (p.length) bad++;
    console.log(p.length ? `✗ ${d}\n  ${p.join('\n  ')}` : `✓ ${d}`);
  }
  console.log(`${dirs.length - bad}/${dirs.length} packs valid`);
  process.exit(bad ? 1 : 0);
}
