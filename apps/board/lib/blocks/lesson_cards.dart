import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';
import '../engine/session_log.dart';
import 'math_text.dart';

/// The "one idea at a time" lesson pieces: cards that appear on Next, a character's speech
/// bubble, the "Remember this" rule, the exam trap, Pause and think, the exam-pattern question
/// with its solution steps, and the recall questions with the next-topic teaser.
///
/// Every view takes [shown] (how many steps of the block are on screen, from the lesson
/// controller) and [onReveal] (show up to step n: a tap on a card, an answer).

/// Type sizes on the layout canvas (two units per design pixel; a 1080p board draws them at
/// 2/3, so body text is at least 22 px there).
class _T {
  _T(BuildContext context) : narrow = context.narrow;
  final bool narrow;
  double get heading => narrow ? 46 : 64;
  double get lead => narrow ? 34 : 44;
  double get body => narrow ? 32 : 40;
  double get cardTitle => narrow ? 31 : 38;
  double get cardText => narrow ? 27 : 33;
  double get label => narrow ? 22 : 26;
}

IconData cardIcon(String? name) => switch (name) {
  'thermometer' => Icons.thermostat,
  'scale' => Icons.scale_outlined,
  'ruler' => Icons.straighten,
  'clock' => Icons.schedule,
  'speed' => Icons.speed,
  'heart' => Icons.favorite_border,
  'sparkle' => Icons.auto_awesome_outlined,
  'rupee' => Icons.currency_rupee,
  'phone' => Icons.smartphone,
  'cricket' => Icons.sports_cricket_outlined,
  'train' => Icons.train_outlined,
  'rain' => Icons.water_drop_outlined,
  'rocket' => Icons.rocket_launch_outlined,
  'chai' => Icons.emoji_food_beverage_outlined,
  'shop' => Icons.storefront_outlined,
  'bolt' => Icons.bolt,
  'bulb' => Icons.lightbulb_outline,
  'flask' => Icons.science_outlined,
  'box' => Icons.inventory_2_outlined,
  'arrow' => Icons.arrow_forward,
  'check' => Icons.check_circle_outline,
  'cross' => Icons.cancel_outlined,
  'sun' => Icons.wb_sunny_outlined,
  'person' => Icons.person_outline,
  'book' => Icons.menu_book_outlined,
  'globe' => Icons.public,
  'area' => Icons.crop_square,
  'volume' => Icons.view_in_ar_outlined,
  'weight' => Icons.fitness_center,
  'question' => Icons.help_outline,
  _ => Icons.circle_outlined,
};

/// A small spaced caps label over a group of cards ("CAN AN INSTRUMENT MEASURE IT?").
class CardsLabel extends StatelessWidget {
  const CardsLabel(this.text, {super.key, this.color = Z.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: zText(_T(context).label, FontWeight.w600).copyWith(color: color, letterSpacing: 2.4),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}

/// Shows [child] once [on]; until then it keeps its place (nothing jumps when it appears).
class Appear extends StatelessWidget {
  const Appear({super.key, required this.on, required this.child});
  final bool on;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: on ? 1 : 0,
    duration: const Duration(milliseconds: 260),
    child: AnimatedSlide(
      offset: on ? Offset.zero : const Offset(0, 0.08),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: IgnorePointer(ignoring: !on, child: child),
    ),
  );
}

/// One card: icon, title and a short line; a big value with its unit (the unit in the accent
/// colour) or a yes/no mark on the right.
class LessonCardTile extends StatelessWidget {
  const LessonCardTile({super.key, required this.card, required this.lang, this.current = false, this.compact = false});
  final LessonCard card;
  final Lang lang;

  /// The card that just appeared: a pale blue fill.
  final bool current;

