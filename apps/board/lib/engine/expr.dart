import 'dart:math' as math;

/// The expression language of whiteboard plots, interactives and scenes, ported exactly from
/// tools/pack-builder/src/expr.ts (the reference). Both run the shared cases in
/// tools/pack-builder/src/expr-cases.json (test/expr_parity_test.dart).
///
/// - Numbers, names (x, slider/toggle/choice/handle names, t, i, vars…), constants pi and e.
///   Multiplication must be written (2*x, not 2x). Trig is in radians.
/// - Precedence, loosest first:
///     ||   &&   comparisons (< > <= >= == !=)   + -   * /   unary - + !   ^ (right-assoc)
///   so -x^2 = -(x^2), 2^3^2 = 512 and an exponent may be signed (2^-1). Comparisons and
///   && || ! give 1 or 0 (any non-zero number is true; NaN is false). Comparisons do not chain.
/// - One argument: sin cos tan asin acos atan sqrt exp ln log abs floor ceil round sign rad deg
///   rand. round(x) = floor(x + 0.5); rand(k) is a repeatable pseudo-random number in [0, 1).
/// - More: min max (2 or more) clamp(v, lo, hi) if(c, a, b) (lazy) mod(a, b) (floored)
///   pow hypot atan2(y, x) step(edge, v) smoothstep(e0, e1, v) bounce(v, lo, hi).
typedef Expr = double Function(Map<String, double> vars);

