import 'package:flutter/material.dart';

import '../../blocks/math_text.dart';
import '../../core/theme.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'strings.dart';

/// Ask ZYN-AI, a panel for the teacher: a question by voice or typed, answered hint first so the
/// class thinks before it is told. Online, ZYN-AI answers; offline (the board's usual state), the
/// panel shows the current lesson's own hints instead. Students never use it on their own.
class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key, required this.samples, this.online = true});
  final ClassSamples samples;
  final bool online;

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  int hints = 1;
  bool answer = false;

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final a = widget.samples.askAi;
      final online = widget.online;
      final banner = Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 26),
        decoration: BoxDecoration(color: online ? Z.correctBg : Z.highlight, borderRadius: BorderRadius.circular(Z.panelRadius)),
        child: Row(
          children: [
            Icon(online ? Icons.wifi : Icons.cloud_off_outlined, size: 48, color: online ? Z.correct : Z.wrongText),
            const SizedBox(width: 24),
            Expanded(child: Text(online ? ct('online', l) : ct('offlineBanner', l), key: const ValueKey('aiBanner'), style: zText(36, FontWeight.w600).copyWith(color: online ? Z.correctLabel : Z.wrongText))),
            if (!online) Text(ct('whenOnline', l), style: zText(28, FontWeight.w500).copyWith(color: Z.wrongText)),
          ],
        ),
      );
      final ask = Row(
        children: [
          Material(
            color: Z.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {},
              child: const SizedBox.square(dimension: 132, child: Icon(Icons.mic, size: 68, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 36),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(color: Z.tile, borderRadius: BorderRadius.circular(Z.radius), border: Border.all(color: Z.primary, width: 3)),
              child: Text(a.question.t(l), style: zText(38, FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 20),
          BigButton(icon: Icons.send_rounded, label: ct('ask', l), onPressed: () {}),
        ],
      );
      Widget hintCard(int i, String text, {bool lesson = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(color: lesson ? Z.tagBg : Z.highlight, borderRadius: BorderRadius.circular(Z.radius)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(lesson ? Icons.menu_book_outlined : Icons.lightbulb_outline, size: 52, color: lesson ? Z.primary : Z.star),
              const SizedBox(width: 24),
              Expanded(child: MathText(text, style: zText(40, FontWeight.w500).copyWith(height: 1.4))),
            ],
          ),
        ),
      );
      final source = online ? a.hints : a.offlineHints;
      final shown = online ? hints.clamp(1, source.length) : source.length;
      final main = ZPanel(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ask,
            const SizedBox(height: 36),
            Kicker(ct('teacherAsked', l)),
            const SizedBox(height: 6),
            Text(a.question.t(l), style: zTitle(52)),
            const SizedBox(height: 28),
            if (!online) ...[Text(ct('fromLesson', l, {'l': a.lesson.t(l)}), style: zText(30, FontWeight.w600).copyWith(color: Z.primary)), const SizedBox(height: 16)],
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < shown; i++) hintCard(i, source[i].t(l), lesson: !online),
                    if (online && answer)
                      Container(
                        key: const ValueKey('aiAnswer'),
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(color: Z.correctBg, borderRadius: BorderRadius.circular(Z.radius), border: Border.all(color: Z.correct, width: 3)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Kicker(ct('answerAi', l), color: Z.correctLabel),
                            const SizedBox(height: 10),
                            MathText(a.answer.t(l), style: zText(38, FontWeight.w400).copyWith(height: 1.45)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      final side = ZPanel(
        padding: const EdgeInsets.all(44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: Z.highlight, borderRadius: BorderRadius.circular(Z.radius)),
                  child: const Icon(Icons.auto_awesome, size: 52, color: Z.wrongText),
                ),
                const SizedBox(width: 24),
                Expanded(child: Text('ZYN-AI', style: zTitle(48, FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 28),
            for (final (icon, text) in [(Icons.lightbulb_outline, ct('hintsFirst', l)), (Icons.co_present_outlined, ct('teacherOnly', l)), (Icons.shield_outlined, ct('privacy', l))])
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 40, color: Z.muted),
                    const SizedBox(width: 18),
                    Expanded(child: Text(text, style: zText(30, FontWeight.w500).copyWith(color: Z.ink2, height: 1.4))),
                  ],
                ),
              ),
            const Spacer(),
            if (online) ...[
              BigButton(key: const ValueKey('aiHint'), icon: Icons.lightbulb_outline, label: ct('nextHint', l), filled: false, onPressed: hints < source.length ? () => setState(() => hints++) : null),
              const SizedBox(height: 20),
              BigButton(key: const ValueKey('aiAnswerBtn'), icon: Icons.visibility_outlined, label: ct('fullAnswer', l), onPressed: answer ? null : () => setState(() => answer = true)),
            ] else
              BigButton(icon: Icons.play_lesson_outlined, label: a.lesson.t(l), filled: false, onPressed: () {}),
          ],
        ),
      );
      return ClassScaffold(
        crumbs: [widget.samples.subject.t(l), widget.samples.year.t(l)],
        title: ct('askAi', l),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            banner,
            const SizedBox(height: 32),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 13, child: main), const SizedBox(width: 32), Expanded(flex: 6, child: side)])),
          ],
        ),
      );
    },
  );
}