  /// A short row (seven base quantities in two columns).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final (fg, bg) = switch (card.tone) {
      'yes' => (Z.correct, Z.correctBg),
      'no' => (Z.trap, Z.trapBg),
      _ => (Z.primary, Z.tagBg),
    };
    final tileBg = card.tone == 'no' ? Z.trapBg.withValues(alpha: 0.55) : (current ? Z.tagBg : Z.tile);
    final iconSize = compact ? (t.narrow ? 56.0 : 64.0) : (t.narrow ? 64.0 : 80.0);
    final trailing = <Widget>[
      if (card.value != null || card.unit != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (card.value != null) Text(card.value!, style: zText(compact ? t.cardTitle + 4 : (t.narrow ? 44 : 60), FontWeight.w700).copyWith(color: Z.ink)),
            if (card.value != null && card.unit != null) SizedBox(width: t.narrow ? 8 : 14),
            if (card.unit != null) Text(card.unit!, style: zText(compact ? t.cardTitle + 2 : (t.narrow ? 40 : 54), FontWeight.w600).copyWith(color: card.unit == '?' ? Z.trap : Z.primary)),
          ],
        ),
      if (card.tone == 'yes' || card.tone == 'no')
        Container(
          width: t.narrow ? 48 : 60,
          height: t.narrow ? 48 : 60,
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          child: Icon(card.tone == 'yes' ? Icons.check : Icons.close, color: Colors.white, size: t.narrow ? 30 : 38),
        ),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: t.narrow ? 22 : 30, vertical: compact ? (t.narrow ? 14 : 18) : (t.narrow ? 18 : 24)),
      decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(Z.radius)),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(color: card.tone == null ? (current ? Colors.white : bg) : bg, shape: BoxShape.circle),
            child: Icon(cardIcon(card.icon), color: fg, size: iconSize * 0.52),
          ),
          SizedBox(width: t.narrow ? 18 : 26),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MathText(card.title.t(lang), accent: Z.primary, maxLines: 2, style: zText(compact ? t.cardTitle - 2 : t.cardTitle, FontWeight.w600).copyWith(color: Z.ink, height: 1.25)),
                if (card.text != null) ...[
                  const SizedBox(height: 4),
                  MathText(card.text!.t(lang), accent: Z.primary, maxLines: 2, style: zText(compact ? t.cardText - 3 : t.cardText, FontWeight.w400).copyWith(color: Z.muted, height: 1.3)),
                ],
              ],
            ),
          ),
          for (final w in trailing) ...[SizedBox(width: t.narrow ? 14 : 24), w],
        ],
      ),
    );
  }
}

/// A list (or two-column grid) of cards; cards after [shown] keep their place, unseen.
class CardList extends StatelessWidget {
  const CardList({super.key, required this.cards, required this.lang, this.shown, this.columns = 1, this.title});
  final List<LessonCard> cards;
  final Lang lang;
  final int? shown;
  final int columns;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final n = shown ?? cards.length;
    final gap = context.narrow ? 14.0 : 20.0;
    final compact = columns > 1 && cards.every((c) => c.value == null);
    Widget tile(int i) => Appear(
      on: i < n,
      child: LessonCardTile(card: cards[i], lang: lang, current: shown != null && i == n - 1 && n < cards.length, compact: compact),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[CardsLabel(title!), SizedBox(height: gap + 4)],
        if (columns == 1)
          for (var i = 0; i < cards.length; i++) ...[if (i > 0) SizedBox(height: gap), tile(i)]
        else
          for (var r = 0; r < cards.length; r += columns) ...[
            if (r > 0) SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var k = r; k < r + columns; k++) ...[
                  if (k > r) SizedBox(width: gap),
                  Expanded(child: k < cards.length ? tile(k) : const SizedBox.shrink()),
                ],
              ],
            ),
          ],
      ],
    );
  }
}

