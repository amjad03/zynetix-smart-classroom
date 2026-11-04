import { describe, expect, it } from 'vitest';
import { Block } from '@zynetix/lesson-schema';
import { checkActivity, checkChallenge, checkPlayfield } from './validate';
import { PlayModel } from './sim';

const L = (en: string) => ({ en });
type PF = Extract<Block, { type: 'interactive' | 'challenge' }>;
type Act = Extract<Block, { type: 'activity' }>;
const parse = <T,>(o: object) => {
  const r = Block.safeParse(o);
  if (!r.success) throw new Error(r.error.message);
  return r.data as T;
};

// A projectile launched by a button, drawn with a trail; stops when it lands.
const projectile = {
  id: 'sc1', type: 'interactive', kind: 'scene', caption: L('Launch it'),
  sliders: [
    { name: 'v', label: L('Speed'), min: 5, max: 25, step: 1, value: 15, unit: 'm/s' },
    { name: 'a', label: L('Angle'), min: 10, max: 80, step: 1, value: 45, unit: '°' },
  ],
  toggles: [{ name: 'vec', label: L('Show velocity'), value: true }],
  buttons: [{ label: L('Launch'), icon: 'launch', reset: true, play: true }],
  time: { max: 6, stopWhen: 'landed' },
  vars: [
    { name: 'px', expr: 'v*cos(rad(a))*t' },
    { name: 'py', expr: 'max(v*sin(rad(a))*t - 4.9*t^2, 0)' },
    { name: 'landed', expr: 't > 0 && v*sin(rad(a))*t - 4.9*t^2 <= 0' },
  ],
  view: { x: [0, 70], y: [0, 35], axes: true, grid: true },
  shapes: [
    { shape: 'trail', x: 'px', y: 'py', color: 'yellow' },
    { shape: 'circle', x: 'px', y: 'py', r: 0.8, color: 'orange' },
    { shape: 'arrow', visibleIf: 'vec', x: 'px', y: 'py', dx: 'v*cos(rad(a))/3', dy: '(v*sin(rad(a)) - 9.8*t)/3', label: 'v' },
    { shape: 'text', x: 60, y: 32, text: L('x = {px:1} m') },
  ],
};

