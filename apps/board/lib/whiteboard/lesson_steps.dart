import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:kinetix_ink/kinetix_ink.dart' hide Lesson;

import '../engine/model.dart';
import '../features/simple/kit.dart' show tr;

/// A lesson's steps as the board's flow bar shows them (Recall 5 min · Newton's law 8 min…),
/// and each step as a board page the teacher can write on.
class LessonStep {
  const LessonStep(this.index, this.block, this.title, this.minutes);

  /// Position in the lesson's blocks.
  final int index;
  final Block block;
  final L10n title;
  final int minutes;
}

L10n _typeName(BlockType t) => switch (t) {
  BlockType.intro => const L10n('Recall', 'ನೆನಪಿಸಿಕೊಳ್ಳಿ'),
  BlockType.concept => const L10n('Concept', 'ಪರಿಕಲ್ಪನೆ'),
  BlockType.model3d => const L10n('3D model', '3D ಮಾದರಿ'),
  BlockType.simulation => const L10n('Simulation', 'ಸಿಮ್ಯುಲೇಶನ್'),
  BlockType.virtualLab => const L10n('Virtual lab', 'ವರ್ಚುವಲ್ ಲ್ಯಾಬ್'),
  BlockType.example => const L10n('Worked example', 'ಉದಾಹರಣೆ'),
  BlockType.classQuiz => const L10n('Quick check', 'ತ್ವರಿತ ಪರೀಕ್ಷೆ'),
  BlockType.pyq => const L10n('Exam question', 'ಪರೀಕ್ಷಾ ಪ್ರಶ್ನೆ'),
  BlockType.trick => const L10n('Trick', 'ಉಪಾಯ'),
  BlockType.recap => const L10n('Recap', 'ಪುನರಾವರ್ತನೆ'),
  BlockType.whiteboard => const L10n('On the board', 'ಬೋರ್ಡ್‌ನಲ್ಲಿ'),
  BlockType.interactive => const L10n('Try it', 'ಪ್ರಯತ್ನಿಸಿ'),
  BlockType.challenge => const L10n('Challenge', 'ಸವಾಲು'),
  BlockType.activity => const L10n('Activity', 'ಚಟುವಟಿಕೆ'),
  BlockType.explainer => const L10n('Explainer', 'ವಿವರಣೆ'),
  BlockType.conceptVideo => const L10n('Concept video', 'ಪರಿಕಲ್ಪನಾ ವೀಡಿಯೊ'),
};

int _defaultSeconds(BlockType t) => switch (t) {
  BlockType.intro || BlockType.recap || BlockType.trick => 240,
  BlockType.classQuiz || BlockType.pyq => 300,
  BlockType.concept || BlockType.example || BlockType.whiteboard => 480,
  _ => 360,
};

/// The steps of [lesson] for this board's curriculum.
List<LessonStep> lessonSteps(Lesson lesson, {String board = 'kar_pu'}) => [
  for (var i = 0; i < lesson.blocks.length; i++)
    if (lesson.blocks[i].forBoard(board))
      LessonStep(
        i,
        lesson.blocks[i],
        lesson.blocks[i].title ?? lesson.blocks[i].maybe('heading') ?? lesson.blocks[i].maybe('caption') ?? _typeName(lesson.blocks[i].type),
        math.max(1, ((lesson.blocks[i].seconds ?? _defaultSeconds(lesson.blocks[i].type)) / 60).round()),
      ),
];

