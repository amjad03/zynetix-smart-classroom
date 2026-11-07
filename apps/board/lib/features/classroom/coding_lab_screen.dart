import 'package:flutter/material.dart';
import 'package:kinetix_ui/kinetix_ui.dart' show KxFonts;

import '../../core/theme.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'strings.dart';

/// The coding lab for PUC Computer Science: a Python program in a large editor and the output it
/// prints, run on the board itself with no internet. (This sample shows a stored run; the board's
/// Python runner comes with the full lab.)
class CodingLabScreen extends StatefulWidget {
  const CodingLabScreen({super.key, required this.samples, this.ran = true, this.line = 6});
  final ClassSamples samples;
  final bool ran;

  /// The line highlighted as running (1-based).
  final int line;

  @override
  State<CodingLabScreen> createState() => _CodingLabScreenState();
}

class _CodingLabScreenState extends State<CodingLabScreen> {
  late bool ran = widget.ran;

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final c = widget.samples.code;
      final lines = c.code.split('\n');
      final mono = TextStyle(fontFamily: KxFonts.code, fontFamilyFallback: ZFonts.fallback, fontSize: 40, height: 1.6, color: Z.onStage);
      final editor = Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Z.stage, borderRadius: BorderRadius.circular(Z.stageRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Z.transport,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 36, color: Z.onStage2),
                  const SizedBox(width: 14),
                  Text('bubble_sort.py', style: mono.copyWith(fontSize: 32, height: 1.2)),
                  const Spacer(),
                  StagePill(label: 'Python 3'),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, line) in lines.indexed)
                      Container(
                        color: i + 1 == widget.line ? Z.stageAccent.withValues(alpha: 0.16) : null,
                        padding: const EdgeInsets.only(right: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 96,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(border: Border(left: BorderSide(color: i + 1 == widget.line ? Z.stageAccent : Colors.transparent, width: 8))),
                              child: Text('${i + 1}', textAlign: TextAlign.right, style: mono.copyWith(color: Z.onStage3)),
                            ),
                            Expanded(child: Text.rich(TextSpan(children: highlightPython(line)), style: mono, softWrap: false, overflow: TextOverflow.fade)),
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
      final task = ZPanel(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker(ct('task', l)),
            const SizedBox(height: 10),
            Text(c.task.t(l), style: zText(36, FontWeight.w500).copyWith(height: 1.4)),
          ],
        ),
      );
      final output = Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: const Color(0xFF0E1315), borderRadius: BorderRadius.circular(Z.panelRadius)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, size: 36, color: Z.onStage2),
                const SizedBox(width: 12),
                Text(ct('output', l), style: zText(30, FontWeight.w600).copyWith(color: Z.onStage2)),
                const Spacer(),
                if (ran) Text('✓ 0.01 s', style: zText(28, FontWeight.w600).copyWith(color: Z.green)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ran)
                      for (final o in c.output) Text(o, style: mono.copyWith(fontSize: 38, color: const Color(0xFFB8F5D6)))
                    else
                      Text('▶ ${ct('run', l)}', style: mono.copyWith(color: Z.onStage3)),
                  ],
                ),
              ),
            ),
            if (c.watch.isNotEmpty) ...[
              const Divider(height: 40, thickness: 2, color: Z.stageTrack),
              Text('${ct('watchVars', l)} ${widget.line}', style: zText(28, FontWeight.w600).copyWith(color: Z.onStage2)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final w in c.watch)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      decoration: BoxDecoration(color: Z.stageAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Z.radius)),
                      child: Text(w, style: mono.copyWith(fontSize: 34, height: 1.3, color: Z.stageAccent)),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
      final stats = Row(
        children: [
          Expanded(child: ZReadout(label: ct('passes', l), value: ran ? '4' : '–', valueSize: 56)),
          const SizedBox(width: 20),
          Expanded(child: ZReadout(label: ct('comparisons', l), value: ran ? '10' : '–', valueSize: 56)),
          const SizedBox(width: 20),
          Expanded(child: ZReadout(label: ct('swaps', l), value: ran ? '7' : '–', valueSize: 56)),
        ],
      );
      return ClassScaffold(
        crumbs: [c.chapter.t(l)],
        title: '${ct('codingLab', l)} · ${c.title.t(l)}',
        trailing: [BarChip(ct('runsOffline', l), icon: Icons.cloud_off_outlined, color: Z.correctLabel, background: Z.correctBg)],
        bottomLeft: [
          BigButton(key: const ValueKey('codeRun'), icon: Icons.play_arrow_rounded, label: ct('run', l), onPressed: () => setState(() => ran = true)),
          BigButton(icon: Icons.skip_next_outlined, label: ct('stepLine', l), filled: false, onPressed: () {}),
          BigButton(icon: Icons.restart_alt, label: ct('reset', l), filled: false, onPressed: () => setState(() => ran = false)),
        ],
        bottomRight: const [],
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 12, child: editor),
            const SizedBox(width: 32),
            Expanded(flex: 9, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [task, const SizedBox(height: 28), stats, const SizedBox(height: 28), Expanded(child: output)])),
          ],
        ),
      );
    },
  );
}

const _keywords = {'def', 'for', 'in', 'if', 'elif', 'else', 'while', 'return', 'import', 'from', 'and', 'or', 'not', 'True', 'False', 'None', 'break', 'continue', 'pass', 'class'};
const _builtins = {'print', 'range', 'len', 'input', 'int', 'str', 'list', 'min', 'max'};

/// Python colouring for the dark stage: keywords purple, built-ins sky, strings green, numbers
/// orange, comments grey.
List<TextSpan> highlightPython(String line) {
  final out = <TextSpan>[];
  final re = RegExp(r'(#.*$)|("[^"]*"|' "'[^']*')" r'|(\b\d+(?:\.\d+)?\b)|(\b[A-Za-z_]\w*\b)|(\s+)|(.)');
  for (final m in re.allMatches(line)) {
    final t = m[0]!;
    Color? c;
    if (m[1] != null) {
      c = Z.onStage3;
    } else if (m[2] != null) {
      c = Z.green;
    } else if (m[3] != null) {
      c = Z.orange;
    } else if (m[4] != null) {
      c = _keywords.contains(t) ? Z.purple : (_builtins.contains(t) ? Z.sky : null);
    }
    out.add(TextSpan(text: t, style: c == null ? null : TextStyle(color: c)));
  }
  return out;
}
