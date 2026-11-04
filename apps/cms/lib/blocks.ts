/**
 * How the block editor draws each block type: a list of fields. Field kinds map to inputs;
 * the schema (packages/lesson-schema) is still the judge — the API validates every save.
 */
import type { BlockType } from '@zynetix/lesson-schema';

export type FieldKind = 'l10n' | 'l10nLong' | 'l10nList' | 'text' | 'number' | 'bool' | 'ids' | 'select' | 'json' | 'range';
/** `json`: a JSON textarea, parsed on blur (`example` is shown as the placeholder). `range`: [min, max]. */
export interface Field { key: string; label: string; kind: FieldKind; options?: string[]; example?: string }

/** Parses a `json` field's text; empty text means "not set". Returns an error message instead of throwing. */
export function parseJsonField(text: string): { value?: unknown; error?: string } {
  if (!text.trim()) return { value: undefined };
  try {
    return { value: JSON.parse(text) };
  } catch (e) {
    return { error: `Not valid JSON: ${(e as Error).message}` };
  }
}

const KINDS = ['function_plot', 'vectors', 'bar_chart', 'pie_chart', 'unit_circle', 'number_line', 'readouts', 'scene'];
/** Controls, time, model and scene fields shared by `interactive` and `challenge` (docs/simulations.md). */
const playfieldExtras: Field[] = [
  { key: 'toggles', label: 'Toggles: on/off switches, 1 or 0 in expressions (JSON)', kind: 'json', example: '[{"name":"friction","label":{"en":"Friction on"},"value":false}]' },
  { key: 'choices', label: 'Choices: segmented selector giving a number (JSON)', kind: 'json', example: '[{"name":"n","label":{"en":"Medium"},"options":[{"label":{"en":"Air"},"value":1},{"label":{"en":"Water"},"value":1.33}],"value":1}]' },
  { key: 'counters', label: 'Counters: numbers that buttons change (JSON)', kind: 'json', example: '[{"name":"gen","value":0,"min":0,"max":10}]' },
  { key: 'buttons', label: 'Buttons: set variables, reset or play time (JSON)', kind: 'json', example: '[{"label":{"en":"Next generation"},"icon":"next","set":{"gen":"gen + 1"}}]' },
  { key: 'handles', label: 'Draggable points on a scene; give vars NAME_x and NAME_y (JSON)', kind: 'json', example: '[{"name":"P","label":"object","x":-6,"y":1,"axis":"x","box":{"x":[-9,-1],"y":[0,3]},"color":"yellow"}]' },
  { key: 'time', label: 'Time t: {min, max, loop, speeds, speed, autoplay, stopWhen, dt} (JSON)', kind: 'json', example: '{"max":5,"autoplay":false,"stopWhen":"y < 0"}' },
  { key: 'vars', label: 'Derived variables, in order: [{name, expr}] (JSON)', kind: 'json', example: '[{"name":"x","expr":"v*cos(rad(a))*t"},{"name":"y","expr":"v*sin(rad(a))*t - 4.9*t^2"}]' },
  { key: 'state', label: 'Integrated variables: [{name, init, rate (d/dt)}] (JSON; needs time)', kind: 'json', example: '[{"name":"th","init":"th0","rate":"w"},{"name":"w","init":0,"rate":"-g/L*sin(th)"}]' },
  { key: 'integrator', label: 'Integrator', kind: 'select', options: ['rk2', 'euler'] },
  { key: 'view', label: 'Scene view {x, y, axes, grid, xLabel, yLabel, equal} (JSON)', kind: 'json', example: '{"x":[0,40],"y":[0,20],"axes":true,"grid":true}' },
  { key: 'shapes', label: 'Scene shapes (JSON): circle, rect, line, arrow, path, polygon, wave, text, label, spring, trail, particles, icon', kind: 'json', example: '[{"shape":"circle","x":"x","y":"y","r":0.6,"color":"yellow"},{"shape":"trail","x":"x","y":"y"}]' },
];

const common: Field[] = [
  { key: 'title', label: 'Title', kind: 'l10n' },
  { key: 'narration', label: 'Narration (read aloud in Self-Learning)', kind: 'l10nLong' },
  { key: 'seconds', label: 'Seconds on screen (Self-Learning)', kind: 'number' },
  { key: 'optional', label: 'Optional (dropped first in a short period)', kind: 'bool' },
  { key: 'boards', label: 'Only for boards (kar_pu, cbse, isc); empty = all', kind: 'ids' },
];

