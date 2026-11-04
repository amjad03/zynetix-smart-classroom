import { describe, expect, it } from 'vitest';
import { Block } from '@zynetix/lesson-schema';
import { checkChallenge, checkPlayfield } from './validate';

const L = (en: string) => ({ en });
// Land a projectile on x = 40 m: range = v² sin 2θ / g.
const projectile = {
  id: 'ch1', type: 'challenge', kind: 'function_plot', prompt: L('Land it on x = 40 m'),
  sliders: [
    { name: 'v', label: L('speed'), min: 10, max: 30, step: 1, value: 15, unit: 'm/s' },
    { name: 'a', label: L('angle'), min: 10, max: 80, step: 1, value: 30, unit: '°' },
  ],
  fns: [{ fn: 'x*tan(a*pi/180) - 9.8*x^2/(2*v^2*cos(a*pi/180)^2)', color: 'yellow' }], x: [0, 60], y: [0, 30],
  goal: 'v^2*sin(2*a*pi/180)/9.8', goalLabel: L('Landing point'), goalUnit: 'm', target: 40, tolerance: 1,
  solution: { v: 20, a: 40 }, explanation: L('R = v² sin 2θ / g'),
};
const parse = (o: object) => Block.parse(o) as Extract<Block, { type: 'challenge' }>;

describe('challenge blocks', () => {
  it('accepts a solvable challenge', () => {
    const b = parse(projectile);
    expect(b.attempts).toBe(3);
    expect(b.mode).toBe('team');
    expect([...checkPlayfield(b, 'w'), ...checkChallenge(b, 'w')]).toEqual([]);
  });
  it('rejects a solution that misses the target', () => {
    expect(checkChallenge(parse({ ...projectile, solution: { v: 20, a: 60 } }), 'w').join()).toMatch(/not solvable/);
  });
  it('rejects a solution the sliders cannot reach', () => {
    expect(checkChallenge(parse({ ...projectile, solution: { v: 20.5, a: 40 } }), 'w').join()).toMatch(/not on the slider's step/);
    expect(checkChallenge(parse({ ...projectile, solution: { v: 40, a: 40 } }), 'w').join()).toMatch(/outside/);
    expect(checkChallenge(parse({ ...projectile, solution: { v: 20 } }), 'w').join()).toMatch(/no value for slider a/);
  });
  it('rejects a bad goal, a start that already wins, and a readout that gives it away', () => {
    expect(checkChallenge(parse({ ...projectile, goal: 'v*g' }), 'w').join()).toMatch(/unknown name "g"/);
    expect(checkChallenge(parse({ ...projectile, sliders: [{ ...projectile.sliders[0], value: 20 }, { ...projectile.sliders[1], value: 40 }] }), 'w').join()).toMatch(/already hit/);
    expect(checkChallenge(parse({ ...projectile, readouts: [{ label: L('R'), expr: 'v^2 * sin(2*a*pi/180) / 9.8' }] }), 'w').join()).toMatch(/readout shows the goal/);
  });
  it('needs at least one slider', () => {
    expect(Block.safeParse({ ...projectile, sliders: [] }).success).toBe(false);
  });
});
