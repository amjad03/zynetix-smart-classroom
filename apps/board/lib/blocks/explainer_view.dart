import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';
import '../features/simple/kit.dart' show S;
import 'lesson_cards.dart';
import 'math_text.dart';

/// An explainer block (the Zynetix School explainers, lesson-schema ExplainerBlock): the usual
/// wrong idea and what is true up front ("Many people think" / "Actually"), then up to four ways
/// in: Watch it (steps one at a time; with `reveal` the lesson's Next walks them), Try it
/// (predict, then see why), Story (comic frames) and It's like (an everyday analogy).
class ExplainerView extends StatefulWidget {
  const ExplainerView({super.key, required this.block, required this.lang, required this.shown, required this.onReveal});
  final Block block;
  final Lang lang;

  /// Watch steps shown (1 = the first), from the lesson controller.
  final int shown;
  final ValueChanged<int> onReveal;

  @override
  State<ExplainerView> createState() => _ExplainerViewState();
}

enum _Tab { watch, tryIt, story, like }

class _ExplainerViewState extends State<ExplainerView> {
  _Tab? _tab;

  Block get b => widget.block;
  Lang get l => widget.lang;
  List<Map<String, dynamic>> _maps(Object? v) => [
    for (final e in (v as List?) ?? const [])
      if (e is Map) e.cast<String, dynamic>(),
  ];
  List<Map<String, dynamic>> get watch => _maps(b.raw['watch']);
  Map<String, dynamic>? get tryIt => (b.raw['try'] as Map?)?.cast<String, dynamic>();
  List<Map<String, dynamic>> get story => _maps(b.raw['story']);
  Map<String, dynamic>? get like => (b.raw['analogy'] as Map?)?.cast<String, dynamic>();

  List<_Tab> get tabs => [
    if (watch.isNotEmpty) _Tab.watch,
    if (tryIt != null && _maps(tryIt!['steps']).isNotEmpty) _Tab.tryIt,
    if (story.isNotEmpty) _Tab.story,
    if (like != null) _Tab.like,
  ];

  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    final ts = tabs;
    final tab = ts.contains(_tab) ? _tab! : ts.firstOrNull;
    final myth = b.raw['misconception'] is Map ? (b.raw['misconception'] as Map).cast<String, dynamic>() : null;
    final tagline = b.maybe('tagline');
    return StepPanel(
      key: ValueKey('explainer:${b.id}'),
      tag: blockName(BlockType.explainer, l),
      center: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(b.f('heading').t(l), style: zTitle(narrow ? 44 : 56)),
          if (tagline != null) ...[
            const SizedBox(height: 12),
            MathText(tagline.t(l), style: zText(narrow ? 28 : 32, FontWeight.w400).copyWith(color: Z.muted, height: 1.4)),
          ],
          if (myth != null) ...[SizedBox(height: narrow ? 28 : 40), _Misconception(myth: L10n.of(myth['myth']), truth: L10n.of(myth['truth']), lang: l)],
          if (ts.length > 1) ...[
            SizedBox(height: narrow ? 28 : 40),
            ZSegmented<_Tab>(
              items: [for (final t in ts) (t, _tabLabel(t), ValueKey('ex-tab-${t.name}'))],
              selected: tab!,
              onChanged: (t) => setState(() => _tab = t),
              fontSize: narrow ? 26 : 30,
            ),
          ],
          if (tab != null) ...[
            SizedBox(height: narrow ? 28 : 40),
            switch (tab) {
              _Tab.watch => _Watch(steps: watch, lang: l, shown: widget.shown.clamp(1, watch.length), onReveal: widget.onReveal),
              _Tab.tryIt => _TryIt(key: ValueKey('try:${b.id}'), data: tryIt!, lang: l),
              _Tab.story => _Story(frames: story, lang: l),
              _Tab.like => _Like(data: like!, lang: l),
            },
          ],
        ],
      ),
    );
  }

  String _tabLabel(_Tab t) => switch (t) {
    _Tab.watch => tr('watchIt', l),
    _Tab.tryIt => tr('tryIt', l),
    _Tab.story => tr('story', l),
    _Tab.like => tr('itsLike', l),
  };
}

