/**
 * The playfield model of interactives, challenges and scenes (mirrored in
 * apps/board/lib/blocks/scene/play_model.dart): controls → derived vars → integrated state over
 * time. The validator uses it to compile every expression with the right names and to run each
 * scene through its time range; the board runs the same steps, so a challenge solved here is
 * solved there.
 *
 * Each time step (fixed `dt`): vars are evaluated in order with the controls, `t` and the state;
 * the state moves by its rates (Euler: k1·dt; RK2 midpoint: k2·dt with k2 at t + dt/2), then t
 * becomes min + steps·dt. `stopWhen` is checked after each step.
 */
import type { Block } from '@zynetix/lesson-schema';
import { BUILTINS, compile, type Expr } from './expr';

export type Playfield = Extract<Block, { type: 'interactive' | 'challenge' }>;
type Vars = Record<string, number>;

export interface Control { name: string; kind: 'slider' | 'toggle' | 'choice' | 'counter' | 'handle'; value: number; min?: number; max?: number; values?: number[] }

/** Every control's name and starting value; a handle gives two (`P_x`, `P_y`). */
export function controlsOf(b: Pick<Playfield, 'sliders' | 'toggles' | 'choices' | 'counters' | 'handles'>): Control[] {
  return [
    ...b.sliders.map((s) => ({ name: s.name, kind: 'slider' as const, value: s.value, min: s.min, max: s.max })),
    ...(b.toggles ?? []).map((s) => ({ name: s.name, kind: 'toggle' as const, value: s.value ? 1 : 0, values: [0, 1] })),
    ...(b.choices ?? []).map((s) => ({ name: s.name, kind: 'choice' as const, value: s.value, values: s.options.map((o) => o.value) })),
    ...(b.counters ?? []).map((s) => ({ name: s.name, kind: 'counter' as const, value: s.value, min: s.min, max: s.max })),
    ...(b.handles ?? []).flatMap((h) => [
      { name: `${h.name}_x`, kind: 'handle' as const, value: h.x },
      { name: `${h.name}_y`, kind: 'handle' as const, value: h.y },
    ]),
  ];
}

/** A compiled playfield model. Problems (bad names, bad expressions) are collected, not thrown. */
export class PlayModel {
  readonly problems: string[] = [];
  readonly controls: Control[];
  readonly hasTime: boolean;
  readonly min: number;
  readonly max: number;
  readonly dt: number;
  readonly rk2: boolean;
  /** Controls, t, state and vars: the names every expression of the block may use. */
  readonly names: string[];
  private vars: { name: string; f: Expr }[] = [];
  private state: { name: string; init: Expr; rate: Expr }[] = [];
  private stop?: Expr;

  constructor(readonly b: Playfield, private readonly where: string) {
    this.controls = controlsOf(b);
    this.hasTime = !!b.time;
    this.min = b.time?.min ?? 0;
    this.max = b.time?.max ?? 0;
    this.dt = b.time?.dt ?? 0.01;
    this.rk2 = b.integrator !== 'euler';
    const control = this.controls.map((c) => c.name);
    const stateNames = (b.state ?? []).map((s) => s.name);
    const base = [...control, ...(this.hasTime ? ['t'] : []), ...stateNames];
    for (const v of b.vars ?? []) {
      const f = this.compile(v.expr, base, `var ${v.name}`);
      if (f) this.vars.push({ name: v.name, f });
      base.push(v.name);
    }
    this.names = base;
    if (b.state?.length && !this.hasTime) this.problems.push(`${where}: state needs time`);
    for (const s of b.state ?? []) {
      const init = typeof s.init === 'number' ? (() => s.init as number) : this.compile(s.init, control, `state ${s.name} init`);
      const rate = this.compile(s.rate, base, `state ${s.name} rate`);
      if (init && rate) this.state.push({ name: s.name, init, rate });
    }
    if (b.time?.stopWhen) this.stop = this.compile(b.time.stopWhen, base, 'time.stopWhen');
    this.checkNames(stateNames);
    if (b.time) {
      const t = b.time;
      if (!(t.max > t.min)) this.problems.push(`${where}: time.max must be above time.min`);
      else if ((t.max - t.min) / t.dt > 20000) this.problems.push(`${where}: time runs ${Math.round((t.max - t.min) / t.dt)} steps; keep it under 20000 (larger dt or shorter time)`);
      if (!t.speeds.includes(t.speed)) this.problems.push(`${where}: time.speed ${t.speed} is not one of time.speeds`);
    }
  }

