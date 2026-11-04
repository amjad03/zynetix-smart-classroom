import { describe, expect, it } from 'vitest';
import { compile } from './expr';
import shared from './expr-cases.json';

it('evaluates the board expression language', () => {
  expect(compile('2*x^2 - 3*x + 1', ['x'])({ x: 2 })).toBe(3);
  expect(compile('A*sin(2*pi*x/L)', ['x', 'A', 'L'])({ x: 0.25, A: 3, L: 1 })).toBeCloseTo(3);
  expect(compile('-x^2', ['x'])({ x: 3 })).toBe(-9);
  expect(compile('2^3^2', [])({})).toBe(512);
  expect(compile('2^-1', [])({})).toBe(0.5);
  expect(() => compile('2x', ['x'])).toThrow();
  expect(() => compile('y+1', ['x'])).toThrow(/unknown name/);
});

// The same cases run in apps/board/test/expr_parity_test.dart, so both engines agree.
describe('shared cases (parity with the board)', () => {
  type Case = { src: string; vars?: Record<string, number>; value?: number | null; error?: string };
  for (const c of (shared as { cases: Case[] }).cases) {
    it(c.src + (c.vars ? ` ${JSON.stringify(c.vars)}` : ''), () => {
      const vars = c.vars ?? {};
      if (c.error !== undefined) {
        expect(() => compile(c.src, Object.keys(vars))).toThrow(c.error);
        return;
      }
      const v = compile(c.src, Object.keys(vars))(vars);
      if (c.value === null) expect(Number.isNaN(v)).toBe(true);
      else expect(v).toBeCloseTo(c.value!, 12);
    });
  }
  it('if() evaluates only the branch it takes', () => {
    let calls = 0;
    const f = compile('if(c, a, b)', ['c', 'a', 'b']);
    const vars = new Proxy({ c: 1, a: 2, b: 3 } as Record<string, number>, { get: (o, k: string) => { if (k === 'b') calls++; return o[k]; } });
    expect(f(vars)).toBe(2);
    expect(calls).toBe(0);
  });
});
