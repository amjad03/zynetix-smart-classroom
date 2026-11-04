import 'dart:math';

import 'package:flutter/material.dart';

import '../../blocks/challenge_view.dart' show Celebration;
import '../../core/services.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import '../../engine/session_log.dart';
import '../participation.dart';
import 'game_stats.dart';
import 'game_store.dart';
import 'strings.dart';

/// Hits needed to beat a boss of [questions] questions: 70% of them, so one or two slips do
/// not lose the battle but guessing does.
int bossHealth(int questions) => max(1, (questions * 0.7).ceil());

/// Up to [n] of a chapter's questions for this board's curriculum, in a random order. Quick-fire
/// questions (single or multiple choice, no case to read) first; numeric, case-based and
/// assertion-reason ones only when there are too few others.
List<Question> bossQuestions(InstalledPack pack, String board, {int n = 10, Random? random}) {
  final topics = {for (final t in pack.chapter.topicsFor(board)) t.id};
  final qs = [
    for (final q in pack.questions.values)
      if (q.topicId == null || topics.contains(q.topicId)) q,
  ]..shuffle(random ?? Random());
  bool quick(Question q) => q.passage == null && (q.format == 'mcq' || q.format == 'multi_correct');
  return [...qs.where(quick), ...qs.where((q) => !quick(q))].take(n).toList();
}

/// A session recorder that also tells the battle about the class's answer to each question
/// (answers counted afterwards, e.g. a hands-up count, are recorded but do not hit the boss).
class _BossRecorder extends SessionRecorder {
  _BossRecorder({required super.outbox, required super.sectionId, required super.chapterId, required super.topicId, required super.packVersion, super.now, super.mastery, required this.onAnswer})
    : super.raw(mode: 'teacher', lessonId: '$chapterId.boss');
  final void Function(bool correct) onAnswer;

  @override
  void answer({required String questionId, required QuizMode mode, int? roll, int? team, required int? chosen, required bool correct, String? topicId, String? chapterId, String? source}) {
    super.answer(questionId: questionId, mode: mode, roll: roll, team: team, chosen: chosen, correct: correct, topicId: topicId, chapterId: chapterId, source: source);
    if (source == null) onAnswer(correct);
  }
}

/// A chapter test played as a boss battle: the boss's health bar drops with every right class
/// answer; the class wins when it is empty before the questions run out. Teams or roll call.
class BossBattleScreen extends StatefulWidget {
  const BossBattleScreen({super.key, required this.pack, this.mode = QuizMode.team, this.questions});
  final InstalledPack pack;
  final QuizMode mode;

  /// The questions to ask (a random 10 of the chapter's when null).
  final List<Question>? questions;

  @override
  State<BossBattleScreen> createState() => BossBattleScreenState();
}

class BossBattleScreenState extends State<BossBattleScreen> with TickerProviderStateMixin {
  late final s = ServicesScope.of(context);
  late final List<Question> questions = widget.questions ?? bossQuestions(widget.pack, s.config.board);
  late final int maxHp = bossHealth(questions.length);
  late int hp = maxHp;
  int correct = 0, asked = 0;
  bool? won;
  late final ClassRoom room = ClassRoom(rollCount: s.config.rollCount);
  late final SessionRecorder recorder = _BossRecorder(
    outbox: s.outbox,
    sectionId: s.config.sectionId,
    chapterId: widget.pack.chapter.id,
    topicId: questions.firstOrNull?.topicId ?? widget.pack.chapter.topics.firstOrNull?.id ?? widget.pack.chapter.id,
    packVersion: widget.pack.version,
    now: s.clock,
    mastery: s.mastery,
    onAnswer: _onAnswer,
  );
  late final AnimationController hit = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final AnimationController party = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  void _onAnswer(bool ok) {
    if (won != null) return;
    setState(() {
      asked++;
      if (ok) {
        correct++;
        hp = max(0, hp - 1);
        hit.forward(from: 0);
      }
    });
    if (hp == 0) _end(true);
  }

  void _end(bool victory) {
    if (won != null) return;
    setState(() => won = victory);
    if (victory) party.forward(from: 0);
    GameStore.of(s.mastery).recordBoss(BossResult(chapterId: widget.pack.chapter.id, won: victory, correct: correct, asked: asked, at: s.clock()));
    recorder.close(completed: true);
  }

