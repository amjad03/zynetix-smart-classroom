import 'dart:math' as math;

import '../../engine/model.dart';

/// The rules of the touch activities (schema `activity`), separate from the widgets so they are
/// unit-tested: where each item is, whether it is right, Check, Show answer and Reset.
/// Shuffles are seeded by the block id, so a class sees the same start every time and the start
/// is never already solved.
abstract class ActivityLogic {
  ActivityLogic(this.block);
  final Block block;

  factory ActivityLogic.of(Block b) => switch (b.raw['kind']) {
    'sort' => SortLogic(b),
    'order' => OrderLogic(b),
    'match' => MatchLogic(b),
    'label' => LabelLogic(b),
    'hotspot' => HotspotLogic(b),
    _ => FillLogic(b),
  };

  /// Items (or targets, blanks) the class must get right.
  int get total;

  /// Per item after a Check: true right, false wrong; null before checking or after a change.
  List<bool?> marks = const [];

  /// Every item has been placed or chosen.
  bool get complete;

  /// Marks every item; returns how many are right.
  int check() {
    marks = [for (var i = 0; i < total; i++) isRight(i)];
    return marks.where((m) => m == true).length;
  }

  bool isRight(int i);
  bool get allRight => List.generate(total, isRight).every((r) => r);

  /// Puts everything in its right place.
  void reveal();

  /// Back to the shuffled start.
  void reset();

  /// Anything moved: the old marks no longer apply.
  void changed() => marks = const [];

  math.Random get _rng {
    var h = 7;
    for (final c in block.id.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return math.Random(h);
  }

  /// 0..n-1 shuffled (never the identity when n > 1).
  List<int> shuffled(int n) {
    final p = List.generate(n, (i) => i)..shuffle(_rng);
    if (n > 1 && List.generate(n, (i) => i).every((i) => p[i] == i)) p.add(p.removeAt(0));
    return p;
  }
}

class SortLogic extends ActivityLogic {
  SortLogic(super.block) {
    reset();
  }
  late final buckets = [for (final b in (block.raw['buckets'] as List?) ?? const []) (id: b['id'] as String, label: L10n.of(b['label']))];
  late final items = [for (final b in (block.raw['items'] as List?) ?? const []) (text: L10n.of(b['text']), answer: b['answer'] as String)];

  /// The order items are shown in the tray.
  late final List<int> trayOrder = shuffled(items.length);

  /// The bucket each item is in (null: still in the tray).
  late List<String?> placed;

  @override
  int get total => items.length;
  @override
  bool get complete => placed.every((p) => p != null);
  @override
  bool isRight(int i) => placed[i] == items[i].answer;

  void place(int item, String? bucket) {
    placed[item] = bucket;
    changed();
  }

  @override
  void reveal() {
    placed = [for (final it in items) it.answer];
    check();
  }

  @override
  void reset() {
    placed = List.filled(items.length, null);
    changed();
  }
}

class OrderLogic extends ActivityLogic {
  OrderLogic(super.block) {
    reset();
  }
  late final steps = block.list('steps');

  /// order[k] = the step shown at position k.
  late List<int> order;

  @override
  int get total => steps.length;
  @override
  bool get complete => true;
  @override
  bool isRight(int k) => order[k] == k;

  void move(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= order.length || to >= order.length) return;
    final s = order.removeAt(from);
    order.insert(to, s);
    changed();
  }

  @override
  void reveal() {
    order = List.generate(steps.length, (i) => i);
    check();
  }

  @override
  void reset() {
    order = shuffled(steps.length);
    changed();
  }
}

class MatchLogic extends ActivityLogic {
  MatchLogic(super.block) {
    reset();
  }
  late final pairs = [for (final p in (block.raw['pairs'] as List?) ?? const []) (left: L10n.of(p['left']), right: L10n.of(p['right']))];

  /// The order of the right-hand cards (pair indexes).
  late final List<int> rightOrder = shuffled(pairs.length);

  /// The right card (pair index) each left card is joined to.
  late List<int?> link;

  @override
  int get total => pairs.length;
  @override
  bool get complete => link.every((l) => l != null);
  @override
  bool isRight(int i) => link[i] == i;

  /// Joins left [l] to right card [r]; a right card belongs to one left card at a time.
  void join(int l, int r) {
    for (var k = 0; k < link.length; k++) {
      if (link[k] == r) link[k] = null;
    }
    link[l] = r;
    changed();
  }

