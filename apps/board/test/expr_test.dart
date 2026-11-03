import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/expr.dart';

// Mirrors tools/pack-builder/src/expr.test.ts (the reference implementation's tests).
void main() {
  test('evaluates the board expression language', () {
    expect(compileExpr('2*x^2 - 3*x + 1', ['x'])({'x': 2}), 3);
    expect(compileExpr('A*sin(2*pi*x/L)', ['x', 'A', 'L'])({'x': 0.25, 'A': 3, 'L': 1}), closeTo(3, 1e-9));
    expect(compileExpr('-x^2', ['x'])({'x': 3}), -9);
    expect(compileExpr('2^3^2', [])({}), 512);
    expect(compileExpr('2^-1', [])({}), 0.5);
    expect(() => compileExpr('2x', ['x']), throwsA(isA<ExprError>()));
    expect(() => compileExpr('y+1', ['x']), throwsA(isA<ExprError>().having((e) => e.message, 'message', contains('unknown name'))));
  });

  test('functions, constants, numbers and errors match the reference', () {
    double ev(String s, [Map<String, double> v = const {}]) => compileExpr(s, v.keys.toList())(v);
    expect(ev('sqrt(16) + abs(-2) + floor(2.7)'), 8);
    expect(ev('log(1000) + ln(e)'), closeTo(4, 1e-12));
    expect(ev('exp(0) + cos(0) + atan(0) + asin(0) + acos(1) + tan(0)'), 2);
    expect(ev('1.5e2 + .5 + 1.'), 151.5);
    expect(ev('(1 + 2) * 3 - 4 / 2'), 7);
    expect(ev('--3 + +2'), 5);
    expect(ev('-2^2'), -4);
    expect(ev('(-2)^2'), 4);
    expect(ev('pi'), math.pi);
    expect(ev('2*exp(-x/3)', {'x': 3}), closeTo(2 / math.e, 1e-12));
    expect(() => compileExpr('sin x', ['x']), throwsA(isA<ExprError>().having((e) => e.message, 'm', contains('needs'))));
    expect(() => compileExpr('(1+2', []), throwsA(isA<ExprError>().having((e) => e.message, 'm', contains('missing )'))));
    expect(() => compileExpr('1+', []), throwsA(isA<ExprError>().having((e) => e.message, 'm', contains('ends too early'))));
    expect(() => compileExpr('1 # 2', []), throwsA(isA<ExprError>()));
    expect(tryCompileExpr('2x', ['x']), isNull);
  });
}