/// Lesson text as plain board text: inline maths markers removed.
String plain(String s) {
  var t = s.replaceAll(RegExp(r'\$\$?|\\\(|\\\)|\\\[|\\\]'), '');
  // \frac{a}{b} → a/b, \sqrt{x} → √x, \text{m/s} → m/s (innermost first).
  for (var i = 0; i < 4; i++) {
    t = t
        .replaceAllMapped(RegExp(r'\\[dt]?frac\{([^{}]*)\}\{([^{}]*)\}'), (m) => '${m[1]}/${m[2]}')
        .replaceAllMapped(RegExp(r'\\sqrt\{([^{}]*)\}'), (m) => '√${m[1]}')
        .replaceAllMapped(RegExp(r'\\(?:text|mathrm|mathbf|operatorname)\{([^{}]*)\}'), (m) => m[1]!);
  }
  const sup = {'0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻', '+': '⁺', 'n': 'ⁿ'};
  String up(String x) => x.split('').every(sup.containsKey) ? x.split('').map((c) => sup[c]).join() : '^($x)';
  t = t.replaceAllMapped(RegExp(r'\^\{([^{}]*)\}'), (m) => up(m[1]!)).replaceAllMapped(RegExp(r'\^([0-9n])'), (m) => up(m[1]!));
  t = t.replaceAllMapped(RegExp(r'_\{([^{}]*)\}'), (m) => m[1]!);
  const words = {
    r'\approx': '≈', r'\times': '×', r'\cdot': '·', r'\le': '≤', r'\ge': '≥', r'\neq': '≠', r'\pm': '±', r'\infty': '∞', r'\propto': '∝',
    r'\pi': 'π', r'\theta': 'θ', r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\lambda': 'λ', r'\mu': 'μ', r'\omega': 'ω', r'\rho': 'ρ', r'\sigma': 'σ',
    r'\Delta': 'Δ', r'\delta': 'δ', r'\to': '→', r'\rightarrow': '→', r'\degree': '°', r'\circ': '°', r'\,': ' ', r'\ ': ' ', r'\;': ' ', r'\quad': ' ',
  };
  final keys = words.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    t = t.replaceAll(k, words[k]!);
  }
  return t.replaceAll(RegExp(r'\*\*?'), '').replaceAll(RegExp(r'[{}]'), '').replaceAll(RegExp(r' {2,}'), ' ').trim();
}

const _ink = Color(0xFF13165A), _body = Color(0xFF4A4E66), _violet = Color(0xFF5442D8);

/// Lays out text as board elements from [top], wrapping at [width]. Returns the elements and
/// the y below them.
(List<BoardElement>, double) boardText(String text, Offset at, {double size = 40, Color color = _body, bool bold = false, double width = 1500}) {
  final out = <BoardElement>[];
  var y = at.dy;
  for (final para in text.split('\n')) {
    var line = '';
    void flush() {
      if (line.isEmpty) return;
      final p = layoutBoardText(line, size, color, bold: bold);
      out.add(TextElement(id: newElementId(), position: Offset(at.dx, y), text: line, color: color, fontSize: size, size: p.size, bold: bold));
      p.dispose();
      y += size * 1.35;
      line = '';
    }

    for (final word in para.split(' ')) {
      final next = line.isEmpty ? word : '$line $word';
      final p = layoutBoardText(next, size, color, bold: bold);
      final w = p.width;
      p.dispose();
      if (line.isNotEmpty && w > width) {
        flush();
        line = word;
      } else {
        line = next;
      }
    }
    flush();
  }
  return (out, y);
}