/// "Many people think" (struck out, red) beside "Actually" (green).
class _Misconception extends StatelessWidget {
  const _Misconception({required this.myth, required this.truth, required this.lang});
  final L10n myth, truth;
  final Lang lang;
  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    Widget card(Color bg, Color stripe, IconData icon, String label, Widget text) => Container(
      key: ValueKey('misconception-$label'),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Z.radius),
        border: Border(left: BorderSide(color: stripe, width: 8)),
      ),
      padding: EdgeInsets.fromLTRB(narrow ? 24 : 36, narrow ? 22 : 30, narrow ? 24 : 36, narrow ? 22 : 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: narrow ? 40 : 48, color: stripe),
          SizedBox(width: narrow ? 18 : 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: zText(narrow ? 24 : 28, FontWeight.w600).copyWith(color: stripe)),
                const SizedBox(height: 8),
                text,
              ],
            ),
          ),
        ],
      ),
    );
    final size = narrow ? 30.0 : 36.0;
    final left = card(
      Z.trapBg,
      Z.trap,
      Icons.do_not_disturb_alt_rounded,
      tr('manyThink', lang),
      Text(myth.t(lang), style: zText(size, FontWeight.w500).copyWith(color: Z.ink, decoration: TextDecoration.lineThrough, decorationColor: Z.trap, decorationThickness: 2.5, height: 1.35)),
    );
    final right = card(Z.correctBg, Z.correct, Icons.lightbulb_outline_rounded, tr('actually', lang), MathText(truth.t(lang), style: zText(size, FontWeight.w500).copyWith(color: Z.ink, height: 1.35)));
    if (narrow || context.portrait) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 16), right]);
    // (No IntrinsicHeight: maths in the text cannot report an intrinsic size.)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(flex: 4, child: left), const SizedBox(width: 24), Expanded(flex: 6, child: right)],
    );
  }
}

/// Watch it: the step on a dark stage card (its number and title), what is said beside it, the
/// step dots, and Next step.
class _Watch extends StatelessWidget {
  const _Watch({required this.steps, required this.lang, required this.shown, required this.onReveal});
  final List<Map<String, dynamic>> steps;
  final Lang lang;
  final int shown;
  final ValueChanged<int> onReveal;
  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    final s = steps[shown - 1];
    final title = L10n.of(s['title']).t(lang), say = L10n.of(s['say']).t(lang);
    final stage = Container(
      key: const ValueKey('watch-stage'),
      constraints: BoxConstraints(minHeight: narrow ? 220 : 380),
      padding: EdgeInsets.all(narrow ? 32 : 48),
      decoration: BoxDecoration(color: S.ink, borderRadius: BorderRadius.circular(Z.stageRadius)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$shown', style: zTitle(narrow ? 96 : 140, FontWeight.w700).copyWith(color: const Color(0xFFFFC94D), height: 1)),
          const SizedBox(height: 12),
          Text(trf('stepOf', lang, {'n': shown, 'm': steps.length}), style: zText(narrow ? 24 : 28, FontWeight.w500).copyWith(color: Colors.white70)),
          const SizedBox(height: 20),
          Text(title, style: zTitle(narrow ? 34 : 44).copyWith(color: Colors.white)),
        ],
      ),
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < steps.length; i++)
              GestureDetector(
                key: ValueKey('watch-dot-$i'),
                onTap: () => onReveal(i + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == shown - 1 ? 44 : 18,
                  height: 18,
                  decoration: BoxDecoration(color: i < shown ? S.violet : Z.track, borderRadius: BorderRadius.circular(Z.pill)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.record_voice_over_outlined, size: narrow ? 36 : 44, color: S.violet)),
            const SizedBox(width: 20),
            Expanded(child: MathText(say, style: zText(narrow ? 32 : 40, FontWeight.w400).copyWith(color: Z.ink, height: 1.45))),
          ],
        ),
        if (shown < steps.length) ...[
          const SizedBox(height: 32),
          BigButton(key: const ValueKey('watch-next'), icon: Icons.arrow_forward_rounded, label: tr('nextStep', lang), filled: false, trailingIcon: true, onPressed: () => onReveal(shown + 1)),
        ],
      ],
    );
    return TwoColumns(leftFlex: 4, rightFlex: 6, left: stage, right: side);
  }
}

/// Try it: the goal, then each small task: predict first (the common wrong idea among the
/// options), then why. The takeaway closes it.
class _TryIt extends StatefulWidget {
  const _TryIt({super.key, required this.data, required this.lang});
  final Map<String, dynamic> data;
  final Lang lang;
  @override
  State<_TryIt> createState() => _TryItState();
}

class _TryItState extends State<_TryIt> {
  final _picked = <int, int>{};
  final _why = <int>{};

