/**
 * The expression language of whiteboard plots, interactives and scenes (mirrored exactly in
 * apps/board/lib/engine/expr.dart; both run the shared cases in expr-cases.json).
 *
 * - Numbers (1, 2.5, .5, 1e3), names (x, slider/toggle/choice/handle names, t, i, vars…),
 *   constants pi and e. Multiplication must be written (2*x, not 2x). Trig is in radians.
 * - Precedence, loosest first:
 *     ||   &&   comparisons (< > <= >= == !=)   + -   * /   unary - + !   ^ (right-assoc)
 *   so -x^2 = -(x^2), 2^3^2 = 512, an exponent may be signed (2^-1), and
 *   a + 1 < b * 2 && c compares the sums before combining. Comparisons and && || ! give 1 or 0
 *   (any non-zero number counts as true). Comparisons do not chain: 1 < x < 3 is an error;
 *   write 1 < x && x < 3.
 * - Functions of one argument: sin cos tan asin acos atan sqrt exp ln log abs floor ceil round
 *   sign rad deg rand. round(x) = floor(x + 0.5). rand(k) is a repeatable pseudo-random number in
 *   [0, 1) for each whole number k (rand(i) gives each particle its own value).
 * - More arguments: min(a, b, …) max(a, b, …) clamp(v, lo, hi) if(c, a, b) mod(a, b)
 *   pow(a, b) hypot(a, b) atan2(y, x) step(edge, v) smoothstep(e0, e1, v) bounce(v, lo, hi).
 *   if() evaluates only the branch it takes. mod is floored (mod(-1, 3) = 2). step is 0 below
 *   the edge and 1 from it on. bounce folds v back and forth between lo and hi like a ball
 *   between two walls.
 */
type Fn = (a: number[]) => number;
const one = (f: (v: number) => number): [number, number, Fn] => [1, 1, (a) => f(a[0])];
const fract = (v: number) => v - Math.floor(v);
/** Three rounds of an exact (in doubles: every product stays below 2^53) quadratic congruential
 *  step, so Dart and JS give the same bits, and rand(i) and rand(i + 1000) are not related. */
export function rand(k: number): number {
  if (!Number.isFinite(k)) return NaN;
  let n = Math.floor(k) % 233280;
  if (n < 0) n += 233280;
  for (let r = 0; r < 3; r++) n = (n * (n + 7919) + 49297) % 233280;
  return n / 233280;
}
export const FNS: Record<string, [number, number, Fn]> = {
  sin: one(Math.sin), cos: one(Math.cos), tan: one(Math.tan), asin: one(Math.asin), acos: one(Math.acos), atan: one(Math.atan),
  sqrt: one(Math.sqrt), exp: one(Math.exp), ln: one(Math.log), log: one(Math.log10), abs: one(Math.abs), floor: one(Math.floor),
  ceil: one(Math.ceil), round: one((v) => Math.floor(v + 0.5)), sign: one((v) => (v > 0 ? 1 : v < 0 ? -1 : v)),
  rad: one((v) => (v * Math.PI) / 180), deg: one((v) => (v * 180) / Math.PI), rand: one(rand),
  min: [2, 99, (a) => a.reduce((x, y) => (Number.isNaN(x) || Number.isNaN(y) ? NaN : Math.min(x, y)))],
  max: [2, 99, (a) => a.reduce((x, y) => (Number.isNaN(x) || Number.isNaN(y) ? NaN : Math.max(x, y)))],
  clamp: [3, 3, ([v, lo, hi]) => (Number.isNaN(v) || Number.isNaN(lo) || Number.isNaN(hi) ? NaN : Math.min(Math.max(v, lo), hi))],
  mod: [2, 2, ([a, b]) => a - b * Math.floor(a / b)],
  pow: [2, 2, ([a, b]) => Math.pow(a, b)],
  hypot: [2, 2, ([a, b]) => Math.sqrt(a * a + b * b)],
  atan2: [2, 2, ([y, x]) => Math.atan2(y, x)],
  step: [2, 2, ([edge, v]) => (Number.isNaN(edge) || Number.isNaN(v) ? NaN : v < edge ? 0 : 1)],
  smoothstep: [3, 3, ([e0, e1, v]) => { const k = Math.min(Math.max((v - e0) / (e1 - e0), 0), 1); return k * k * (3 - 2 * k); }],
  bounce: [3, 3, ([v, lo, hi]) => { const z = (v - lo) / (hi - lo); return lo + (hi - lo) * (1 - Math.abs(fract(z / 2) * 2 - 1)); }],
};
/** Names that are not variables: functions, constants, and `if`. */
export const BUILTINS = [...Object.keys(FNS), 'if', 'pi', 'e'];
export type Expr = (vars: Record<string, number>) => number;

