import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/features/classroom/class_data.dart';
import 'package:zynetix_board/features/classroom/class_quiz_screen.dart';
import 'package:zynetix_board/features/classroom/explainer_screen.dart';

import 'helpers.dart';

ClassSamples samples() => ClassSamples.fromJson(jsonDecode(File('screenshots/fixtures/puc_class_samples.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  test('the PUC sample fixture parses', () {
    final s = samples();
    expect(s.explainers.single.steps, hasLength(6));
    expect(s.questions.first.answer, 3);
    expect(s.mocks.map((m) => m.exam), containsAll(['KCET', 'NEET', 'JEE Main']));
    expect(s.mastery.byRoll.first, hasLength(40));
  });

  testWidgets('class quiz: a tap cycles right, wrong, clear; reveal counts the marked rolls', (t) async {
    final s = await testServices(prefs: {'rollCount': 40, 'displaySize': 'classroom'});
    await pumpBoard(t, s, home: ClassQuizScreen(samples: samples()));
    await t.tap(find.byKey(const ValueKey('quizMark')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('fillRight')));
    await t.pump();
    for (final r in [2, 4]) {
      await t.tap(find.byKey(ValueKey('roll-$r'))); // right → wrong
      await t.pump();
    }
    await t.tap(find.byKey(const ValueKey('roll-6')));
    await t.tap(find.byKey(const ValueKey('roll-6'))); // right → wrong → clear
    await t.pump();
    await t.tap(find.byKey(const ValueKey('quizReveal')));
    await t.pump();
    // 37 right of 39 marked.
    expect(find.text('95%'), findsOneWidget);
  });

  testWidgets('an explainer steps and its tabs', (t) async {
    final s = await testServices(prefs: {'displaySize': 'classroom'});
    final data = samples();
    await pumpBoard(t, s, home: ExplainerScreen(samples: data, explainer: data.explainers.first));
    expect(find.byType(ExplainerScreen), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('exNext')));
    await t.pump();
    expect(find.byKey(const ValueKey('scene-same-time')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tab-like')));
    await t.pump();
    expect(find.textContaining('Air resistance'), findsWidgets);
  });
}