  @override
  void dispose() {
    recorder.close(completed: won != null);
    hit.dispose();
    party.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = s.config.lang, text = Theme.of(context).textTheme;
    final name = '${gt('bossName', l)} ${widget.pack.chapter.title.t(l)}';
    final Widget body;
    if (questions.isEmpty) {
      body = Center(child: Text(gt('notEnoughQuestions', l), style: text.headlineMedium, textAlign: TextAlign.center));
    } else if (won != null) {
      body = Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(won! ? Icons.emoji_events : Icons.directions_run, size: 160, color: won! ? Z.accent : Z.wrong),
              const SizedBox(height: Z.gap),
              Text(won! ? gt('victory', l) : gt('bossEscaped', l), key: const ValueKey('bossResult'), style: text.displayLarge, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('$correct / $asked ${tr('correct', l)}${won! ? ' · +${GamePoints.boss} ${gt('points', l)}' : ''}', style: text.headlineMedium),
              const SizedBox(height: Z.gap),
              BigButton(icon: Icons.arrow_back, label: tr('back', l), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      );
    } else {
      body = QuizRunner(
        key: const ValueKey('bossQuiz'),
        questions: questions,
        mode: widget.mode,
        lang: l,
        recorder: recorder,
        room: room,
        onDone: () => _end(hp == 0),
      );
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Z.tap + 16,
        leading: IconButton(iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(gt('bossBattle', l), style: context.narrow ? text.headlineMedium : text.headlineLarge),
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(context.narrow ? 16 : 32),
            // A short landscape screen (a phone on its side): the boss stands beside the questions.
            child: MediaQuery.sizeOf(context).height < 900 && !context.portrait
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 320,
                        child: SingleChildScrollView(
                          child: _BossBar(name: name, hp: hp, maxHp: maxHp, hit: hit, lang: l, vertical: true),
                        ),
                      ),
                      const SizedBox(width: Z.gap),
                      Expanded(child: body),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BossBar(name: name, hp: hp, maxHp: maxHp, hit: hit, lang: l),
                      SizedBox(height: MediaQuery.sizeOf(context).height < 900 ? 8 : Z.gap),
                      Expanded(child: body),
                    ],
                  ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: Celebration(controller: party, stars: 3, label: gt('bossBeaten', l))),
          ),
        ],
      ),
    );
  }
}

/// The boss (a painted chapter guardian that shakes when hit) and its health bar.
class _BossBar extends StatelessWidget {
  const _BossBar({required this.name, required this.hp, required this.maxHp, required this.hit, required this.lang, this.vertical = false});
  final String name;
  final int hp, maxHp;
  final Animation<double> hit;
  final Lang lang;

  /// Stacked (guardian above its bar), for a panel beside the questions.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme, frac = maxHp == 0 ? 0.0 : hp / maxHp;
    final color = Color.lerp(Z.wrong, Z.correct, frac)!;
    final short = !vertical && MediaQuery.sizeOf(context).height < 900, side = short ? 88.0 : 150.0;
    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: vertical ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: hit,
          builder: (context, _) {
            final t = hit.value;
            final dx = t == 0 || t == 1 ? 0.0 : sin(t * pi * 8) * 18 * (1 - t);
            return Transform.translate(
              offset: Offset(dx, 0),
              child: SizedBox(width: side, height: side, child: CustomPaint(painter: _GuardianPainter(flash: t > 0 && t < 1 ? 1 - t : 0, health: frac))),
            );
          },
        ),
        const SizedBox(width: Z.gap, height: 12),
        _flexIf(
          !vertical,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: short || vertical ? text.bodyLarge : text.headlineMedium, maxLines: short ? 1 : 3, overflow: TextOverflow.ellipsis),
              SizedBox(height: short ? 4 : 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(Z.radius),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: frac),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, v, _) => LinearProgressIndicator(key: const ValueKey('bossHealth'), value: v, minHeight: short ? 22 : 40, color: color, backgroundColor: Colors.white12),
                ),
              ),
              if (!short) const SizedBox(height: 8),
              Text('${gt('bossHealth', lang)}: $hp / $maxHp', style: text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _flexIf(bool expand, Widget child) => expand ? Expanded(child: child) : child;

/// An original chapter guardian: a crystal block with a visor, its glow fading with its health
/// and flashing white when hit.
class _GuardianPainter extends CustomPainter {
  _GuardianPainter({required this.flash, required this.health});
  final double flash, health;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..lineTo(w * 0.9, h * 0.28)
      ..lineTo(w * 0.82, h * 0.86)
      ..lineTo(w * 0.5, h * 0.98)
      ..lineTo(w * 0.18, h * 0.86)
      ..lineTo(w * 0.1, h * 0.28)
      ..close();
    final base = Color.lerp(const Color(0xFF455A64), const Color(0xFF7B1FA2), health)!;
    canvas.drawPath(body, Paint()..color = Color.lerp(base, Colors.white, flash * 0.8)!);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Z.accent.withValues(alpha: 0.4 + 0.6 * health),
    );
    // Facets.
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white24;
    canvas.drawLine(Offset(w * 0.5, h * 0.04), Offset(w * 0.5, h * 0.98), facet);
    canvas.drawLine(Offset(w * 0.1, h * 0.28), Offset(w * 0.5, h * 0.5), facet);
    canvas.drawLine(Offset(w * 0.9, h * 0.28), Offset(w * 0.5, h * 0.5), facet);
    // Visor and eyes.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.36, w * 0.52, h * 0.16), const Radius.circular(12)), Paint()..color = Colors.black87);
    final eye = Paint()..color = Color.lerp(Z.wrong, Z.accent, 1 - health)!;
    canvas.drawCircle(Offset(w * 0.38, h * 0.44), w * 0.045, eye);
    canvas.drawCircle(Offset(w * 0.62, h * 0.44), w * 0.045, eye);
  }

  @override
  bool shouldRepaint(_GuardianPainter old) => old.flash != flash || old.health != health;
}
