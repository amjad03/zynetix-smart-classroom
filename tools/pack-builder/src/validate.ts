/**
 * Content check for authors: `node dist/validate.js [packDir…]` (all packs when none given).
 * Beyond the schema it checks that every topic has a complete lesson, that each topic has at
 * least 3 questions, and that every 3D model, lab, animation and PhET id exists in Kinetix
 * (docs/content-assets.md).
 */
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { readSource, validate } from './build';
import { compile } from './expr';

const repo = resolve(__dirname, '../../..');
const content = join(repo, 'content');
const catalogue = readFileSync(join(repo, 'docs/content-assets.md'), 'utf8');
const section = (title: string) => catalogue.split('## ').find((s) => s.startsWith(title)) ?? '';
const tableIds = (title: string) => new Set([...section(title).matchAll(/^\| ([a-z0-9._-]+) \|/gm)].map((m) => m[1]).filter((x) => x !== 'modelId' && x !== 'labId' && x !== 'simId'));
const models = tableIds('3d_model'), labs = tableIds('virtual_lab'), sims = tableIds('simulation, source `kinetix_sim`'), phet = tableIds('simulation, source `phet`');
const csSims = tableIds('simulation, source `kinetix_cs`');
const anims = new Set([...section('simulation, source `animation`').matchAll(/`([a-z0-9-]+)`/g)].map((m) => m[1]));
const REQUIRED = ['intro', 'concept', 'example', 'class_quiz', 'recap'];

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
      if (b.type === 'interactive') {
        const names = ['x', ...b.sliders.map((sl) => sl.name)];
        const vars = Object.fromEntries(b.sliders.map((sl) => [sl.name, sl.value]));
        for (const sl of b.sliders) if (!(sl.min <= sl.value && sl.value <= sl.max)) problems.push(`${l.id}/${b.id}: slider ${sl.name} value outside min..max`);
        const exprs = [...(b.fns ?? []).map((f) => f.fn), ...b.readouts.map((r) => r.expr),
          ...[...(b.vectors ?? []).flat(), ...Object.values(b.data ?? {}), ...(b.points ?? [])].filter((v): v is string => typeof v === 'string')];
        for (const ex of exprs) {
          try {
            const f = compile(ex, names);
            const xs = b.x ? [b.x[0], (b.x[0] + b.x[1]) / 2, b.x[1]] : [1];
            if (xs.every((x) => !Number.isFinite(f({ ...vars, x })))) problems.push(`${l.id}/${b.id}: "${ex}" is not a number at the default slider values`);
          } catch (e) { problems.push(`${l.id}/${b.id}: ${(e as Error).message}`); }
        }
        const need: Record<string, boolean> = { function_plot: !!b.fns?.length && !!b.x && !!b.y, vectors: !!b.vectors?.length, bar_chart: !!b.data, pie_chart: !!b.data, unit_circle: b.sliders.some((sl) => sl.name === 'theta'), number_line: !!b.points?.length && !!b.x, readouts: b.readouts.length > 0 };
        if (!need[b.kind]) problems.push(`${l.id}/${b.id}: ${b.kind} is missing its fields (see lesson-schema InteractiveBlock)`);
      }
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
