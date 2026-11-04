import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/blocks/math_text.dart';

void main() {
  testWidgets('a long inline formula in a narrow box scrolls instead of overflowing', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: SizedBox(width: 240, child: MathText(r'Use $x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a} + \int_0^1 x^2\,dx + \sum_{n=1}^{\infty} \frac{1}{n^2}$ here'))),
    ));
    expect(t.takeException(), isNull);
  });
}
