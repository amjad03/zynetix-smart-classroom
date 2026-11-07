import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinetix_cs/kinetix_cs.dart' show WebRunner, RunRequest, RunResult, RunStatus, CodeLanguage;
import 'package:kinetix_ui/kinetix_ui.dart' show KxFonts;

import '../../core/theme.dart';
import '../../engine/model.dart';
import '../app/class_content.dart' show Program;
import '../app/help.dart';
import 'class_data.dart';
import 'class_kit.dart';
import 'strings.dart';

/// The coding lab for PUC Computer Science: a Python program in a large editor and the output it
/// prints. On a board with a WebView it really runs, offline, in Pyodide (CPython compiled to
/// WebAssembly, served from the app's own assets on 127.0.0.1 by kinetix_cs). Where Python cannot
/// run, the lab says so plainly and steps through the program's recorded run instead.
class CodingLabScreen extends StatefulWidget {
  const CodingLabScreen({super.key, required this.samples, this.programs = const [], this.runner, this.ran = false, this.line = 0});
  final ClassSamples samples;

  /// The programs to choose from (assets/classroom/programs.json); the sample's own when empty.
  final List<Program> programs;

  /// Tests pass a runner; by default the board's Python (null where there is no WebView).
  final WebRunner? runner;

  /// Show the recorded output at once (screenshots).
  final bool ran;

  /// The line highlighted as running (1-based), 0 for none.
  final int line;

  @override
  State<CodingLabScreen> createState() => _CodingLabScreenState();
}

class _CodingLabScreenState extends State<CodingLabScreen> {
  late final List<CodeSample> programs = widget.programs.isEmpty ? [widget.samples.code] : [for (final p in widget.programs) p.sample];
  late final List<String> files = widget.programs.isEmpty ? ['program.py'] : [for (final p in widget.programs) p.file];
  late final WebRunner runner = widget.runner ?? WebRunner();
  late final TextEditingController code = TextEditingController(text: programs.first.code);
  int pick = 0;

  /// Output lines shown, and whether they are from a real run or the recorded one.
  List<String> out = const [];
  String err = '';
  bool running = false, recorded = false, edited = false;
  int shown = 0;
  int? ms;
  String loading = '';
  StreamSubscription<String>? _load;

  CodeSample get c => programs[pick];

  @override
  void initState() {
    super.initState();
    code.addListener(() {
      final e = code.text != c.code;
      if (e != edited) setState(() => edited = e);
    });
    _load = runner.loading.listen((m) {
      if (mounted) setState(() => loading = m);
    });
    if (runner.available) runner.warm();
    if (widget.ran) {
      out = c.output;
      shown = out.length;
      recorded = true;
    }
  }

  @override
  void dispose() {
    _load?.cancel();
    if (widget.runner == null) runner.dispose();
    code.dispose();
    super.dispose();
  }

  void _choose(int i) => setState(() {
    pick = i;
    code.text = c.code;
    out = const [];
    err = '';
    shown = 0;
    recorded = false;
    ms = null;
  });

  Future<void> _run() async {
    setState(() {
      running = true;
      err = '';
    });
    final r = runner.available ? await runner.run(RunRequest(CodeLanguage.python, code.text)) : const RunResult(status: RunStatus.unavailable);
    if (!mounted) return;
    setState(() {
      running = false;
      if (r.status == RunStatus.unavailable) {
        // No Python on this board: the program's recorded run, one line at a time.
        recorded = true;
        out = c.output;
        shown = 1;
        ms = null;
      } else {
        recorded = false;
        out = r.stdout.trimRight().isEmpty ? const [] : r.stdout.trimRight().split('\n');
        err = r.stderr.trim().isNotEmpty ? r.stderr.trim() : (r.status == RunStatus.ok ? '' : (r.message ?? r.status.name));
        shown = out.length;
        ms = r.timeMs;
      }
    });
  }

