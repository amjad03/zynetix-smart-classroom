import { describe, expect, it } from 'vitest';
import { Block, BLOCK_TYPES } from '@zynetix/lesson-schema';
import { BLOCK_FIELDS, clean, newBlock, parseJsonField } from './blocks';

describe('block editor model', () => {
  it('has a form for every block type', () => {
    expect(Object.keys(BLOCK_FIELDS).sort()).toEqual([...BLOCK_TYPES].sort());
  });
  it('new blocks become valid once their text is filled in', () => {
    for (const t of BLOCK_TYPES) {
      const b = newBlock(t, []) as any;
      for (const [k, v] of Object.entries(b)) if (v && typeof v === 'object' && 'en' in v) b[k] = { en: 'x' };
      if (t === 'example') b.steps = [{ en: 'x' }];
      if (t === 'recap') b.points = [{ en: 'x' }];
      if (b.questionIds) b.questionIds = ['q1'];
      expect(Block.safeParse(clean(b)).success, t).toBe(true);
    }
  });
  it('clean drops empty optional text and empty Kannada', () => {
    expect(clean({ id: 'a', type: 'trick', heading: { en: 'h', kn: '' }, body: { en: 'b' }, mnemonic: { en: '' }, seconds: '' })).toEqual({ id: 'a', type: 'trick', heading: { en: 'h' }, body: { en: 'b' } });
  });
  it('drops an empty boards list (meaning every board)', () => {
    expect(clean({ id: 'a', type: 'recap', points: [{ en: 'p' }], boards: [] })).toEqual({ id: 'a', type: 'recap', points: [{ en: 'p' }] });
    expect(Block.safeParse(clean({ id: 'a', type: 'recap', points: [{ en: 'p' }], boards: ['cbse'] })).success).toBe(true);
  });
  it('json fields parse on blur and report bad JSON', () => {
    expect(parseJsonField('[1, 2]')).toEqual({ value: [1, 2] });
    expect(parseJsonField('  ')).toEqual({ value: undefined });
    expect(parseJsonField('[1,').error).toMatch(/Not valid JSON/);
    for (const f of [...BLOCK_FIELDS.whiteboard, ...BLOCK_FIELDS.interactive]) if (f.kind === 'json') expect(parseJsonField(f.example!).error, f.key).toBeUndefined();
  });
  it('new block ids do not clash', () => {
    expect(newBlock('concept', ['concept1']).id).toBe('concept2');
  });
});