/// A character's line: the round avatar with its coloured ring and a speech bubble.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.speaker, required this.lang, this.dark = false});
  final Speaker speaker;
  final Lang lang;
  final bool dark;

  static String asset(Character c) => 'assets/characters/${c.name}.png';

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final ring = speaker.who == Character.diya ? Z.diya : Z.aarav;
    final d = t.narrow ? 88.0 : 120.0;
    final ink = dark ? Z.onStage : Z.ink;
    return Row(
      key: ValueKey('speaker-${speaker.who.name}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: d,
          height: d,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
          child: ClipOval(
            child: ColoredBox(
              color: const Color(0xFFF6F1E7),
              child: Image.asset(asset(speaker.who), fit: BoxFit.cover, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => Center(child: Text(tr(speaker.who.name, lang)[0], style: zTitle(d * 0.4).copyWith(color: ring)))),
            ),
          ),
        ),
        SizedBox(width: t.narrow ? 14 : 20),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: t.narrow ? 24 : 34, vertical: t.narrow ? 16 : 22),
            decoration: BoxDecoration(
              color: dark ? Z.transport : Colors.white,
              borderRadius: BorderRadius.circular(t.narrow ? 32 : 44),
              border: Border.all(color: dark ? Z.stageAxis : Z.ink, width: 3),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${tr(speaker.who.name, lang)}: ', style: zText(t.narrow ? 29 : 36, FontWeight.w700).copyWith(color: ink)),
                  TextSpan(text: speaker.say.t(lang).replaceAll('*', ''), style: zText(t.narrow ? 29 : 36, FontWeight.w500).copyWith(color: ink, height: 1.35)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A white panel that holds a stepped block: the tag, then [child]; it scrolls when taller,
/// and a tap anywhere shows the next idea.
class StepPanel extends StatelessWidget {
  const StepPanel({super.key, required this.child, this.tag, this.onTap, this.stripe, this.tagColor, this.tagBg, this.center = true, this.dots});
  final Widget child;
  final String? tag;
  final VoidCallback? onTap;

  /// [center]: the content sits in the middle of the panel when it is shorter (it scrolls
  /// from the top when taller).
  /// A coloured stripe along the top (the exam trap).
  final Color? stripe;
  final Color? tagColor, tagBg;
  final bool center;

  /// (shown, total): small progress dots by the tag.
  final (int, int)? dots;

  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    final pad = EdgeInsets.fromLTRB(narrow ? 36 : 80, narrow ? 32 : 56, narrow ? 36 : 80, narrow ? 32 : 56);
    final head = Row(
      children: [
        if (tag != null) Flexible(child: ZTag(tag!, color: tagColor ?? Z.primary, background: tagBg ?? Z.tagBg)),
        if (dots != null && dots!.$2 > 1) ...[
          const SizedBox(width: 24),
          for (var i = 0; i < dots!.$2; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              width: i < dots!.$1 ? 36 : 14,
              height: 14,
              decoration: BoxDecoration(color: i < dots!.$1 ? Z.primary : Z.track, borderRadius: BorderRadius.circular(Z.pill)),
            ),
        ],
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Z.panel, borderRadius: BorderRadius.circular(Z.panelRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stripe != null) Container(height: 12, color: stripe),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: pad,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: (box.maxHeight - pad.vertical).clamp(0, double.infinity)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
                      children: [
                        if (tag != null || dots != null) ...[head, SizedBox(height: narrow ? 24 : 36)],
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two columns on a board (text left, cards right), one column on a phone.
class TwoColumns extends StatelessWidget {
  const TwoColumns({super.key, required this.left, this.right, this.leftFlex = 5, this.rightFlex = 6});
  final Widget left;
  final Widget? right;
  final int leftFlex, rightFlex;
  @override
  Widget build(BuildContext context) {
    if (right == null) return Align(alignment: Alignment.topLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1900), child: left));
    if (context.narrow || context.portrait) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, SizedBox(height: context.narrow ? 32 : 48), right!]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        const SizedBox(width: 80),
        Expanded(flex: rightFlex, child: right!),
      ],
    );
  }
}

/// A numbered step or point: the newest one in pale blue.
class StepRow extends StatelessWidget {
  const StepRow({super.key, required this.n, required this.text, required this.lang, this.current = false, this.numbered = true});
  final int n;
  final String text;
  final Lang lang;
  final bool current, numbered;
  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final d = t.narrow ? 52.0 : 64.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: t.narrow ? 20 : 28, vertical: t.narrow ? 16 : 22),
      decoration: BoxDecoration(color: current ? Z.tagBg : Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: d,
            height: d,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: current ? Z.primary : Colors.white, shape: BoxShape.circle, border: current ? null : Border.all(color: Z.line, width: 2)),
            child: numbered
                ? Text('$n', style: zText(t.narrow ? 26 : 30, FontWeight.w700).copyWith(color: current ? Colors.white : Z.ink2))
                : Icon(Icons.arrow_forward, size: d * 0.5, color: current ? Colors.white : Z.ink2),
          ),
          SizedBox(width: t.narrow ? 18 : 26),
          Expanded(child: MathText(text, accent: Z.primary, style: zText(t.body, FontWeight.w400).copyWith(color: Z.ink, height: 1.4))),
        ],
      ),
    );
  }
}