  @override
  void reveal() {
    link = List.generate(pairs.length, (i) => i);
    check();
  }

  @override
  void reset() {
    link = List.filled(pairs.length, null);
    changed();
  }
}

/// A target on a diagram (world units of the view).
typedef ActivityTarget = ({String id, double x, double y, double? r, double? w, double? h, L10n label});

List<ActivityTarget> _targets(Block b) => [
  for (final t in (b.raw['targets'] as List?) ?? const [])
    (
      id: t['id'] as String,
      x: (t['x'] as num).toDouble(),
      y: (t['y'] as num).toDouble(),
      r: (t['r'] as num?)?.toDouble(),
      w: (t['w'] as num?)?.toDouble(),
      h: (t['h'] as num?)?.toDouble(),
      label: L10n.of(t['label']),
    ),
];

class LabelLogic extends ActivityLogic {
  LabelLogic(super.block) {
    reset();
  }
  late final targets = _targets(block);

  /// Label chips: each target's label, then the distractors (target index, or null).
  late final List<({L10n text, int? target})> chips = [
    for (final (i, t) in targets.indexed) (text: t.label, target: i),
    for (final d in block.list('distractors')) (text: d, target: null),
  ];
  late final List<int> chipOrder = shuffled(chips.length);

  /// The chip on each target (null: empty).
  late List<int?> onTarget;

  @override
  int get total => targets.length;
  @override
  bool get complete => onTarget.every((c) => c != null);
  @override
  bool isRight(int i) => onTarget[i] != null && chips[onTarget[i]!].target == i;

  /// Chips not on a target yet.
  Iterable<int> get free => chipOrder.where((c) => !onTarget.contains(c));

  /// Puts [chip] on [target] (null: back to the tray); a chip already there goes back.
  void place(int chip, int? target) {
    for (var k = 0; k < onTarget.length; k++) {
      if (onTarget[k] == chip) onTarget[k] = null;
    }
    if (target != null) onTarget[target] = chip;
    changed();
  }

  @override
  void reveal() {
    onTarget = List.generate(targets.length, (i) => i);
    check();
  }

  @override
  void reset() {
    onTarget = List.filled(targets.length, null);
    changed();
  }
}

class HotspotLogic extends ActivityLogic {
  HotspotLogic(super.block) {
    reset();
  }
  late final targets = _targets(block);
  late final Set<String> answer = {...block.ids('answer')};
  late Set<int> picked;

  @override
  int get total => targets.length;
  @override
  bool get complete => picked.isNotEmpty;

  /// A target is right when it is picked exactly if it is in the answer.
  @override
  bool isRight(int i) => picked.contains(i) == answer.contains(targets[i].id);

  void tap(int i) {
    picked.contains(i) ? picked.remove(i) : picked.add(i);
    changed();
  }

  @override
  void reveal() {
    picked = {
      for (final (i, t) in targets.indexed)
        if (answer.contains(t.id)) i,
    };
    check();
  }

  @override
  void reset() {
    picked = {};
    changed();
  }
}

class FillLogic extends ActivityLogic {
  FillLogic(super.block) {
    reset();
  }
  late final blanks = [for (final b in (block.raw['blanks'] as List?) ?? const []) (options: L10n.list(b['options']), answer: (b['answer'] as num?)?.toInt() ?? 0)];
  late List<int?> chosen;

  @override
  int get total => blanks.length;
  @override
  bool get complete => chosen.every((c) => c != null);
  @override
  bool isRight(int i) => chosen[i] == blanks[i].answer;

  void choose(int blank, int option) {
    chosen[blank] = option;
    changed();
  }

  @override
  void reveal() {
    chosen = [for (final b in blanks) b.answer];
    check();
  }

  @override
  void reset() {
    chosen = List.filled(blanks.length, null);
    changed();
  }

  /// The passage in pieces: text, or a blank's index (0-based) for `__n__`.
  static List<Object> pieces(String passage) {
    final out = <Object>[];
    var at = 0;
    for (final m in RegExp(r'__(\d+)__').allMatches(passage)) {
      if (m.start > at) out.add(passage.substring(at, m.start));
      out.add(int.parse(m.group(1)!) - 1);
      at = m.end;
    }
    if (at < passage.length) out.add(passage.substring(at));
    return out;
  }
}
