/**
 * The expression language of whiteboard plots and interactives (mirrored in
 * apps/board/lib/engine/expr.dart): numbers, variables (x and slider names), + - * / ^,
 * unary minus, parentheses, functions sin cos tan asin acos atan sqrt exp ln log abs floor,
 * constants pi and e. Multiplication must be written (2*x, not 2x). Trig is in radians.
 */
const FNS: Record<string, (v: number) => number> = {
  sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
  sqrt: Math.sqrt, exp: Math.exp, ln: Math.log, log: Math.log10, abs: Math.abs, floor: Math.floor,
};
export type Expr = (vars: Record<string, number>) => number;

export function compile(src: string, names: string[]): Expr {
  const t = src.match(/\s*(\d+\.?\d*(?:e[+-]?\d+)?|\.\d+|[A-Za-z_]\w*|\S)/g)?.map((s) => s.trim()) ?? [];
  let i = 0;
  const peek = () => t[i], next = () => t[i++];
  const fail = (m: string): never => { throw new Error(`"${src}": ${m}`); };
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
    return power();
  };
  const power = (): Expr => {
    const b = primary();
    if (peek() === '^') { next(); const e = unary(); return (v) => Math.pow(b(v), e(v)); }
    return b;
  };
  const primary = (): Expr => {
    const tok = next();
    if (tok === undefined) return fail('ends too early');
    if (tok === '(') { const e = expr(); if (next() !== ')') fail('missing )'); return e; }
    if (/^[\d.]/.test(tok)) { const n = Number(tok); if (Number.isNaN(n)) fail(`bad number ${tok}`); return () => n; }
    if (/^[A-Za-z_]/.test(tok)) {
      if (tok in FNS) {
        if (next() !== '(') fail(`${tok} needs (…)`);
        const a = expr();
        if (next() !== ')') fail('missing )');
        const f = FNS[tok];
        return (v) => f(a(v));
      }
      if (tok === 'pi') return () => Math.PI;
      if (tok === 'e') return () => Math.E;
      if (!names.includes(tok)) fail(`unknown name "${tok}" (use x, slider names, or ${Object.keys(FNS).join(' ')})`);
      return (v) => v[tok];
    }
    return fail(`unexpected "${tok}"`);
  };
  const e = expr();
  if (i < t.length) fail(`unexpected "${t[i]}"`);
  return e;
}
