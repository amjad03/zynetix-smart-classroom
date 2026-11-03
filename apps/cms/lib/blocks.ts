/**
 * How the block editor draws each block type: a list of fields. Field kinds map to inputs;
 * the schema (packages/lesson-schema) is still the judge — the API validates every save.
 */
import type { BlockType } from '@zynetix/lesson-schema';

export type FieldKind = 'l10n' | 'l10nLong' | 'l10nList' | 'text' | 'number' | 'bool' | 'ids' | 'select';
export interface Field { key: string; label: string; kind: FieldKind; options?: string[] }

const common: Field[] = [
  { key: 'title', label: 'Title', kind: 'l10n' },
  { key: 'narration', label: 'Narration (read aloud in Self-Learning)', kind: 'l10nLong' },
  { key: 'seconds', label: 'Seconds on screen (Self-Learning)', kind: 'number' },
  { key: 'optional', label: 'Optional (dropped first in a short period)', kind: 'bool' },
  { key: 'boards', label: 'Only for boards (kar_pu, cbse); empty = all', kind: 'ids' },
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
