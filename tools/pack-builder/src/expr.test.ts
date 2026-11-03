import { expect, it } from 'vitest';
import { compile } from './expr';
it('evaluates the board expression language', () => {
  expect(compile('2*x^2 - 3*x + 1', ['x'])({ x: 2 })).toBe(3);
  expect(compile('A*sin(2*pi*x/L)', ['x', 'A', 'L'])({ x: 0.25, A: 3, L: 1 })).toBeCloseTo(3);
  expect(compile('-x^2', ['x'])({ x: 3 })).toBe(-9);
  expect(compile('2^3^2', [])({})).toBe(512);
  expect(compile('2^-1', [])({})).toBe(0.5);
  expect(() => compile('2x', ['x'])).toThrow();
  expect(() => compile('y+1', ['x'])).toThrow(/unknown name/);
});