/// "15 cm": the number and the unit, big, each with its name under a bracket.
class HeroMeasure extends StatelessWidget {
  const HeroMeasure({super.key, required this.raw, required this.lang});
  final Map<String, dynamic> raw;
  final Lang lang;
  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final big = t.narrow ? 120.0 : 180.0;
    Widget part(String s, String label, Color c) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s, style: zText(big, FontWeight.w700).copyWith(color: c, height: 1.05)),
        const SizedBox(height: 8),
        // The bracket under the part.
        SizedBox(
          height: 22,
          child: CustomPaint(painter: _Bracket(c), child: const SizedBox(width: double.infinity)),
        ),
        const SizedBox(height: 10),
        Text(label, style: zText(t.label + 6, FontWeight.w600).copyWith(color: c, letterSpacing: 1.2)),
      ],
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.narrow ? 24 : 48, vertical: t.narrow ? 24 : 40),
      decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IntrinsicWidth(child: part(raw['value'] as String? ?? '', L10n.of(raw['valueLabel']).t(lang), Z.ink)),
                SizedBox(width: t.narrow ? 36 : 72),
                IntrinsicWidth(child: part(raw['unit'] as String? ?? '', L10n.of(raw['unitLabel']).t(lang), Z.primary)),
              ],
            ),
          ),
          if (raw['note'] is Map) ...[
            SizedBox(height: t.narrow ? 20 : 32),
            MathText(L10n.of(raw['note']).t(lang), accent: Z.primary, align: TextAlign.center, style: zText(t.cardText, FontWeight.w400).copyWith(color: Z.ink2, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _Bracket extends CustomPainter {
  _Bracket(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = c
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(4, 2)
        ..lineTo(4, s.height - 4)
        ..lineTo(s.width - 4, s.height - 4)
        ..lineTo(s.width - 4, 2),
      p,
    );
  }

  @override
  bool shouldRepaint(_Bracket old) => old.c != c;
}

/// An intro or concept block in the "one idea at a time" style.
class SteppedConcept extends StatelessWidget {
  const SteppedConcept({super.key, required this.block, required this.lang, required this.shown, required this.lessonTitle, this.onTap, required this.tag});
  final Block block;
  final Lang lang;
  final int shown;
  final String lessonTitle, tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = block, l = lang, t = _T(context);
    final intro = b.type == BlockType.intro;
    final hero = b.raw['hero'] as Map<String, dynamic>?;
    final cards = b.cards;
    final points = b.list('points');
    final total = b.revealSteps(null);
    final all = !b.reveal || shown >= total;
    // Steps in order: the hero, each card, each point.
    var k = 0;
    final heroAt = hero != null ? k++ : -1;
    final cardsFrom = k;
    k += cards.length;
    final pointsFrom = k;
    bool on(int step) => !b.reveal || step < shown;
    final cardsShown = b.reveal ? (shown - cardsFrom).clamp(0, cards.length) : null;
    final heading = intro ? b.f('heading').t(l) : (b.title?.t(l) ?? '');
    final body = intro ? b.f('hook').t(l) : b.f('body').t(l);
    final speaker = b.speaker;
    final hasRight = cards.isNotEmpty || hero != null;
    final pointsW = [
      for (var i = 0; i < points.length; i++) ...[
        if (i > 0) SizedBox(height: t.narrow ? 14 : 20),
        Appear(
          on: on(pointsFrom + i),
          child: StepRow(n: i + 1, text: points[i].t(l), lang: l, numbered: b.reveal && cards.isEmpty && hero == null, current: b.reveal && !all && shown - 1 == pointsFrom + i),
        ),
      ],
    ];
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (intro) ...[Text(lessonTitle, style: zText(t.narrow ? 26 : 32, FontWeight.w500).copyWith(color: Z.muted)), const SizedBox(height: 8)],
        MathText(heading, accent: Z.primary, style: zTitle(t.heading).copyWith(height: 1.2)),
        SizedBox(height: t.narrow ? 16 : 28),
        MathText(body, accent: Z.primary, style: zText(t.lead, FontWeight.w400).copyWith(color: Z.ink2, height: 1.45)),
        if (b.s('formula') != null) ...[SizedBox(height: t.narrow ? 24 : 36), Formula(b.s('formula')!)],
        if (hasRight && points.isNotEmpty) ...[SizedBox(height: t.narrow ? 24 : 40), ...pointsW],
        if (speaker != null) ...[SizedBox(height: t.narrow ? 28 : 48), Appear(on: all, child: SpeechBubble(speaker: speaker, lang: l))],
      ],
    );
    Widget? right;
    if (hasRight) {
      right = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hero != null) Appear(on: on(heroAt), child: HeroMeasure(raw: hero, lang: l)),
          if (hero != null && cards.isNotEmpty) SizedBox(height: t.narrow ? 24 : 36),
          if (cards.isNotEmpty)
            CardList(
              cards: cards,
              lang: l,
              shown: cardsShown,
              columns: cards.length > 4 && !t.narrow ? 2 : 1,
              title: b.maybe('cardsTitle')?.t(l),
            ),
        ],
      );
    } else if (points.isNotEmpty) {
      // No cards: the steps sit under the text, full width.
      right = null;
    }
    return StepPanel(
      tag: tag,
      onTap: onTap,
      dots: b.reveal ? (shown.clamp(1, total), total) : null,
      child: hasRight
          ? TwoColumns(left: left, right: right)
          : TwoColumns(
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1700), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    MathText(heading, accent: Z.primary, style: zTitle(t.heading).copyWith(height: 1.2)),
                    SizedBox(height: t.narrow ? 16 : 28),
                    MathText(body, accent: Z.primary, style: zText(t.lead, FontWeight.w400).copyWith(color: Z.ink2, height: 1.45)),
                    if (b.s('formula') != null) ...[SizedBox(height: t.narrow ? 24 : 36), Formula(b.s('formula')!)],
                  ])),
                  SizedBox(height: t.narrow ? 28 : 48),
                  ...pointsW,
                  if (speaker != null) ...[SizedBox(height: t.narrow ? 28 : 48), Appear(on: all, child: Align(alignment: Alignment.centerLeft, child: SpeechBubble(speaker: speaker, lang: l)))],
                ],
              ),
            ),
    );
  }
}

