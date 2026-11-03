import 'dart:math' as math;

/// The expression language of whiteboard plots and interactives, ported exactly from
/// tools/pack-builder/src/expr.ts (the reference): numbers, variables (x and slider names),
/// + - * / ^, unary minus, parentheses, functions sin cos tan asin acos atan sqrt exp ln log abs
/// floor, constants pi and e. Multiplication must be written (2*x, not 2x). Trig is in radians.
///
/// Precedence: + - < * / < unary minus < ^ (right-associative), so -x^2 = -(x^2) and 2^3^2 = 512;
/// an exponent may itself be signed (2^-1).
typedef Expr = double Function(Map<String, double> vars);

class ExprError implements Exception {
  ExprError(this.message);
  final String message;
  @override
  String toString() => message;
}

const Map<String, double Function(double)> _fns = {
  'sin': math.sin,
  'cos': math.cos,
  'tan': math.tan,
  'asin': math.asin,
  'acos': math.acos,
  'atan': math.atan,
  'sqrt': math.sqrt,
  'exp': math.exp,
  'ln': math.log,
  'log': _log10,
  'abs': _abs,
  'floor': _floor,
};

double _log10(double v) => math.log(v) / math.ln10;
double _abs(double v) => v.abs();
double _floor(double v) => v.isFinite ? v.floorToDouble() : v;

final _token = RegExp(r'\s*(\d+\.?\d*(?:e[+-]?\d+)?|\.\d+|[A-Za-z_]\w*|\S)');
final _digitOrDot = RegExp(r'^[\d.]');
final _ident = RegExp(r'^[A-Za-z_]');

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
    final e = expr();
    if (i < t.length) fail('unexpected "${t[i]}"');
    return e;
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

  Expr primary() {
    final tok = next();
    if (tok == null) fail('ends too early');
    if (tok == '(') {
      final e = expr();
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
      final f = _fns[tok];
      if (f != null) {
        if (next() != '(') fail('$tok needs (…)');
        final a = expr();
        if (next() != ')') fail('missing )');
        return (v) => f(a(v));
      }
      if (tok == 'pi') return (_) => math.pi;
      if (tok == 'e') return (_) => math.e;
      if (!names.contains(tok)) fail('unknown name "$tok" (use x, slider names, or ${_fns.keys.join(' ')})');
      return (v) => v[tok] ?? double.nan;
    }
    fail('unexpected "$tok"');
  }
}