class ExprError implements Exception {
  ExprError(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef _Fn = ({int lo, int hi, double Function(List<double>) f, double Function(double)? u});
_Fn _one(double Function(double) f) => (lo: 1, hi: 1, f: (a) => f(a[0]), u: f);
_Fn _many(int lo, int hi, double Function(List<double>) f) => (lo: lo, hi: hi, f: f, u: null);

double _log10(double v) => math.log(v) / math.ln10;
double _floor(double v) => v.isFinite ? v.floorToDouble() : v;
double _ceil(double v) => v.isFinite ? v.ceilToDouble() : v;
double _fract(double v) => v - _floor(v);

/// Same bits as the reference: three rounds of an exact quadratic congruential step.
double exprRand(double k) {
  if (!k.isFinite) return double.nan;
  var n = k.floorToDouble().remainder(233280);
  if (n < 0) n += 233280;
  for (var r = 0; r < 3; r++) {
    n = (n * (n + 7919) + 49297).remainder(233280);
  }
  return n / 233280;
}

double _minMax(List<double> a, bool isMin) {
  var out = a.first;
  for (final v in a.skip(1)) {
    if (out.isNaN || v.isNaN) return double.nan;
    out = isMin ? math.min(out, v) : math.max(out, v);
  }
  return out;
}

final Map<String, _Fn> _fns = {
  'sin': _one(math.sin),
  'cos': _one(math.cos),
  'tan': _one(math.tan),
  'asin': _one(math.asin),
  'acos': _one(math.acos),
  'atan': _one(math.atan),
  'sqrt': _one(math.sqrt),
  'exp': _one(math.exp),
  'ln': _one(math.log),
  'log': _one(_log10),
  'abs': _one((v) => v.abs()),
  'floor': _one(_floor),
  'ceil': _one(_ceil),
  'round': _one((v) => _floor(v + 0.5)),
  'sign': _one((v) => v > 0 ? 1 : (v < 0 ? -1 : v)),
  'rad': _one((v) => v * math.pi / 180),
  'deg': _one((v) => v * 180 / math.pi),
  'rand': _one(exprRand),
  'min': _many(2, 99, (a) => _minMax(a, true)),
  'max': _many(2, 99, (a) => _minMax(a, false)),
  'clamp': _many(3, 3, (a) => a[0].isNaN || a[1].isNaN || a[2].isNaN ? double.nan : math.min(math.max(a[0], a[1]), a[2])),
  'mod': _many(2, 2, (a) => a[0] - a[1] * _floor(a[0] / a[1])),
  'pow': _many(2, 2, (a) => math.pow(a[0], a[1]).toDouble()),
  'hypot': _many(2, 2, (a) => math.sqrt(a[0] * a[0] + a[1] * a[1])),
  'atan2': _many(2, 2, (a) => math.atan2(a[0], a[1])),
  'step': _many(2, 2, (a) => a[0].isNaN || a[1].isNaN ? double.nan : (a[1] < a[0] ? 0 : 1)),
  'smoothstep': _many(3, 3, (a) {
    final k = math.min(math.max((a[2] - a[0]) / (a[1] - a[0]), 0.0), 1.0);
    return k * k * (3 - 2 * k);
  }),
  'bounce': _many(3, 3, (a) {
    final z = (a[0] - a[1]) / (a[2] - a[1]);
    return a[1] + (a[2] - a[1]) * (1 - (_fract(z / 2) * 2 - 1).abs());
  }),
};

/// Names that are not variables: functions, constants, and `if`.
final List<String> exprBuiltins = [..._fns.keys, 'if', 'pi', 'e'];

double _truth(double v) => v != 0 && !v.isNaN ? 1 : 0;

final _token = RegExp(r'\s*(\d+\.?\d*(?:e[+-]?\d+)?|\.\d+|[A-Za-z_]\w*|<=|>=|==|!=|&&|\|\||\S)');
final _digitOrDot = RegExp(r'^[\d.]');
final _ident = RegExp(r'^[A-Za-z_]');
const _cmp = ['<', '>', '<=', '>=', '==', '!='];

/// Compiles [src]; [names] are the variables it may use. Throws [ExprError] like the reference.
Expr compileExpr(String src, List<String> names) => _Parser(src, names).parse();

/// Compiles and returns null instead of throwing (a bad expression in a pack never stops a lesson).
Expr? tryCompileExpr(String src, List<String> names) {
  try {
    return compileExpr(src, names);
  } on ExprError {
    return null;
  }
}

class _Parser {
  _Parser(this.src, this.names) : t = [for (final m in _token.allMatches(src)) m.group(0)!.trim()];
  final String src;
  final List<String> names;
  final List<String> t;
  int i = 0;

  String? peek() => i < t.length ? t[i] : null;
  String? next() {
    final tok = peek();
    i++;
    return tok;
  }

  Never fail(String m) => throw ExprError('"$src": $m');

  Expr parse() {
    final e = or();
    if (i < t.length) fail('unexpected "${t[i]}"');
    return e;
  }

  Expr or() {
    var l = and();
    while (peek() == '||') {
      next();
      final a = l, b = and();
      l = (v) => _truth(a(v)) == 1 || _truth(b(v)) == 1 ? 1 : 0;
    }
    return l;
  }

  Expr and() {
    var l = cmp();
    while (peek() == '&&') {
      next();
      final a = l, b = cmp();
      l = (v) => _truth(a(v)) == 1 && _truth(b(v)) == 1 ? 1 : 0;
    }
    return l;
  }

  Expr cmp() {
    final a = expr();
    final op = peek();
    if (op == null || !_cmp.contains(op)) return a;
    next();
    final b = expr();
    if (peek() != null && _cmp.contains(peek())) fail('comparisons do not chain: write a < b && b < c');
    return switch (op) {
      '<' => (v) => a(v) < b(v) ? 1 : 0,
      '>' => (v) => a(v) > b(v) ? 1 : 0,
      '<=' => (v) => a(v) <= b(v) ? 1 : 0,
      '>=' => (v) => a(v) >= b(v) ? 1 : 0,
      '==' => (v) => a(v) == b(v) ? 1 : 0,
      _ => (v) => a(v) != b(v) ? 1 : 0,
    };
  }

  Expr expr() {
    var l = term();
    while (peek() == '+' || peek() == '-') {
      final op = next(), a = l, b = term();
      l = op == '+' ? (v) => a(v) + b(v) : (v) => a(v) - b(v);
    }
    return l;
  }

  Expr term() {
    var l = unary();
    while (peek() == '*' || peek() == '/') {
      final op = next(), a = l, b = unary();
      l = op == '*' ? (v) => a(v) * b(v) : (v) => a(v) / b(v);
    }
    return l;
  }

  // Unary minus binds looser than ^, so -x^2 = -(x^2); the exponent may itself be signed (2^-1).
  Expr unary() {
    if (peek() == '-') {
      next();
      final a = unary();
      return (v) => -a(v);
    }
    if (peek() == '+') {
      next();
      return unary();
    }
    if (peek() == '!') {
      next();
      final a = unary();
      return (v) => _truth(a(v)) == 1 ? 0 : 1;
    }
    return power();
  }

  Expr power() {
    final b = primary();
    if (peek() == '^') {
      next();
      final e = unary();
      return (v) => math.pow(b(v), e(v)).toDouble();
    }
    return b;
  }

  List<Expr> args(String name) {
    if (next() != '(') fail('$name needs (…)');
    final out = [or()];
    while (peek() == ',') {
      next();
      out.add(or());
    }
    if (next() != ')') fail('missing )');
    return out;
  }

  Expr primary() {
    final tok = next();
    if (tok == null) fail('ends too early');
    if (tok == '(') {
      final e = or();
      if (next() != ')') fail('missing )');
      return e;
    }
    if (_digitOrDot.hasMatch(tok)) {
      // JS Number() accepts "1." and "1.e5"; Dart's parser wants a digit after the point.
      final n = double.tryParse(tok.replaceFirst(RegExp(r'\.(?=e|$)'), '.0'));
      if (n == null) fail('bad number $tok');
      return (_) => n;
    }
    if (_ident.hasMatch(tok)) {
      if (tok == 'if') {
        final a = args(tok);
        if (a.length != 3) fail('if needs 3 values: if(condition, then, else)');
        final c = a[0], y = a[1], n = a[2];
        return (v) => _truth(c(v)) == 1 ? y(v) : n(v);
      }
      final f = _fns[tok];
      if (f != null) {
        final a = args(tok);
        if (a.length < f.lo || a.length > f.hi) {
          fail('$tok takes ${f.lo == f.hi ? f.lo : '${f.lo} or more'} value${f.lo == 1 && f.hi == 1 ? '' : 's'}');
        }
        final u = f.u;
        if (u != null) {
          final a0 = a[0];
          return (v) => u(a0(v));
        }
        return (v) => f.f([for (final g in a) g(v)]);
      }
      if (tok == 'pi') return (_) => math.pi;
      if (tok == 'e') return (_) => math.e;
      if (!names.contains(tok)) fail('unknown name "$tok" (use x, slider names, or ${_fns.keys.join(' ')})');
      return (v) => v[tok] ?? double.nan;
    }
    fail('unexpected "$tok"');
  }
}