/// "Remember this." and the rule, big and centred, with its formula.
class RuleCard extends StatelessWidget {
  const RuleCard({super.key, required this.block, required this.lang});
  final Block block;
  final Lang lang;
  @override
  Widget build(BuildContext context) {
    final t = _T(context), l = lang;
    final f = block.s('formula');
    return StepPanel(
      center: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr('rememberThis', l), textAlign: TextAlign.center, style: zText(t.narrow ? 34 : 46, FontWeight.w500).copyWith(color: Z.muted)),
          SizedBox(height: t.narrow ? 20 : 36),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 2300),
            child: MathText(block.f('heading').t(l), accent: Z.primary, align: TextAlign.center, style: zTitle(t.narrow ? 54 : 96).copyWith(height: 1.2)),
          ),
          if (f != null) ...[
            SizedBox(height: t.narrow ? 24 : 44),
            Math.tex(f, textStyle: TextStyle(fontSize: t.narrow ? 56 : 88, color: Z.primary), onErrorFallback: (_) => Text(f)),
          ],
          SizedBox(height: t.narrow ? 24 : 44),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1800),
            child: MathText(block.f('body').t(l), accent: Z.primary, align: TextAlign.center, style: zText(t.body, FontWeight.w400).copyWith(color: Z.ink2, height: 1.45)),
          ),
          if (block.maybe('mnemonic') != null) ...[
            SizedBox(height: t.narrow ? 20 : 36),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1800),
              child: MathText(block.maybe('mnemonic')!.t(l), accent: Z.primary, align: TextAlign.center, style: zText(t.body, FontWeight.w600).copyWith(color: Z.primary, fontStyle: FontStyle.italic, height: 1.4)),
            ),
          ],
        ],
      ),
    );
  }
}

/// The exam trap: a red stripe, the wrong belief struck out, the right one, why, and where it
/// is asked.
class TrapCard extends StatelessWidget {
  const TrapCard({super.key, required this.block, required this.lang});
  final Block block;
  final Lang lang;
  @override
  Widget build(BuildContext context) {
    final t = _T(context), l = lang, b = block;
    final d = t.narrow ? 56.0 : 72.0;
    Widget row(IconData icon, Color c, Widget text) => Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(width: d, height: d, decoration: BoxDecoration(color: c, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: d * 0.56)),
        SizedBox(width: t.narrow ? 18 : 28),
        Expanded(child: text),
      ],
    );
    final exams = [for (final e in (b.raw['exams'] as List?) ?? const []) examLabel(e as String)];
    final f = b.s('formula');
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(t.narrow ? 20 : 28),
          decoration: BoxDecoration(color: Z.trapBg, borderRadius: BorderRadius.circular(Z.radius)),
          child: row(
            Icons.close,
            Z.trap,
            Text(b.f('wrong').t(l), style: zText(t.lead, FontWeight.w500).copyWith(color: Z.trap, decoration: TextDecoration.lineThrough, decorationColor: Z.trap, decorationThickness: 2.5, height: 1.35)),
          ),
        ),
        SizedBox(height: t.narrow ? 16 : 24),
        Container(
          padding: EdgeInsets.all(t.narrow ? 20 : 28),
          decoration: BoxDecoration(color: Z.correctBg, borderRadius: BorderRadius.circular(Z.radius)),
          child: row(Icons.check, Z.correct, MathText(b.f('right').t(l), accent: Z.correct, style: zText(t.lead, FontWeight.w600).copyWith(color: Z.ink, height: 1.35))),
        ),
        SizedBox(height: t.narrow ? 24 : 40),
        MathText(b.f('body').t(l), accent: Z.primary, style: zText(t.body, FontWeight.w400).copyWith(color: Z.ink2, height: 1.45)),
        if (exams.isNotEmpty) ...[
          SizedBox(height: t.narrow ? 24 : 40),
          CardsLabel(tr('whereAsked', l)),
          const SizedBox(height: 16),
          Wrap(spacing: 14, runSpacing: 14, children: [for (final e in exams) ZTag.neutral(e)]),
        ],
      ],
    );
    return StepPanel(
      tag: b.f('heading').t(l),
      tagColor: Z.trap,
      tagBg: Z.trapBg,
      stripe: Z.trap,
      child: TwoColumns(
        leftFlex: 6,
        rightFlex: 4,
        left: left,
        right: f == null
            ? null
            : Container(
                padding: EdgeInsets.all(t.narrow ? 28 : 48),
                decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Math.tex(f, textStyle: TextStyle(fontSize: t.narrow ? 48 : 64, color: Z.ink), onErrorFallback: (_) => Text(f)),
                  ),
                ),
              ),
      ),
    );
  }
}