  private checkNames(stateNames: string[]) {
    const all = [...this.controls.map((c) => c.name), ...stateNames, ...(this.b.vars ?? []).map((v) => v.name)];
    const seen = new Set<string>();
    for (const n of all) {
      if (seen.has(n)) this.problems.push(`${this.where}: two controls or variables are called "${n}"`);
      seen.add(n);
      if (BUILTINS.includes(n) || n === 'x') this.problems.push(`${this.where}: name "${n}" clashes with a built-in name`);
      if (n === 't' && this.hasTime) this.problems.push(`${this.where}: "t" is the time; rename that control`);
      if (n === 'i' && (this.b.shapes ?? []).some((s) => s.shape === 'particles')) this.problems.push(`${this.where}: "i" is the particle index; rename that control`);
    }
  }

  /** Compiles an expression, recording a problem instead of throwing. */
  compile(src: string, names: string[], what: string): Expr | undefined {
    try { return compile(src, names); } catch (e) { this.problems.push(`${this.where}: ${what}: ${(e as Error).message}`); return undefined; }
  }

  defaults(): Vars { return Object.fromEntries(this.controls.map((c) => [c.name, c.value])); }

  /** Controls + t + state + vars. */
  env(controls: Vars, t: number, state: Vars): Vars {
    const e: Vars = { ...controls, ...state };
    if (this.hasTime) e.t = t;
    for (const v of this.vars) e[v.name] = v.f(e);
    return e;
  }

  initState(controls: Vars): Vars { return Object.fromEntries(this.state.map((s) => [s.name, s.init(controls)])); }

  private rates(controls: Vars, t: number, s: Vars): Vars {
    const e = this.env(controls, t, s);
    return Object.fromEntries(this.state.map((x) => [x.name, x.rate(e)]));
  }

  /** One fixed step from `steps` steps after min. */
  step(controls: Vars, steps: number, s: Vars): Vars {
    if (!this.state.length) return s;
    const t = this.min + steps * this.dt, dt = this.dt;
    const k1 = this.rates(controls, t, s);
    if (!this.rk2) return Object.fromEntries(this.state.map((x) => [x.name, s[x.name] + k1[x.name] * dt]));
    const mid = Object.fromEntries(this.state.map((x) => [x.name, s[x.name] + (k1[x.name] * dt) / 2]));
    const k2 = this.rates(controls, t + dt / 2, mid);
    return Object.fromEntries(this.state.map((x) => [x.name, s[x.name] + k2[x.name] * dt]));
  }

  stopped(e: Vars): boolean { const v = this.stop?.(e); return v !== undefined && v !== 0 && !Number.isNaN(v); }

  /** Total steps from min to max. */
  get totalSteps(): number { return this.hasTime ? Math.round((this.max - this.min) / this.dt) : 0; }

  /**
   * Runs from the start with these controls until stopWhen or the end of time, calling `sample`
   * at about `samples` evenly spaced steps (and at the start and the end). Returns the final env.
   */
  run(controls: Vars, sample?: (env: Vars) => void, samples = 40): Vars {
    let s = this.initState(controls);
    let e = this.env(controls, this.min, s);
    sample?.(e);
    const n = this.totalSteps;
    const every = Math.max(1, Math.floor(n / samples));
    for (let k = 0; k < n; k++) {
      s = this.step(controls, k, s);
      e = this.env(controls, this.min + (k + 1) * this.dt, s);
      const stop = this.stopped(e);
      if (sample && ((k + 1) % every === 0 || stop || k + 1 === n)) sample(e);
      if (stop) break;
    }
    return e;
  }
}