const truth = (v: number) => (v !== 0 && !Number.isNaN(v) ? 1 : 0);

export function compile(src: string, names: string[]): Expr {
  const t = src.match(/\s*(\d+\.?\d*(?:e[+-]?\d+)?|\.\d+|[A-Za-z_]\w*|<=|>=|==|!=|&&|\|\||\S)/g)?.map((s) => s.trim()) ?? [];
  let i = 0;
  const peek = () => t[i], next = () => t[i++];
  const fail = (m: string): never => { throw new Error(`"${src}": ${m}`); };
  const or = (): Expr => {
    let l = and();
    while (peek() === '||') { next(); const a = l, b = and(); l = (v) => (truth(a(v)) || truth(b(v)) ? 1 : 0); }
    return l;
  };
  const and = (): Expr => {
    let l = cmp();
    while (peek() === '&&') { next(); const a = l, b = cmp(); l = (v) => (truth(a(v)) && truth(b(v)) ? 1 : 0); }
    return l;
  };
  const CMP = ['<', '>', '<=', '>=', '==', '!='];
  const cmp = (): Expr => {
    const a = expr();
    const op = peek();
    if (op === undefined || !CMP.includes(op)) return a;
    next();
    const b = expr();
    if (peek() !== undefined && CMP.includes(peek()!)) fail('comparisons do not chain: write a < b && b < c');
    switch (op) {
      case '<': return (v) => (a(v) < b(v) ? 1 : 0);
      case '>': return (v) => (a(v) > b(v) ? 1 : 0);
      case '<=': return (v) => (a(v) <= b(v) ? 1 : 0);
      case '>=': return (v) => (a(v) >= b(v) ? 1 : 0);
      case '==': return (v) => (a(v) === b(v) ? 1 : 0);
      default: return (v) => (a(v) !== b(v) ? 1 : 0);
    }
  };
  const expr = (): Expr => {
    let l = term();
    while (peek() === '+' || peek() === '-') { const op = next(), a = l, b = term(); l = op === '+' ? (v) => a(v) + b(v) : (v) => a(v) - b(v); }
    return l;
  };
  const term = (): Expr => {
    let l = unary();
    while (peek() === '*' || peek() === '/') { const op = next(), a = l, b = unary(); l = op === '*' ? (v) => a(v) * b(v) : (v) => a(v) / b(v); }
    return l;
  };
  // Unary minus binds looser than ^, so -x^2 = -(x^2); the exponent may itself be signed (2^-1).
  const unary = (): Expr => {
    if (peek() === '-') { next(); const a = unary(); return (v) => -a(v); }
    if (peek() === '+') { next(); return unary(); }
    if (peek() === '!') { next(); const a = unary(); return (v) => (truth(a(v)) ? 0 : 1); }
    return power();
  };
  const power = (): Expr => {
    const b = primary();
    if (peek() === '^') { next(); const e = unary(); return (v) => Math.pow(b(v), e(v)); }
    return b;
  };
  const args = (name: string): Expr[] => {
    if (next() !== '(') fail(`${name} needs (…)`);
    const out = [or()];
    while (peek() === ',') { next(); out.push(or()); }
    if (next() !== ')') fail('missing )');
    return out;
  };
  const primary = (): Expr => {
    const tok = next();
    if (tok === undefined) return fail('ends too early');
    if (tok === '(') { const e = or(); if (next() !== ')') fail('missing )'); return e; }
    if (/^[\d.]/.test(tok)) { const n = Number(tok); if (Number.isNaN(n)) fail(`bad number ${tok}`); return () => n; }
    if (/^[A-Za-z_]/.test(tok)) {
      if (tok === 'if') {
        const a = args(tok);
        if (a.length !== 3) fail('if needs 3 values: if(condition, then, else)');
        const [c, y, n] = a;
        return (v) => (truth(c(v)) ? y(v) : n(v));
      }
      if (tok in FNS) {
        const [lo, hi, f] = FNS[tok];
        const a = args(tok);
        if (a.length < lo || a.length > hi) fail(`${tok} takes ${lo === hi ? lo : `${lo} or more`} value${lo === 1 && hi === 1 ? '' : 's'}`);
        if (a.length === 1) { const a0 = a[0]; return (v) => f([a0(v)]); }
        return (v) => f(a.map((g) => g(v)));
      }
      if (tok === 'pi') return () => Math.PI;
      if (tok === 'e') return () => Math.E;
      if (!names.includes(tok)) fail(`unknown name "${tok}" (use x, slider names, or ${Object.keys(FNS).join(' ')})`);
      return (v) => v[tok];
    }
    return fail(`unexpected "${tok}"`);
  };
  const e = or();
  if (i < t.length) fail(`unexpected "${t[i]}"`);
  return e;
}