String examLabel(String e) => switch (e) {
  'PUC' => 'PUC boards',
  'JEE' => 'JEE Main',
  'JEE_ADV' => 'JEE Advanced',
  _ => e,
};

/// "Pause and think": the question, big answer buttons; a tap shows the right one and a
/// one-line why at once. Step 2k+1 shows question k, step 2k+2 its answer.
class PauseThinkView extends StatefulWidget {
  const PauseThinkView({super.key, required this.questions, required this.lang, required this.shown, required this.onReveal, this.recorder});
  final List<Question> questions;
  final Lang lang;
  final int shown;
  final ValueChanged<int> onReveal;
  final SessionRecorder? recorder;
  @override
  State<PauseThinkView> createState() => _PauseThinkViewState();
}

class _PauseThinkViewState extends State<PauseThinkView> {
  final chosen = <int, int>{};

  @override
  Widget build(BuildContext context) {
    final t = _T(context), l = widget.lang;
    if (widget.questions.isEmpty) return const SizedBox.shrink();
    final k = ((widget.shown - 1) ~/ 2).clamp(0, widget.questions.length - 1);
    final q = widget.questions[k];
    final revealed = widget.shown >= 2 * k + 2;
    final pick = chosen[k];
    void tap(int i) {
      if (revealed) return;
      setState(() => chosen[k] = i);
      widget.recorder?.answer(questionId: q.id, mode: QuizMode.monitor, chosen: i, correct: i == q.answer, topicId: q.topicId, chapterId: q.chapterId);
      widget.onReveal(2 * k + 2);
    }

    Widget option(int i) {
      final right = i == q.answer;
      final (bg, fg, border) = !revealed
          ? (Colors.white, Z.ink, Z.line)
          : right
          ? (Z.correct, Colors.white, Z.correct)
          : i == pick
          ? (Z.wrongBg, Z.wrongText, Z.wrong)
          : (Z.well, Z.ghost, Z.track);
      return Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius), side: BorderSide(color: border, width: 3)),
        child: InkWell(
          key: ValueKey('think-$i'),
          borderRadius: BorderRadius.circular(Z.radius),
          onTap: () => tap(i),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: t.narrow ? 220 : 320, minHeight: t.narrow ? 96 : 120),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.narrow ? 32 : 52, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (revealed && right) ...[Icon(Icons.check_circle, color: Colors.white, size: t.narrow ? 36 : 44), const SizedBox(width: 14)],
                  if (revealed && !right && i == pick) ...[Icon(Icons.cancel, color: Z.wrong, size: t.narrow ? 36 : 44), const SizedBox(width: 14)],
                  Flexible(child: Text(q.options[i].t(l), textAlign: TextAlign.center, style: zText(t.narrow ? 34 : 44, FontWeight.w700).copyWith(color: fg))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return StepPanel(
      tag: tr('pauseThink', l),
      dots: widget.questions.length > 1 ? (k + 1, widget.questions.length) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MathText(q.stem.t(l), style: zTitle(t.narrow ? 46 : 72).copyWith(height: 1.25)),
          SizedBox(height: t.narrow ? 32 : 64),
          Wrap(spacing: t.narrow ? 20 : 32, runSpacing: 20, children: [for (var i = 0; i < q.options.length; i++) option(i)]),
          SizedBox(height: t.narrow ? 28 : 56),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: revealed && q.explanation != null
                ? Container(
                    key: ValueKey('why-$k'),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: t.narrow ? 24 : 40, vertical: t.narrow ? 20 : 30),
                    decoration: BoxDecoration(color: Z.correctBg, borderRadius: BorderRadius.circular(Z.radius)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 4), child: Icon(Icons.lightbulb_outline, color: Z.correct, size: t.narrow ? 36 : 46)),
                        SizedBox(width: t.narrow ? 16 : 24),
                        Expanded(child: MathText(q.explanation!.t(l), accent: Z.correct, style: zText(t.body, FontWeight.w500).copyWith(color: Z.ink, height: 1.4))),
                      ],
                    ),
                  )
                : Text(key: const ValueKey('hint'), tr('tapAnswer', l), style: zText(t.cardText, FontWeight.w400).copyWith(color: Z.muted)),
          ),
        ],
      ),
    );
  }
}

/// An exam-pattern question to pause and solve: the question and options on the left, the
/// solution on the right, one step per Next once the class has answered.
class ExamSolveView extends StatefulWidget {
  const ExamSolveView({super.key, required this.question, required this.exams, required this.lang, required this.shown, required this.onReveal, this.recorder});
  final Question question;
  final List<String> exams;
  final Lang lang;
  final int shown;
  final ValueChanged<int> onReveal;
  final SessionRecorder? recorder;
  @override
  State<ExamSolveView> createState() => _ExamSolveViewState();
}