describe('scene playfields', () => {
  it('accepts a launchable projectile', () => {
    expect(checkPlayfield(parse<PF>(projectile), 'w')).toEqual([]);
  });
  it('rejects an expression with an unknown name and a name that hides t or i', () => {
    expect(checkPlayfield(parse<PF>({ ...projectile, vars: [...projectile.vars, { name: 'z', expr: 'g*t' }] }), 'w').join()).toMatch(/var z.*unknown name "g"/);
    expect(checkPlayfield(parse<PF>({ ...projectile, sliders: [...projectile.sliders, { name: 't', label: L('t'), min: 0, max: 1, step: 0.1, value: 0 }] }), 'w').join()).toMatch(/"t" is the time/);
    const withI = { ...projectile, toggles: [{ name: 'i', label: L('i') }], shapes: [{ shape: 'particles', count: 5, x: 'i', y: 1, r: 0.2 }] };
    expect(checkPlayfield(parse<PF>(withI), 'w').join()).toMatch(/"i" is the particle index/);
  });
  it('runs every setting through time and rejects NaN in a drawn value', () => {
    // sqrt goes negative when the speed slider is at its minimum.
    const bad = { ...projectile, shapes: [{ shape: 'circle', x: 'px', y: 'sqrt(v - 6)', r: 1 }] };
    expect(checkPlayfield(parse<PF>(bad), 'w').join()).toMatch(/shape 1 \(circle\) y is not a number at t=0 with v=5/);
    // Hidden shapes are not checked.
    expect(checkPlayfield(parse<PF>({ ...bad, shapes: [{ ...bad.shapes[0], visibleIf: 'v > 6' }] }), 'w')).toEqual([]);
    // Infinity in a text value, part way through time.
    const inf = { ...projectile, shapes: [{ shape: 'text', x: 1, y: 1, text: L('{1/(t - 1)}') }], time: { max: 2, dt: 0.5 } };
    expect(checkPlayfield(parse<PF>(inf), 'w').join()).toMatch(/text is not a number at t=1/);
  });
  it('checks particles for each index, paths over their range, and buttons', () => {
    const gas = {
      id: 'g', type: 'interactive', kind: 'scene', caption: L('Gas'), sliders: [{ name: 'T', label: L('T'), min: 100, max: 600, step: 50, value: 300 }],
      time: { max: 10, loop: true, autoplay: true, dt: 0.05 },
      view: { x: [0, 10], y: [0, 10] },
      shapes: [{ shape: 'particles', count: 40, x: 'bounce(10*rand(i) + sqrt(T)/4*t*(rand(i+500)-0.5), 0, 10)', y: 'bounce(10*rand(i+99) + sqrt(T)/4*t*(rand(i+700)-0.5), 0, 10)', r: 0.15, color: { by: '(T-100)/500', scale: ['blue', 'red'] } }],
    };
    expect(checkPlayfield(parse<PF>(gas), 'w')).toEqual([]);
    expect(checkPlayfield(parse<PF>({ ...gas, shapes: [{ shape: 'particles', count: 3, x: 'log(i - 1)', y: 1, r: 0.1 }] }), 'w').join()).toMatch(/particle 0: x is not a number/);
    expect(checkPlayfield(parse<PF>({ ...gas, shapes: [{ shape: 'path', fn: 'sqrt(-1 - x^2)' }] }), 'w').join()).toMatch(/fn is not a number anywhere/);
    expect(checkPlayfield(parse<PF>({ ...gas, buttons: [{ label: L('Hot'), set: { Q: 600 } }] }), 'w').join()).toMatch(/sets "Q", which is not a slider/);
    expect(checkPlayfield(parse<PF>({ ...gas, kind: 'function_plot', fns: [{ fn: 'x', color: 'white' }], x: [0, 1], y: [0, 1] }), 'w').join()).toMatch(/shapes need kind scene/);
  });
  it('integrates state with RK2: a small-angle pendulum swings with T = 2π√(L/g)', () => {
    const pend = parse<PF>({
      id: 'p', type: 'interactive', kind: 'scene', caption: L('Pendulum'), sliders: [{ name: 'L', label: L('Length'), min: 0.5, max: 2, step: 0.1, value: 1 }],
      time: { max: 4.1, dt: 0.001 }, state: [{ name: 'th', init: 0.05, rate: 'w' }, { name: 'w', init: 0, rate: '-9.8/L*sin(th)' }],
      view: { x: [-1, 1], y: [-2.2, 0.2] }, shapes: [{ shape: 'line', x1: 0, y1: 0, x2: 'L*sin(th)', y2: '-L*cos(th)' }],
    });
    expect(checkPlayfield(pend, 'w')).toEqual([]);
    const m = new PlayModel(pend, 'w');
    const period = 2 * Math.PI * Math.sqrt(1 / 9.8);
    let k = 0, s = m.initState(m.defaults());
    for (; (k + 1) * m.dt <= period; k++) s = m.step(m.defaults(), k, s);
    expect(s.th).toBeCloseTo(0.05, 3);
    // Euler drifts (gains energy); RK2 stays put.
    const eu = new PlayModel({ ...pend, integrator: 'euler' }, 'w');
    expect(eu.run(eu.defaults()).th).not.toBeCloseTo(m.run(m.defaults()).th, 4);
  });
  it('a challenge with time takes the goal where the model stops', () => {
    const { caption: _, ...rest } = projectile;
    const ch = parse<Extract<Block, { type: 'challenge' }>>({
      ...rest, id: 'c1', type: 'challenge', prompt: L('Land on the flag at 40 m'),
      goal: 'px', goalLabel: L('Landing point'), goalUnit: 'm', target: 40, tolerance: 1.5, solution: { v: 20, a: 40 }, explanation: L('R = v² sin 2θ / g'),
    });
    expect([...checkPlayfield(ch, 'w'), ...checkChallenge(ch, 'w')]).toEqual([]);
    expect(checkChallenge({ ...ch, solution: { v: 25, a: 40 } }, 'w').join()).toMatch(/not solvable/);
    expect(checkChallenge({ ...ch, solution: { v: 20, a: 40, vec: 0.5 } }, 'w').join()).toMatch(/vec = 0.5 is not a value it can take/);
  });
});

