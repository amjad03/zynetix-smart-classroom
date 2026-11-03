import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';
import 'player.dart';
import 'self_learning.dart';
import 'settings.dart';
import 'teacher_mode.dart';

/// Home: two big buttons and a one-tap Continue card.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return ListenableBuilder(
      listenable: s.config,
      builder: (context, _) {
        final l = s.config.lang, text = Theme.of(context).textTheme;
        final next = s.nextTopic();
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                StatusBar(lang: l),
                const Spacer(),
                if (next != null)
                  _ContinueCard(
                    title: '${subjectName(next.pack.chapter.subject, l)} · ${next.pack.chapter.title.t(l)}',
                    topic: next.lesson.title.t(l),
                    lang: l,
                    onTap: () => openLesson(context, next.pack, next.lesson),
                  ),
                const SizedBox(height: 40),
                SizedBox(
                  height: 300,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(
                      child: _ModeButton(
                        key: const ValueKey('teacherMode'),
                        icon: Icons.co_present_outlined,
                        title: tr('teacherMode', l),
                        sub: tr('teacherModeSub', l),
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TeacherModeScreen())),
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: _ModeButton(
                        key: const ValueKey('selfLearning'),
                        icon: Icons.smart_display_outlined,
                        title: tr('selfLearning', l),
                        sub: tr('selfLearningSub', l),
                        color: const Color(0xFF6A1B9A),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SelfLearningStartScreen())),
                      ),
                    ),
                  ]),
                ),
                const Spacer(),
                Text('${s.config.collegeName} · ${tr('offlineOk', l)}', style: text.bodyMedium, textAlign: TextAlign.center),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// Opens the lesson player in Teacher Mode.
void openLesson(BuildContext context, InstalledPack pack, Lesson lesson) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LessonPlayerScreen(pack: pack, lesson: lesson)));

/// Section, clock and the EN / ಕನ್ನಡ switch, at the top of every screen outside a lesson.
class StatusBar extends StatefulWidget {
  const StatusBar({super.key, required this.lang});
  final Lang lang;
  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context), now = s.clock();
    final text = Theme.of(context).textTheme;
    return Row(children: [
      Text('Zynetix', style: text.headlineLarge?.copyWith(color: Z.accent)),
      const SizedBox(width: 24),
      Text(s.config.sectionLabel, style: text.headlineMedium),
      const Spacer(),
      // Long press (IT / teacher only, behind the PIN): settings.
      GestureDetector(
        onLongPress: () => openSettings(context),
        child: Text('${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}', style: text.headlineMedium),
      ),
      const SizedBox(width: 24),
      SegmentedButton<Lang>(
        style: SegmentedButton.styleFrom(minimumSize: const Size(140, Z.tap), textStyle: const TextStyle(fontSize: 30)),
        segments: const [ButtonSegment(value: Lang.en, label: Text('EN')), ButtonSegment(value: Lang.kn, label: Text('ಕನ್ನಡ'))],
        selected: {widget.lang},
        showSelectedIcon: false,
        onSelectionChanged: (v) => s.config.setLang(v.first),
      ),
    ]);
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.title, required this.topic, required this.lang, required this.onTap});
  final String title, topic;
  final Lang lang;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(Z.radius),
      child: InkWell(
        key: const ValueKey('continue'),
        borderRadius: BorderRadius.circular(Z.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Row(children: [
            const Icon(Icons.play_circle_fill, size: 110, color: Z.accent),
            const SizedBox(width: 32),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${tr('continue', lang)} · $title', style: text.bodyLarge),
                Text(topic, style: text.headlineLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({super.key, required this.icon, required this.title, required this.sub, required this.color, required this.onTap});
  final IconData icon;
  final String title, sub;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(40),
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(children: [
              Icon(icon, size: 140, color: Colors.white),
              const SizedBox(width: 32),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(sub, style: const TextStyle(fontSize: 32, color: Colors.white70)),
                ]),
                ),
              ),
            ]),
          ),
        ),
      );
}