class _ExamSolveViewState extends State<ExamSolveView> {
  int? pick;
  @override
  Widget build(BuildContext context) {
    final t = _T(context), l = widget.lang, q = widget.question;
    final revealed = widget.shown >= 2;
    final steps = q.solution.isNotEmpty ? q.solution : [?q.explanation];
    final stepsShown = (widget.shown - 1).clamp(0, steps.length);
    void tap(int i) {
      if (revealed) return;
      setState(() => pick = i);
      widget.recorder?.answer(questionId: q.id, mode: QuizMode.monitor, chosen: i, correct: i == q.answer, topicId: q.topicId, chapterId: q.chapterId);
      widget.onReveal(2);
    }

    Widget option(int i) {
      final right = i == q.answer;
      final (bg, fg, letterBg, letterFg) = !revealed
          ? (Z.tile, Z.ink, Colors.white, Z.ink2)
          : right
          ? (Z.correctBg, Z.ink, Z.correct, Colors.white)
          : i == pick
          ? (Z.wrongBg, Z.wrongText, Z.wrong, Colors.white)
          : (Z.well, Z.ghost, Z.segTrack, Z.ghost);
      final d = t.narrow ? 52.0 : 64.0;
      return Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Z.radius), side: BorderSide(color: revealed && right ? Z.correct : Colors.transparent, width: 3)),
        child: InkWell(
          key: ValueKey('solve-$i'),
          borderRadius: BorderRadius.circular(Z.radius),
          onTap: () => tap(i),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.narrow ? 18 : 24, vertical: t.narrow ? 14 : 18),
            child: Row(
              children: [
                Container(width: d, height: d, alignment: Alignment.center, decoration: BoxDecoration(color: letterBg, borderRadius: BorderRadius.circular(16)), child: Text('ABCD'[i], style: zText(t.narrow ? 26 : 30, FontWeight.w700).copyWith(color: letterFg))),
                SizedBox(width: t.narrow ? 18 : 26),
                Expanded(child: MathText(q.options[i].t(l), style: zText(t.body, FontWeight.w500).copyWith(color: fg))),
                if (revealed && right) Icon(Icons.check_circle, color: Z.correct, size: t.narrow ? 40 : 52),
              ],
            ),
          ),
        ),
      );
    }

    final pattern = trf('patternOf', l, {'e': widget.exams.map(examLabel).join(' · ')});
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ZTag(pattern),
            ZTag.neutral(tr('originalQ', l)),
            if (!revealed)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.timer_outlined, color: Z.muted, size: t.narrow ? 30 : 36), const SizedBox(width: 10), Text(tr('pauseSolve', l), style: zText(t.narrow ? 26 : 30, FontWeight.w600).copyWith(color: Z.muted))]),
              ),
          ],
        ),
        SizedBox(height: t.narrow ? 24 : 40),
        MathText(q.stem.t(l), style: zTitle(t.narrow ? 40 : 54).copyWith(height: 1.3)),
        SizedBox(height: t.narrow ? 24 : 40),
        for (var i = 0; i < q.options.length; i++) ...[if (i > 0) SizedBox(height: t.narrow ? 12 : 18), option(i)],
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CardsLabel(tr('solution', l), color: revealed ? Z.correctLabel : Z.muted),
        SizedBox(height: t.narrow ? 20 : 32),
        if (!revealed)
          Container(
            padding: EdgeInsets.all(t.narrow ? 24 : 36),
            decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(Z.radius)),
            child: Row(
              children: [
                Icon(Icons.hourglass_top, color: Z.muted, size: t.narrow ? 40 : 52),
                SizedBox(width: t.narrow ? 16 : 24),
                Expanded(child: Text(tr('solveFirst', l), style: zText(t.cardText, FontWeight.w400).copyWith(color: Z.ink2, height: 1.4))),
              ],
            ),
          )
        else
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) SizedBox(height: t.narrow ? 12 : 18),
            Appear(on: i < stepsShown, child: StepRow(n: i + 1, text: steps[i].t(l), lang: l, current: i == stepsShown - 1 && stepsShown < steps.length)),
          ],
      ],
    );
    final wide = !t.narrow && !context.portrait;
    return StepPanel(
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: left), const SizedBox(width: 64), Container(width: 3, height: 760, color: Z.track), const SizedBox(width: 64), Expanded(flex: 5, child: right)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, SizedBox(height: t.narrow ? 32 : 48), right]),
    );
  }
}

/// "Can you answer these without help?": numbered questions one at a time (a tap shows the
/// answer), then the next topic.
class RecallView extends StatefulWidget {
  const RecallView({super.key, required this.block, required this.lang, required this.shown, this.onTap});
  final Block block;
  final Lang lang;
  final int shown;
  final VoidCallback? onTap;
  @override
  State<RecallView> createState() => _RecallViewState();
}

