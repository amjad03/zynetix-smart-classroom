/**
 * Content check for authors: `node dist/validate.js [packDir…]` (all packs when none given).
 * Beyond the schema it checks that every topic has a complete lesson, that each topic has at
 * least 3 questions, and that every 3D model, lab, animation and PhET id exists in Kinetix
 * (docs/content-assets.md).
 */
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { readSource, validate } from './build';

const repo = resolve(__dirname, '../../..');
const content = join(repo, 'content');
const catalogue = readFileSync(join(repo, 'docs/content-assets.md'), 'utf8');
const section = (title: string) => catalogue.split('## ').find((s) => s.startsWith(title)) ?? '';
const tableIds = (title: string) => new Set([...section(title).matchAll(/^\| ([a-z0-9._-]+) \|/gm)].map((m) => m[1]).filter((x) => x !== 'modelId' && x !== 'labId' && x !== 'simId'));
const models = tableIds('3d_model'), labs = tableIds('virtual_lab'), sims = tableIds('simulation, source `kinetix_sim`'), phet = tableIds('simulation, source `phet`');
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
    for (const b of l.blocks) {
      if (b.type === '3d_model' && !models.has(b.modelId)) problems.push(`${l.id}/${b.id}: unknown 3D model ${b.modelId}`);
      if (b.type === 'virtual_lab' && !labs.has(b.labId)) problems.push(`${l.id}/${b.id}: unknown lab ${b.labId}`);
      if (b.type === 'simulation') {
        const ok = b.source === 'phet' ? phet.has(b.simId) : b.source === 'animation' ? anims.has(b.simId) : sims.has(b.simId) || labs.has(b.simId);
        if (!ok) problems.push(`${l.id}/${b.id}: unknown ${b.source} sim ${b.simId}`);
      }
    }
  }
  for (const q of src.questions) {
    if (q.chapterId !== src.chapter.id) problems.push(`${q.id}: chapterId ${q.chapterId}`);
    if (q.topicId && !src.chapter.topics.some((t) => t.id === q.topicId)) problems.push(`${q.id}: unknown topic ${q.topicId}`);
    if (q.pyq) problems.push(`${q.id}: do not label PYQ years (unverified)`);
    if (new Set(q.options.map((o) => o.en.trim())).size !== 4) problems.push(`${q.id}: duplicate options`);
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