describe('activities', () => {
  const base = { id: 'a1', type: 'activity', prompt: L('Do it') };
  const sort = { ...base, kind: 'sort', buckets: [{ id: 'a', label: L('Assets') }, { id: 'l', label: L('Liabilities') }], items: [{ text: L('Cash'), answer: 'a' }, { text: L('Creditors'), answer: 'l' }, { text: L('Stock'), answer: 'a' }] };
  it('accepts a good one of each kind', () => {
    const good = [
      sort,
      { ...base, kind: 'order', steps: [L('Prophase'), L('Metaphase'), L('Anaphase'), L('Telophase')] },
      { ...base, kind: 'match', pairs: [{ left: L('Order'), right: L('A place for everything') }, { left: L('Equity'), right: L('Kindness and justice') }] },
      { ...base, kind: 'label', view: { x: [0, 10], y: [0, 6] }, shapes: [{ shape: 'circle', x: 5, y: 3, r: 2.5, fill: false }], targets: [{ id: 'n', x: 5, y: 3, r: 0.8, label: L('Nucleus') }, { id: 'm', x: 2.5, y: 3, r: 0.5, label: L('Membrane') }] },
      { ...base, kind: 'hotspot', view: { x: [0, 10], y: [0, 6] }, targets: [{ id: 'n', x: 5, y: 3, r: 0.8, label: L('Nucleus') }, { id: 'm', x: 2.5, y: 3, w: 1, h: 1, label: L('Membrane') }], answer: ['n'] },
      { ...base, kind: 'fill', passage: L('The __1__ falls on the __2__.'), blanks: [{ options: [L('rain'), L('sun')], answer: 0 }, { options: [L('hills'), L('sky')], answer: 0 }] },
    ];
    for (const g of good) expect(checkActivity(parse<Act>(g), 'w'), g.kind).toEqual([]);
  });
  it('rejects unsolvable ones', () => {
    expect(checkActivity(parse<Act>({ ...sort, items: [...sort.items, { text: L('Land'), answer: 'x' }] }), 'w').join()).toMatch(/unknown bucket x/);
    expect(checkActivity(parse<Act>({ ...sort, items: [...sort.items, { text: L('cash '), answer: 'a' }] }), 'w').join()).toMatch(/two items are the same/);
    expect(checkActivity(parse<Act>({ ...sort, items: sort.items.filter((i) => i.answer === 'a') }), 'w').join()).toMatch(/bucket l gets no item/);
    expect(checkActivity(parse<Act>({ ...base, kind: 'order' }), 'w').join()).toMatch(/order needs steps/);
    expect(checkActivity(parse<Act>({ ...base, kind: 'hotspot', view: { x: [0, 10], y: [0, 6] }, targets: [{ id: 'n', x: 9.8, y: 3, r: 0.8, label: L('N') }, { id: 'm', x: 2, y: 2, r: 0.5, label: L('M') }], answer: ['n', 'm'] }), 'w').join()).toMatch(/not inside the view.*every target is right/);
    expect(checkActivity(parse<Act>({ ...base, kind: 'fill', passage: L('The __2__ falls.'), blanks: [{ options: [L('rain'), L('sun')], answer: 1 }] }), 'w').join()).toMatch(/blanks __1__/);
    expect(checkActivity(parse<Act>({ ...base, kind: 'fill', passage: L('The __1__ falls.'), blanks: [{ options: [L('rain'), L('Rain')], answer: 0 }] }), 'w').join()).toMatch(/options of blank 1/);
    expect(Block.safeParse({ ...base, kind: 'fill', passage: L('The __1__ falls.'), blanks: [{ options: [L('rain'), L('sun')], answer: 5 }] }).success).toBe(false);
  });
});