  @override
  Widget build(BuildContext context) => LangBuilder(
    builder: (context, l) {
      final lines = code.text.split('\n');
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
                  Text(files[pick], style: mono.copyWith(fontSize: 32, height: 1.2)),
                  if (edited) Text('  •', style: mono.copyWith(fontSize: 32, height: 1.2, color: Z.stageAccent)),
                  const Spacer(),
                  StagePill(label: 'Python 3'),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 96,
                      padding: const EdgeInsets.only(right: 24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        for (var i = 0; i < lines.length; i++)
                          Container(
                            color: i + 1 == widget.line ? Z.stageAccent.withValues(alpha: 0.16) : null,
                            child: Text('${i + 1}', textAlign: TextAlign.right, style: mono.copyWith(color: Z.onStage3)),
                          ),
                      ]),
                    ),
                    Expanded(
                      child: Stack(children: [
                        // The colours under a transparent editor: type to change the program.
                        IgnorePointer(child: Text.rich(TextSpan(children: [for (final (i, line) in lines.indexed) ...[...highlightPython(line), if (i < lines.length - 1) const TextSpan(text: '\n')]]), style: mono, softWrap: false)),
                        TextField(
                          key: const ValueKey('codeEditor'),
                          controller: code,
                          maxLines: null,
                          style: mono.copyWith(color: Colors.transparent),
                          cursorColor: Z.stageAccent,
                          decoration: const InputDecoration.collapsed(hintText: ''),
                        ),
                      ]),
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
      final how = runner.available
          ? (l == Lang.kn ? 'ಈ ಬೋರ್ಡ್‌ನಲ್ಲೇ ಪೈಥಾನ್ ನಡೆಯುತ್ತದೆ, ಇಂಟರ್ನೆಟ್ ಬೇಡ' : 'Python runs on this board, no internet')
          : (l == Lang.kn ? 'ಈ ಸಾಧನದಲ್ಲಿ ಪೈಥಾನ್ ನಡೆಯದು: ದಾಖಲಿಸಿದ ಓಟವನ್ನು ಹಂತ ಹಂತವಾಗಿ ತೋರಿಸುತ್ತಿದೆ' : 'Python can’t run on this device: stepping through a recorded run');
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
                if (recorded && out.isNotEmpty) Text(l == Lang.kn ? 'ದಾಖಲಿಸಿದ ಓಟ' : 'Recorded run', key: const ValueKey('recordedRun'), style: zText(28, FontWeight.w600).copyWith(color: Z.orange)),
                if (!recorded && ms != null) Text(err.isEmpty ? '✓ ${(ms! / 1000).toStringAsFixed(2)} s' : '✗', style: zText(28, FontWeight.w600).copyWith(color: err.isEmpty ? Z.green : Z.orange)),
              ],
            ),
            const SizedBox(height: 12),
            Text(running && loading.isNotEmpty ? loading : how, style: zText(24, FontWeight.w500).copyWith(color: Z.onStage3)),
            if (recorded && edited) Text(l == Lang.kn ? 'ನಿಮ್ಮ ಬದಲಾವಣೆಗಳು ಇಲ್ಲಿ ನಡೆಯುವುದಿಲ್ಲ; ಮೂಲ ಪ್ರೋಗ್ರಾಂನ ಓಟ.' : 'Your changes can’t run here; this is the original program’s run.', style: zText(24, FontWeight.w500).copyWith(color: Z.orange)),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (running) Text(l == Lang.kn ? 'ನಡೆಯುತ್ತಿದೆ…' : 'Running…', style: mono.copyWith(color: Z.onStage3)),
                    if (!running && out.isEmpty && err.isEmpty) Text('▶ ${ct('run', l)}', style: mono.copyWith(color: Z.onStage3)),
                    for (final o in out.take(shown)) Text(o, style: mono.copyWith(fontSize: 38, color: const Color(0xFFB8F5D6))),
                    if (err.isNotEmpty) Text(err, style: mono.copyWith(fontSize: 32, color: const Color(0xFFFFB4A8))),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      final pickers = Wrap(spacing: 14, runSpacing: 14, children: [
        for (final (i, p) in programs.indexed)
          ChoiceChip(
            key: ValueKey('program-$i'),
            label: Text(p.title.t(l), style: zText(28, FontWeight.w600)),
            selected: i == pick,
            onSelected: (_) => _choose(i),
          ),
      ]);
      return ClassScaffold(
        crumbs: [c.chapter.t(l)],
        title: '${ct('codingLab', l)} · ${c.title.t(l)}',
        trailing: [BarChip(ct('runsOffline', l), icon: Icons.cloud_off_outlined, color: Z.correctLabel, background: Z.correctBg)],
        help: () => HelpInfo(
          next: L10n(recorded && shown < out.length ? 'Tap Next line to show the next line of the recorded run.' : 'Tap Run to run the program. Change the code and run it again.', recorded && shown < out.length ? 'ದಾಖಲಿಸಿದ ಓಟದ ಮುಂದಿನ ಸಾಲಿಗೆ “ಮುಂದಿನ ಸಾಲು” ಒತ್ತಿ.' : 'ಪ್ರೋಗ್ರಾಂ ನಡೆಸಲು “ರನ್” ಒತ್ತಿ. ಕೋಡ್ ಬದಲಿಸಿ ಮತ್ತೆ ನಡೆಸಿ.'),
        ),
        bottomLeft: [
          BigButton(key: const ValueKey('codeRun'), icon: Icons.play_arrow_rounded, label: ct('run', l), onPressed: running ? null : _run),
          BigButton(key: const ValueKey('codeStep'), icon: Icons.skip_next_outlined, label: ct('stepLine', l), filled: false, onPressed: recorded && shown < out.length ? () => setState(() => shown++) : null),
          BigButton(icon: Icons.restart_alt, label: ct('reset', l), filled: false, onPressed: () => _choose(pick)),
        ],
        bottomRight: const [],
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (programs.length > 1) ...[pickers, const SizedBox(height: 24)], Expanded(child: editor)])),
            const SizedBox(width: 32),
            Expanded(flex: 9, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [task, const SizedBox(height: 28), Expanded(child: output), SizedBox(width: 1, height: 1, child: runner.view())])),
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