  @override
  Widget build(BuildContext context) {
    final l = widget.lang, narrow = context.narrow;
    final steps = [
      for (final e in (widget.data['steps'] as List?) ?? const [])
        if (e is Map) e.cast<String, dynamic>(),
    ];
    final body = zText(narrow ? 30 : 36, FontWeight.w400).copyWith(color: Z.ink, height: 1.4);
    final done = [for (var i = 0; i < steps.length; i++) _why.contains(i) || _picked.containsKey(i)].every((x) => x);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(narrow ? 24 : 32),
          decoration: BoxDecoration(color: S.lavender, borderRadius: BorderRadius.circular(Z.radius)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_rounded, size: narrow ? 36 : 44, color: S.violet),
              const SizedBox(width: 20),
              Expanded(child: MathText(L10n.of(widget.data['goal']).t(l), style: body.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        for (final (i, s) in steps.indexed) ...[
          SizedBox(height: narrow ? 20 : 28),
          _tryStep(i, s, l, body, narrow),
        ],
        if (done) ...[
          SizedBox(height: narrow ? 24 : 32),
          Container(
            key: const ValueKey('try-takeaway'),
            padding: EdgeInsets.all(narrow ? 24 : 32),
            decoration: BoxDecoration(color: S.butter, borderRadius: BorderRadius.circular(Z.radius)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('remember', l), style: zText(narrow ? 24 : 28, FontWeight.w600).copyWith(color: S.ink)),
                const SizedBox(height: 8),
                MathText(L10n.of(widget.data['takeaway']).t(l), style: body.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _tryStep(int i, Map<String, dynamic> s, Lang l, TextStyle body, bool narrow) {
    final p = s['predict'] is Map ? (s['predict'] as Map).cast<String, dynamic>() : null;
    final options = p == null ? const <L10n>[] : L10n.list(p['options']);
    final answer = (p?['answer'] as num?)?.toInt() ?? 0, trap = (p?['trap'] as num?)?.toInt();
    final picked = _picked[i];
    final open = _why.contains(i) || picked != null;
    final hint = L10n.maybe(s['hint']);
    return Container(
      key: ValueKey('try-step-$i'),
      padding: EdgeInsets.all(narrow ? 24 : 32),
      decoration: BoxDecoration(color: Z.well, borderRadius: BorderRadius.circular(Z.radius), border: Border.all(color: Z.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: narrow ? 48 : 56,
                height: narrow ? 48 : 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: open ? S.violet : Z.segTrack, shape: BoxShape.circle),
                child: Text('${i + 1}', style: zText(narrow ? 24 : 28, FontWeight.w600).copyWith(color: open ? Colors.white : Z.ink2)),
              ),
              const SizedBox(width: 20),
              Expanded(child: MathText(L10n.of(s['task']).t(l), style: body.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: 16),
            if (L10n.of(p['question']).t(l) != L10n.of(s['task']).t(l)) ...[MathText(L10n.of(p['question']).t(l), style: body), const SizedBox(height: 12)],
            Text(tr('predictFirst', l), style: zText(narrow ? 22 : 26, FontWeight.w500).copyWith(color: Z.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final (k, o) in options.indexed)
                  _OptionChip(
                    key: ValueKey('try-$i-opt-$k'),
                    text: o.t(l),
                    state: picked == null ? _Opt.idle : (k == answer ? _Opt.right : (k == picked ? _Opt.wrong : _Opt.idle)),
                    onTap: picked == null ? () => setState(() => _picked[i] = k) : null,
                  ),
              ],
            ),
            if (picked != null) ...[
              const SizedBox(height: 14),
              Text(
                picked == answer ? tr('rightPick', l) : (picked == trap ? tr('trapPicked', l) : tr('notQuite', l)),
                style: zText(narrow ? 26 : 30, FontWeight.w600).copyWith(color: picked == answer ? Z.correct : Z.wrongText),
              ),
            ],
          ],
          if (p == null && !open) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                ZSmallButton(key: ValueKey('try-why-$i'), icon: Icons.visibility_outlined, label: tr('showWhy', l), onPressed: () => setState(() => _why.add(i))),
                if (hint != null) Text('${tr('hint', l)}: ${hint.t(l)}', style: zText(narrow ? 24 : 28, FontWeight.w400).copyWith(color: Z.muted)),
              ],
            ),
          ],
          if (open) ...[
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(narrow ? 20 : 26),
              decoration: BoxDecoration(color: Z.correctBg, borderRadius: BorderRadius.circular(Z.radius)),
              child: MathText(L10n.of(s['explain']).t(l), style: body),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Opt { idle, right, wrong }

class _OptionChip extends StatelessWidget {
  const _OptionChip({super.key, required this.text, required this.state, this.onTap});
  final String text;
  final _Opt state;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    final (bg, fg, border) = switch (state) {
      _Opt.right => (Z.correctBg, Z.correct, Z.correct),
      _Opt.wrong => (Z.wrongBg, Z.wrongText, Z.wrong),
      _Opt.idle => (Colors.white, Z.ink, Z.line),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius), side: BorderSide(color: border, width: 2)),
      child: InkWell(
        borderRadius: BorderRadius.circular(Z.radius),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: narrow ? 72 : 84, maxWidth: narrow ? 640 : 820),
          padding: EdgeInsets.symmetric(horizontal: narrow ? 22 : 30, vertical: 14),
          child: MathText(text, style: zText(narrow ? 28 : 32, FontWeight.w500).copyWith(color: fg, height: 1.3)),
        ),
      ),
    );
  }
}

/// Story: numbered frames, each a caption and the line said in it.
class _Story extends StatelessWidget {
  const _Story({required this.frames, required this.lang});
  final List<Map<String, dynamic>> frames;
  final Lang lang;
  static const _tints = [S.lavender, S.mint, S.butter, S.sky];
  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = narrow ? (box.maxWidth > 900 ? 2 : 1) : (frames.length >= 4 ? 4 : frames.length).clamp(1, 4);
        final w = (box.maxWidth - (cols - 1) * 20) / cols;
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            for (final (i, f) in frames.indexed)
              Container(
                key: ValueKey('story-$i'),
                width: w,
                padding: EdgeInsets.all(narrow ? 22 : 28),
                decoration: BoxDecoration(color: _tints[i % _tints.length], borderRadius: BorderRadius.circular(Z.radius)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}', style: zTitle(narrow ? 40 : 52, FontWeight.w700).copyWith(color: S.ink, height: 1)),
                    if (L10n.maybe(f['speech']) case final sp?) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Z.radius)),
                        child: Text('“${sp.t(lang)}”', style: zText(narrow ? 26 : 30, FontWeight.w600).copyWith(color: S.ink, height: 1.3)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    MathText(L10n.of(f['caption']).t(lang), style: zText(narrow ? 26 : 30, FontWeight.w400).copyWith(color: Z.ink, height: 1.4)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// It's like: the analogy's headline, everyday things paired with the lesson's, and where the
/// comparison stops working.
class _Like extends StatelessWidget {
  const _Like({required this.data, required this.lang});
  final Map<String, dynamic> data;
  final Lang lang;
  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow, l = lang;
    final pairs = [
      for (final p in (data['pairs'] as List?) ?? const [])
        if (p is List && p.length == 2) (L10n.of(p[0]), L10n.of(p[1])),
    ];
    final limits = L10n.maybe(data['limits']);
    Widget chip(String s, Color bg) => Container(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 20 : 28, vertical: narrow ? 16 : 20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Z.radius)),
      child: MathText(s, style: zText(narrow ? 28 : 32, FontWeight.w500).copyWith(color: Z.ink, height: 1.3)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MathText(L10n.of(data['headline']).t(l), style: zTitle(narrow ? 34 : 44, FontWeight.w600).copyWith(color: S.ink, height: 1.35)),
        if (pairs.isNotEmpty) ...[
          SizedBox(height: narrow ? 24 : 32),
          Row(
            children: [
              Expanded(child: Text(L10n.maybe(data['everyday'])?.t(l) ?? tr('everyday', l), style: zText(narrow ? 22 : 26, FontWeight.w600).copyWith(color: Z.muted))),
              SizedBox(width: narrow ? 56 : 80),
              Expanded(child: Text(L10n.maybe(data['concept'])?.t(l) ?? tr('inScience', l), style: zText(narrow ? 22 : 26, FontWeight.w600).copyWith(color: Z.muted))),
            ],
          ),
          for (final (i, (a, c)) in pairs.indexed) ...[
            const SizedBox(height: 14),
            Row(
              key: ValueKey('like-pair-$i'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: chip(a.t(l), S.butter)),
                SizedBox(width: narrow ? 56 : 80, child: Icon(Icons.arrow_forward_rounded, size: narrow ? 32 : 40, color: S.violet)),
                Expanded(child: chip(c.t(l), S.lavender)),
              ],
            ),
          ],
        ],
        if (limits != null) ...[
          SizedBox(height: narrow ? 24 : 32),
          Container(
            padding: EdgeInsets.all(narrow ? 22 : 28),
            decoration: BoxDecoration(color: Z.well, borderRadius: BorderRadius.circular(Z.radius), border: Border.all(color: Z.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('whereItStops', l), style: zText(narrow ? 22 : 26, FontWeight.w600).copyWith(color: Z.muted)),
                const SizedBox(height: 8),
                MathText(limits.t(l), style: zText(narrow ? 28 : 32, FontWeight.w400).copyWith(color: Z.ink2, height: 1.4)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
