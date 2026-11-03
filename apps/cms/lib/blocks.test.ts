import { describe, expect, it } from 'vitest';
import { Block, BLOCK_TYPES } from '@zynetix/lesson-schema';
import { BLOCK_FIELDS, clean, newBlock } from './blocks';

describe('block editor model', () => {
  it('has a form for every block type', () => {
    expect(Object.keys(BLOCK_FIELDS).sort()).toEqual([...BLOCK_TYPES].sort());
  });
  it('new blocks become valid once their text is filled in', () => {
    for (const t of BLOCK_TYPES) {
      const b = newBlock(t, []) as any;
      for (const [k, v] of Object.entries(b)) if (v && typeof v === 'object' && 'en' in v) b[k] = { en: 'x' };
      if (b.steps) b.steps = [{ en: 'x' }];
      if (b.points) b.points = [{ en: 'x' }];
      if (b.questionIds) b.questionIds = ['q1'];
      expect(Block.safeParse(clean(b)).success, t).toBe(true);
    }
  });
  it('clean drops empty optional text and empty Kannada', () => {
    expect(clean({ id: 'a', type: 'trick', heading: { en: 'h', kn: '' }, body: { en: 'b' }, mnemonic: { en: '' }, seconds: '' })).toEqual({ id: 'a', type: 'trick', heading: { en: 'h' }, body: { en: 'b' } });
  });
  it('new block ids do not clash', () => {
    expect(newBlock('concept', ['concept1']).id).toBe('concept2');
  });
});