export const BLOCK_FIELDS: Record<BlockType, Field[]> = {
  intro: [{ key: 'heading', label: 'Heading', kind: 'l10n' }, { key: 'hook', label: 'Hook', kind: 'l10nLong' }, { key: 'objectives', label: 'Objectives', kind: 'l10nList' }],
  concept: [{ key: 'body', label: 'Body ($…$ for LaTeX)', kind: 'l10nLong' }, { key: 'formula', label: 'Display formula (LaTeX)', kind: 'text' }, { key: 'points', label: 'Key points', kind: 'l10nList' }],
  '3d_model': [{ key: 'modelId', label: 'Kinetix 3D model id (heart, molecules, atoms…)', kind: 'text' }, { key: 'variant', label: 'Variant (h2o, nacl…)', kind: 'text' }, { key: 'caption', label: 'Caption', kind: 'l10nLong' }],
  simulation: [
    { key: 'source', label: 'Source', kind: 'select', options: ['phet', 'animation', 'kinetix_sim', 'kinetix_cs'] },
    { key: 'simId', label: 'Sim id (PhET file in media/phet, animation id, lab.graph-plotter…, or algo.bubble / sim.logic / code.sql for kinetix_cs)', kind: 'text' },
    { key: 'preset', label: 'Preset', kind: 'text' },
    { key: 'caption', label: 'Caption', kind: 'l10nLong' },
    { key: 'tryThis', label: 'Try this', kind: 'l10nList' },
  ],
  virtual_lab: [{ key: 'labId', label: 'Kinetix lab id (titration-oxalic-naoh, inclined-plane…)', kind: 'text' }, { key: 'preset', label: 'Preset', kind: 'text' }, { key: 'aim', label: 'Aim', kind: 'l10nLong' }],
  example: [{ key: 'problem', label: 'Problem', kind: 'l10nLong' }, { key: 'steps', label: 'Steps (revealed one by one)', kind: 'l10nList' }, { key: 'answer', label: 'Answer', kind: 'l10n' }],
  class_quiz: [
    { key: 'questionIds', label: 'Question ids (comma separated)', kind: 'ids' },
    { key: 'mode', label: 'How the class answers', kind: 'select', options: ['monitor', 'roll_call', 'team'] },
    { key: 'secondsPerQuestion', label: 'Seconds per question', kind: 'number' },
  ],
  pyq: [{ key: 'questionIds', label: 'Question ids', kind: 'ids' }, { key: 'exams', label: 'Exams shown (PUC, KCET…)', kind: 'ids' }],
  trick: [{ key: 'heading', label: 'Heading', kind: 'l10n' }, { key: 'body', label: 'Trick', kind: 'l10nLong' }, { key: 'mnemonic', label: 'Mnemonic', kind: 'l10n' }],
  recap: [{ key: 'points', label: 'Recap points', kind: 'l10nList' }, { key: 'homework', label: 'Homework', kind: 'l10nList' }, { key: 'homeworkQuestionIds', label: 'Homework question ids', kind: 'ids' }],
  whiteboard: [
    {
      key: 'steps',
      label: 'Board steps (JSON): each {say?, draw: [...], clear?}; draw kinds text, math, line, arrow, rect, circle, path, axes, plot on a 100 × 60 grid',
      kind: 'json',
      example: '[{"say":{"en":"Draw the axes"},"draw":[{"kind":"axes","from":[10,5],"to":[90,55],"x":[-3,3],"y":[-1,9],"xLabel":"x","yLabel":"y"},{"kind":"plot","fn":"x^2","color":"yellow"}]}]',
    },
  ],
  interactive: [
    { key: 'kind', label: 'Kind', kind: 'select', options: KINDS },
    { key: 'caption', label: 'Caption', kind: 'l10nLong' },
    { key: 'sliders', label: 'Sliders (JSON, up to 4)', kind: 'json', example: '[{"name":"a","label":{"en":"a"},"min":-3,"max":3,"step":0.1,"value":1}]' },
    { key: 'fns', label: 'Functions y = f(x, sliders) (JSON, function_plot)', kind: 'json', example: '[{"fn":"a*x^2","label":"y = ax²","color":"yellow"}]' },
    { key: 'x', label: 'x range', kind: 'range' },
    { key: 'y', label: 'y range', kind: 'range' },
    { key: 'xLabel', label: 'x-axis label', kind: 'text' },
    { key: 'yLabel', label: 'y-axis label', kind: 'text' },
    { key: 'readouts', label: 'Read-outs (JSON)', kind: 'json', example: '[{"label":{"en":"Area"},"expr":"a*b","unit":"m²","digits":2}]' },
    { key: 'vectors', label: 'Vectors [[x, y]…] (JSON; entries may be slider names)', kind: 'json', example: '[[3,"b"],[-1,2]]' },
    { key: 'data', label: 'Chart data {label: value or slider name} (JSON)', kind: 'json', example: '{"Rent":"r","Food":40}' },
    { key: 'points', label: 'Number-line points (JSON; values or slider names)', kind: 'json', example: '[-2,"a",3.5]' },
    ...playfieldExtras,
    { key: 'tryThis', label: 'Try this', kind: 'l10nList' },
  ],
  challenge: [
    { key: 'kind', label: 'Kind', kind: 'select', options: KINDS },
    { key: 'sliders', label: 'Sliders (JSON, up to 4)', kind: 'json', example: '[{"name":"a","label":{"en":"a"},"min":-3,"max":3,"step":0.1,"value":1}]' },
    { key: 'fns', label: 'Functions y = f(x, sliders) (JSON, function_plot)', kind: 'json', example: '[{"fn":"a*x^2","label":"y = ax²","color":"yellow"}]' },
    { key: 'x', label: 'x range', kind: 'range' },
    { key: 'y', label: 'y range', kind: 'range' },
    { key: 'xLabel', label: 'x-axis label', kind: 'text' },
    { key: 'yLabel', label: 'y-axis label', kind: 'text' },
    { key: 'readouts', label: 'Read-outs (JSON)', kind: 'json', example: '[{"label":{"en":"Area"},"expr":"a*b","unit":"m²","digits":2}]' },
    { key: 'vectors', label: 'Vectors [[x, y]…] (JSON; entries may be slider names)', kind: 'json', example: '[[3,"b"],[-1,2]]' },
    { key: 'data', label: 'Chart data {label: value or slider name} (JSON)', kind: 'json', example: '{"Rent":"r","Food":40}' },
    { key: 'points', label: 'Number-line points (JSON; values or slider names)', kind: 'json', example: '[-2,"a",3.5]' },
    ...playfieldExtras,
    { key: 'prompt', label: 'Mission (what the class must do)', kind: 'l10nLong' },
    { key: 'goal', label: 'Goal expression (controls, vars; with time, taken where the model stops)', kind: 'text' },
    { key: 'goalLabel', label: 'Goal label', kind: 'l10n' },
    { key: 'goalUnit', label: 'Goal unit', kind: 'text' },
    { key: 'target', label: 'Target value', kind: 'number' },
    { key: 'tolerance', label: 'Tolerance (±)', kind: 'number' },
    { key: 'solution', label: 'Solution control values (JSON; every slider; must hit the target)', kind: 'json', example: '{"a":5}' },
    { key: 'attempts', label: 'Tries (default 3)', kind: 'number' },
    { key: 'timeLimit', label: 'Seconds per try (optional)', kind: 'number' },
    { key: 'mode', label: 'Who plays', kind: 'select', options: ['team', 'roll_call', 'monitor'] },
    { key: 'hint', label: 'Hint after a miss', kind: 'l10n' },
    { key: 'explanation', label: 'Explanation (shown at the end)', kind: 'l10nLong' },
  ],
  activity: [
    { key: 'kind', label: 'Kind', kind: 'select', options: ['sort', 'order', 'match', 'label', 'hotspot', 'fill'] },
    { key: 'prompt', label: 'What to do (read aloud)', kind: 'l10nLong' },
    { key: 'buckets', label: 'sort: 2–4 buckets [{id, label}] (JSON)', kind: 'json', example: '[{"id":"asset","label":{"en":"Assets"}},{"id":"liab","label":{"en":"Liabilities"}}]' },
    { key: 'items', label: 'sort: items [{text, answer: bucket id}] (JSON)', kind: 'json', example: '[{"text":{"en":"Cash"},"answer":"asset"},{"text":{"en":"Creditors"},"answer":"liab"}]' },
    { key: 'steps', label: 'order: the steps in the RIGHT order (shown shuffled)', kind: 'l10nList' },
    { key: 'pairs', label: 'match: pairs [{left, right}] (JSON)', kind: 'json', example: '[{"left":{"en":"Unity of command"},"right":{"en":"One boss for each worker"}},{"left":{"en":"Order"},"right":{"en":"A place for everything"}}]' },
    { key: 'view', label: 'label/hotspot: diagram view {x, y} (JSON)', kind: 'json', example: '{"x":[0,10],"y":[0,6]}' },
    { key: 'shapes', label: 'label/hotspot: diagram shapes (JSON, constants only)', kind: 'json', example: '[{"shape":"circle","x":5,"y":3,"r":2,"fill":false}]' },
    { key: 'targets', label: 'label/hotspot: targets [{id, x, y, r (or w, h), label}] (JSON)', kind: 'json', example: '[{"id":"n","x":5,"y":3,"r":0.8,"label":{"en":"Nucleus"}},{"id":"m","x":2,"y":2,"r":0.6,"label":{"en":"Membrane"}}]' },
    { key: 'distractors', label: 'label: extra wrong labels', kind: 'l10nList' },
    { key: 'answer', label: 'hotspot: the right target ids', kind: 'ids' },
    { key: 'passage', label: 'fill: passage with blanks __1__, __2__ …', kind: 'l10nLong' },
    { key: 'blanks', label: 'fill: blanks [{options, answer (index)}] (JSON)', kind: 'json', example: '[{"options":[{"en":"rain"},{"en":"sun"}],"answer":0}]' },
    { key: 'questionId', label: 'Record the first Check as this answer id (optional)', kind: 'text' },
    { key: 'explanation', label: 'Explanation (after Check / Show answer)', kind: 'l10nLong' },
  ],
};