class _RecallViewState extends State<RecallView> {
  final open = <int>{};
  @override
  Widget build(BuildContext context) {
    final t = _T(context), l = widget.lang, b = widget.block;
    final points = b.list('points'), answers = b.list('answers');
    final total = b.revealSteps(null);
    bool on(int i) => !b.reveal || i < widget.shown;
    final next = b.raw['next'] as Map?;
    final d = t.narrow ? 56.0 : 68.0;
    return StepPanel(
      tag: tr('recap', l),
      onTap: widget.onTap,
      dots: b.reveal ? (widget.shown.clamp(1, total), total) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Questions with answers to tap, or (no answers) the key ideas to recall one by one.
          Text(tr(answers.isNotEmpty ? 'recallTitle' : 'recallIdeasTitle', l), style: zTitle(t.heading)),
          const SizedBox(height: 8),
          Text(tr(answers.isNotEmpty ? 'tapToCheck' : 'recallKeyIdeas', l), style: zText(t.cardText, FontWeight.w400).copyWith(color: Z.muted)),
          SizedBox(height: t.narrow ? 28 : 48),
          for (var i = 0; i < points.length; i++) ...[
            if (i > 0) SizedBox(height: t.narrow ? 14 : 22),
            Appear(
              on: on(i),
              child: Material(
                color: Z.tile,
                borderRadius: BorderRadius.circular(Z.radius),
                child: InkWell(
                  key: ValueKey('recall-$i'),
                  borderRadius: BorderRadius.circular(Z.radius),
                  onTap: i < answers.length ? () => setState(() => open.contains(i) ? open.remove(i) : open.add(i)) : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: t.narrow ? 20 : 32, vertical: t.narrow ? 18 : 26),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: d, height: d, alignment: Alignment.center, decoration: const BoxDecoration(color: Z.primary, shape: BoxShape.circle), child: Text('${i + 1}', style: zText(t.narrow ? 28 : 32, FontWeight.w700).copyWith(color: Colors.white))),
                        SizedBox(width: t.narrow ? 18 : 28),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(padding: EdgeInsets.only(top: t.narrow ? 6 : 8), child: MathText(points[i].t(l), accent: Z.primary, style: zText(t.lead, FontWeight.w600).copyWith(color: Z.ink, height: 1.35))),
                              if (open.contains(i) && i < answers.length) ...[
                                SizedBox(height: t.narrow ? 10 : 14),
                                MathText(answers[i].t(l), accent: Z.correct, style: zText(t.body, FontWeight.w400).copyWith(color: Z.correctLabel, height: 1.4)),
                              ],
                            ],
                          ),
                        ),
                        if (i < answers.length) ...[const SizedBox(width: 16), Icon(open.contains(i) ? Icons.expand_less : Icons.expand_more, color: Z.muted, size: t.narrow ? 40 : 52)],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (next != null) ...[
            SizedBox(height: t.narrow ? 32 : 56),
            Appear(
              on: on(points.length),
              child: Container(
                key: const ValueKey('nextTeaser'),
                padding: EdgeInsets.symmetric(horizontal: t.narrow ? 24 : 40, vertical: t.narrow ? 22 : 30),
                decoration: BoxDecoration(color: Z.stage, borderRadius: BorderRadius.circular(Z.radius)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(color: Z.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text(L10n.of(next['label']).t(l).toUpperCase(), style: zText(t.label, FontWeight.w700).copyWith(color: Colors.white, letterSpacing: 1.6)),
                    ),
                    SizedBox(width: t.narrow ? 18 : 28),
                    Expanded(child: Text(L10n.of(next['title']).t(l), style: zText(t.narrow ? 30 : 40, FontWeight.w600).copyWith(color: Colors.white, height: 1.3))),
                    const SizedBox(width: 16),
                    Icon(Icons.arrow_forward, color: Colors.white, size: t.narrow ? 40 : 52),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Self-Learning: walks a stepped block through its steps by itself, one every [every].
class AutoReveal extends StatefulWidget {
  const AutoReveal({super.key, required this.total, required this.builder, this.every = const Duration(seconds: 6)});
  final int total;
  final Widget Function(int shown, ValueChanged<int> reveal) builder;
  final Duration every;
  @override
  State<AutoReveal> createState() => _AutoRevealState();
}

class _AutoRevealState extends State<AutoReveal> {
  int shown = 1;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.every, (_) {
      if (shown >= widget.total) {
        _t?.cancel();
      } else {
        setState(() => shown++);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(shown, (n) => setState(() => shown = n.clamp(1, widget.total)));
}
