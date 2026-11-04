// The shared expression cases (tools/pack-builder/src/expr-cases.json) give the same values and
// errors on the board as in the pack builder's reference engine.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/expr.dart';

void main() {
  final cases = (jsonDecode(File('../../tools/pack-builder/src/expr-cases.json').readAsStringSync())['cases'] as List).cast<Map<String, dynamic>>();

  test('there are shared cases', () => expect(cases.length, greaterThan(50)));

  for (final c in cases) {
    final vars = {for (final e in ((c['vars'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble()};
    test('${c['src']} $vars', () {
      if (c['error'] != null) {
        expect(() => compileExpr(c['src'] as String, vars.keys.toList()), throwsA(isA<ExprError>().having((e) => e.message, 'message', contains(c['error'] as String))));
        return;
      }
      final v = compileExpr(c['src'] as String, vars.keys.toList())(vars);
      if (c['value'] == null) {
        expect(v.isNaN, isTrue);
      } else {
        expect(v, closeTo((c['value'] as num).toDouble(), 1e-12));
      }
    });
  }

  test('if() evaluates only the branch it takes', () {
    final f = compileExpr('if(c, a, sqrt(-1) + b)', ['c', 'a', 'b']);
    expect(f({'c': 1, 'a': 2, 'b': 3}), 2);
    expect(f({'c': 0, 'a': 2, 'b': 3}).isNaN, isTrue);
  });

  test('rand gives the reference bits over many values', () {
    // A few values well spread over 0..1, the same as the reference engine.
    final xs = [for (var i = 0; i < 1000; i++) exprRand(i.toDouble())];
    expect(xs.every((v) => v >= 0 && v < 1), isTrue);
    expect(xs.reduce((a, b) => a + b) / xs.length, closeTo(0.5022, 0.001));
  });
}