export const fieldsFor = (t: BlockType) => [...BLOCK_FIELDS[t], ...common];

const L = (en = '') => ({ en });
/** A new block with the required fields filled, so a save validates as soon as text is typed. */
export function newBlock(type: BlockType, existing: string[]): Record<string, unknown> {
  let n = 1;
  while (existing.includes(`${type.replace('_', '')}${n}`)) n++;
  const id = `${type.replace('_', '')}${n}`;
  const t: Record<BlockType, Record<string, unknown>> = {
    intro: { heading: L(), hook: L() },
    concept: { body: L() },
    '3d_model': { modelId: 'molecules', caption: L() },
    simulation: { source: 'kinetix_sim', simId: 'lab.graph-plotter', caption: L() },
    virtual_lab: { labId: 'ohms-law', aim: L() },
    example: { problem: L(), steps: [L()], answer: L() },
    class_quiz: { questionIds: [], mode: 'monitor' },
    pyq: { questionIds: [] },
    trick: { heading: L(), body: L() },
    recap: { points: [L()] },
    whiteboard: { steps: [{ draw: [{ kind: 'text', at: [10, 10], text: L('Title') }] }] },
    interactive: { kind: 'function_plot', caption: L(), sliders: [{ name: 'a', label: L('a'), min: -3, max: 3, step: 0.1, value: 1 }], fns: [{ fn: 'a*x^2', color: 'yellow' }], x: [-5, 5], y: [-5, 5] },
    activity: { kind: 'order', prompt: L(), steps: [L('First'), L('Second'), L('Third')] },
    challenge: { kind: 'function_plot', prompt: L(), sliders: [{ name: 'a', label: L('a'), min: 0, max: 10, step: 1, value: 1 }], fns: [{ fn: 'a*x', color: 'yellow' }], x: [0, 10], y: [0, 100], goal: 'a*a', goalLabel: L('a²'), target: 25, tolerance: 0.5, solution: { a: 5 }, explanation: L() },
  };
  return { id, type, ...t[type] };
}

/** Drops empty optional values so the strict schema accepts the block. */
export function clean(b: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(b)) {
    if (v === '' || v === undefined || v === null) continue;
    if (k === 'boards' && Array.isArray(v) && v.length === 0) continue; // empty = every board
    if (typeof v === 'object' && !Array.isArray(v) && 'en' in (v as object)) {
      const l = v as { en: string; kn?: string };
      if (!l.en && !l.kn && !['heading', 'hook', 'body', 'caption', 'aim', 'problem', 'answer'].includes(k)) continue;
      out[k] = l.kn ? { en: l.en, kn: l.kn } : { en: l.en };
      continue;
    }
    out[k] = v;
  }
  return out;
}