/// The page for lesson step [step] (number [n] in the flow), ready to write on: a small "From
/// lesson step" tag, the step's heading and its words (cards, points, worked steps).
List<BoardElement> stepPage(LessonStep step, int n, InstalledPack? pack, Lang l) {
  final b = step.block;
  final els = <BoardElement>[];
  var y = 60.0;
  void add((List<BoardElement>, double) r, [double gap = 18]) {
    els.addAll(r.$1);
    y = r.$2 + gap;
  }

  add(boardText(tr(l, 'From lesson step $n · you can write on it', 'ಪಾಠದ ಹಂತ $n ರಿಂದ · ಇದರ ಮೇಲೆ ಬರೆಯಬಹುದು'), Offset(100, y), size: 26, color: _violet), 10);
  add(boardText(plain(step.title.t(l)), Offset(100, y), size: 72, color: _ink, bold: true), 30);
  final lines = <String>[];
  for (final k in const ['hook', 'body', 'formula']) {
    final v = b.maybe(k);
    if (v != null && v.t(l).trim().isNotEmpty) lines.add(plain(v.t(l)));
  }
  for (final o in b.list('objectives')) {
    lines.add('• ${plain(o.t(l))}');
  }
  for (final c in b.cards) {
    final v = [if (c.value != null) c.value!, if (c.unit != null) c.unit!].join(' ');
    lines.add('• ${plain(c.title.t(l))}${c.text != null ? ': ${plain(c.text!.t(l))}' : ''}${v.isNotEmpty ? '  ($v)' : ''}');
  }
  for (final p in b.list('points')) {
    lines.add('• ${plain(p.t(l))}');
  }
  if (b.type == BlockType.example) {
    final q = b.maybe('problem') ?? b.maybe('question');
    if (q != null) lines.add(plain(q.t(l)));
    for (final (i, s) in b.list('steps').indexed) {
      lines.add('${i + 1}. ${plain(s.t(l))}');
    }
    final a = b.maybe('answer');
    if (a != null) lines.add('= ${plain(a.t(l))}');
  }
  if (b.type == BlockType.whiteboard) {
    for (final s in b.boardSteps) {
      if (s.say != null) lines.add('• ${plain(s.say!.t(l))}');
    }
  }
  if (lines.isEmpty) {
    final say = b.maybe('text') ?? b.maybe('body') ?? b.narration;
    if (say != null) lines.add(plain(say.t(l)));
  }
  if (b.type == BlockType.classQuiz || b.type == BlockType.pyq) {
    for (final id in b.ids('questionIds').take(3)) {
      final q = pack?.questions[id];
      if (q != null) lines.add('Q. ${plain(q.stem.t(l))}');
    }
  }
  for (final line in lines.take(12)) {
    add(boardText(line, Offset(110, y), size: 40), 14);
  }
  return els;
}

/// The recap page: the lesson's recap points, or each step's title.
List<BoardElement> recapPage(Lesson lesson, List<LessonStep> steps, Lang l) {
  final els = <BoardElement>[];
  var y = 60.0;
  void add((List<BoardElement>, double) r, [double gap = 18]) {
    els.addAll(r.$1);
    y = r.$2 + gap;
  }

  add(boardText(tr(l, 'Recap · ${plain(lesson.title.t(l))}', 'ಪುನರಾವರ್ತನೆ · ${plain(lesson.title.t(l))}'), Offset(100, y), size: 72, color: _ink, bold: true), 30);
  final recap = lesson.blocks.where((b) => b.type == BlockType.recap).firstOrNull;
  final points = recap == null ? <String>[] : [for (final p in recap.list('points')) plain(p.t(l))];
  for (final p in points.isEmpty ? [for (final s in steps) plain(s.title.t(l))] : points) {
    add(boardText('• $p', Offset(110, y), size: 42), 14);
  }
  return els;
}

/// The recap's points for the small preview card.
List<String> recapPoints(Lesson lesson, List<LessonStep> steps, Lang l) {
  final recap = lesson.blocks.where((b) => b.type == BlockType.recap).firstOrNull;
  final points = recap == null ? <String>[] : [for (final p in recap.list('points')) plain(p.t(l))];
  return points.isEmpty ? [for (final s in steps) plain(s.title.t(l))] : points;
}

/// The quick-check question for a step: a quiz question of the lesson (the next one after the
/// step), else any question of the topic.
Question? quickCheck(Lesson lesson, InstalledPack? pack, int stepIndex) {
  if (pack == null) return null;
  final quiz = [
    for (var i = 0; i < lesson.blocks.length; i++)
      if (lesson.blocks[i].type == BlockType.classQuiz || lesson.blocks[i].type == BlockType.pyq) (i, lesson.blocks[i]),
  ];
  for (final (i, b) in [...quiz.where((q) => q.$1 >= stepIndex), ...quiz]) {
    for (final id in b.ids('questionIds')) {
      final q = pack.questions[id];
      if (q != null && i >= 0) return q;
    }
  }
  return pack.questions.values.where((q) => q.topicId == lesson.topicId).firstOrNull;
}

/// The answer of [q] in words.
String answerOf(Question q, Lang l) {
  if (q.isNumeric && q.numericAnswer != null) return '${q.numericAnswer}';
  final ids = q.answers ?? [q.answer];
  final opts = [
    for (final i in ids)
      if (i >= 0 && i < q.options.length) plain(q.options[i].t(l)),
  ];
  return opts.join(' · ');
}
