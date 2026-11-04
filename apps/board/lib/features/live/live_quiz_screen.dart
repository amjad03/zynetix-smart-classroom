import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../blocks/math_text.dart';
import '../../core/services.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../engine/model.dart';
import '../../engine/session_log.dart';
import '../participation.dart' show formatNumber;
import 'chapter_picker.dart';
import 'live_server.dart';
import 'strings.dart';

enum LiveStage { pick, run, done }

/// Phone quiz: the board serves a page on its own Wi-Fi (no internet), shows a QR code, the
/// address and a 4-digit room code; each student answers on a phone with their roll number. The
/// board shows how many have answered and a histogram, then reveals, and every phone's answer is
/// recorded for its roll number (source 'phone').
///
/// With [questions] (and their [pack]) it starts straight away; otherwise the teacher picks a
/// chapter first. [server] and [listen] are for tests (a server that is never bound to a port).
class LiveQuizScreen extends StatefulWidget {
  const LiveQuizScreen({super.key, this.questions, this.pack, this.server, this.listen = true, this.port = 8080});
  final List<Question>? questions;
  final InstalledPack? pack;
  final LiveServer? server;
  final bool listen;
  final int port;

  @override
  State<LiveQuizScreen> createState() => LiveQuizScreenState();
}

class LiveQuizScreenState extends State<LiveQuizScreen> {
  late final Services s = ServicesScope.of(context);
  LiveStage stage = LiveStage.pick;
  List<Question> questions = const [];
  SessionRecorder? recorder;
  LiveServer? server;
  String? url;
  bool noNetwork = false, failed = false;
  int i = 0;

  /// Right and answered per question, filled at each reveal.
  final results = <(int right, int total)>[];

  Question get question => questions[i];

  @override
  void initState() {
    super.initState();
    if (widget.questions != null && widget.questions!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) start(widget.pack, widget.questions!);
      });
    }
  }

  @override
  void dispose() {
    recorder?.close(completed: stage == LiveStage.done);
    server?.removeListener(_changed);
    if (widget.server == null) {
      server?.dispose();
    } else {
      unawaited(server?.stop());
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> start(InstalledPack? pack, List<Question> qs) async {
    if (qs.isEmpty) return;
    final first = qs.first;
    final chapterId = pack?.chapter.id ?? first.chapterId ?? '';
    recorder = SessionRecorder.raw(
      outbox: s.outbox,
      sectionId: s.config.sectionId,
      mode: 'teacher',
      chapterId: chapterId,
      topicId: first.topicId ?? pack?.chapter.topics.firstOrNull?.id ?? chapterId,
      lessonId: 'live.phones.$chapterId',
      packVersion: pack?.version ?? '0.0.0',
      now: s.clock,
      mastery: s.mastery,
    );
    final srv = server = widget.server ?? LiveServer(rollCount: s.config.rollCount, lang: s.config.lang);
    srv.addListener(_changed);
    setState(() {
      questions = qs;
      i = 0;
      results.clear();
      stage = LiveStage.run;
    });
    srv.open(qs.first);
    if (!widget.listen) {
      setState(() => url = 'http://127.0.0.1:${widget.port}/');
      return;
    }
    try {
      await srv.start(port: widget.port);
      final ips = await LiveServer.lanAddresses();
      if (!mounted) return;
      setState(() {
        noNetwork = ips.isEmpty;
        url = 'http://${ips.isEmpty ? 'localhost' : ips.first}:${srv.port}/';
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  /// Closes answering, shows right or wrong on every phone and records each roll's answer.
  void reveal() {
    final srv = server!;
    if (srv.phase != LivePhase.open) return;
    final answers = srv.answers;
    final res = srv.reveal();
    final q = question;
    for (final e in answers.entries) {
      recorder!.answer(questionId: q.id, mode: QuizMode.monitor, roll: e.key, chosen: e.value.chosen, correct: res[e.key]!, topicId: q.topicId, chapterId: q.chapterId, source: 'phone');
    }
    setState(() => results.add((res.values.where((v) => v).length, res.length)));
  }

  void next() {
    if (i + 1 >= questions.length) {
      recorder?.close(completed: true);
      setState(() => stage = LiveStage.done);
      return;
    }
    setState(() => i++);
    server!.open(question);
  }

  @override
  Widget build(BuildContext context) {
    final l = s.config.lang, text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Z.tap + 16,
        leading: IconButton(key: const ValueKey('liveBack'), iconSize: 56, icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(
          stage == LiveStage.run ? '${ltr('phones', l)} · ${i + 1} / ${questions.length}' : ltr('phones', l),
          style: context.narrow ? text.headlineMedium : text.headlineLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(context.narrow ? 16 : 32),
        child: switch (stage) {
          LiveStage.pick => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ltr('phonesSub', l), style: text.bodyLarge),
              const SizedBox(height: 16),
              Expanded(child: ChapterTestPicker(onPick: start)),
            ],
          ),
          LiveStage.run => _run(l, text),
          LiveStage.done => _done(l, text),
        },
      ),
    );
  }

  Widget _join(Lang l, TextTheme text, double qrSize) {
    final srv = server!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (url != null)
          Container(
            color: Colors.white,
            child: QrImageView(key: const ValueKey('qr'), data: '$url?room=${srv.roomCode}', size: qrSize, backgroundColor: Colors.white),
          )
        else
          SizedBox(width: qrSize, height: qrSize, child: Center(child: failed ? const Icon(Icons.wifi_off, size: 96) : const CircularProgressIndicator())),
        const SizedBox(height: 12),
        if (failed) Text(ltr('serverFailed', l), style: text.bodyMedium?.copyWith(color: Z.wrong), textAlign: TextAlign.center),
        if (noNetwork) Text(ltr('noNetwork', l), style: text.bodyMedium?.copyWith(color: Z.wrong), textAlign: TextAlign.center),
        Text(ltr('scanToJoin', l), style: text.bodyMedium, textAlign: TextAlign.center),
        if (url != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(url!.replaceFirst('http://', '').replaceFirst(RegExp(r'/$'), ''), key: const ValueKey('liveUrl'), style: text.headlineMedium?.copyWith(color: Z.accent, fontWeight: FontWeight.w800)),
          ),
        const SizedBox(height: 8),
        Text(ltr('roomCode', l), style: text.bodyMedium),
        Text(
          srv.roomCode,
          key: const ValueKey('roomCode'),
          style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w900, letterSpacing: 12, height: 1.1),
        ),
        Text('${srv.joined.length} ${ltr('joined', l)}', key: const ValueKey('joined'), style: text.bodyLarge),
      ],
    );
  }

  Widget _run(Lang l, TextTheme text) {
    final portrait = context.portrait;
    return LayoutBuilder(
      builder: (context, c) {
        if (portrait) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: min(560, c.maxHeight * 0.42),
                child: SingleChildScrollView(child: Center(child: _join(l, text, min(300, c.maxWidth * 0.5)))),
              ),
              const Divider(height: 32),
              Expanded(child: _question(l, text)),
            ],
          );
        }
        final side = min(560.0, c.maxWidth * 0.34);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: side,
              child: SingleChildScrollView(child: _join(l, text, min(side - 40, max(160.0, c.maxHeight - 420)))),
            ),
            const VerticalDivider(width: 48),
            Expanded(child: _question(l, text)),
          ],
        );
      },
    );
  }

  Widget _question(Lang l, TextTheme text) {
    final srv = server!, q = question;
    final revealed = srv.phase == LivePhase.revealed;
    final answered = srv.answers.length;
    final res = revealed && results.length > i ? results[i] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: MathText(q.stem.t(l), style: text.headlineMedium?.copyWith(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          res == null ? '$answered / ${s.config.rollCount} ${ltr('answered', l)}' : '${tr('correct', l)}: ${res.$1} / ${res.$2}',
          key: const ValueKey('answeredCount'),
          style: text.headlineMedium?.copyWith(color: res == null ? Z.accent : Z.correct, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Expanded(flex: 2, child: q.isNumeric ? _values(q, revealed, l, text) : _histogram(q, revealed, l, text)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: revealed
              ? BigButton(key: const ValueKey('liveNext'), icon: i + 1 >= questions.length ? Icons.done_all : Icons.arrow_forward, label: i + 1 >= questions.length ? tr('finish', l) : tr('nextQuestion', l), onPressed: next)
              : BigButton(key: const ValueKey('liveReveal'), icon: Icons.visibility_outlined, label: tr('reveal', l), onPressed: reveal),
        ),
      ],
    );
  }

  Widget _histogram(Question q, bool revealed, Lang l, TextTheme text) {
    final h = server!.histogram;
    final n = min(4, q.options.length);
    final top = max(1, h.take(n).fold(0, max));
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var k = 0; k < n; k++) ...[
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: revealed && q.correctSet.contains(k) ? Z.correct : scheme.surfaceContainerHighest,
                  child: Text('ABCD'[k], style: zText(30, FontWeight.w600).copyWith(color: revealed && q.correctSet.contains(k) ? Colors.white : Z.ink2)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: double.infinity,
                          decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: c.maxWidth * h[k] / top,
                          decoration: BoxDecoration(
                            color: !revealed ? const Color(0xFFC9D7FA) : (q.correctSet.contains(k) ? const Color(0xFFBFE5D3) : Z.wrongBg),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(q.options[k].t(l), style: text.bodyLarge?.copyWith(fontSize: 28), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text('${h[k]}', key: ValueKey('bar-$k'), textAlign: TextAlign.end, style: zText(44, FontWeight.w600)),
                ),
              ],
            ),
          ),
          if (k < n - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _values(Question q, bool revealed, Lang l, TextTheme text) {
    final vals = server!.values;
    final tol = q.tolerance ?? 0;
    return ListView(
      children: [
        if (revealed) Text('${tr('correctAnswer', l)}: ${formatNumber(q.numericAnswer ?? double.nan)}${tol > 0 ? ' ± ${formatNumber(tol)}' : ''}', style: text.headlineMedium?.copyWith(color: Z.correct)),
        if (vals.isEmpty) Text(ltr('noAnswers', l), style: text.bodyLarge),
        for (final (v, n) in vals.take(6))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${formatNumber(v)}   ×$n',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: !revealed ? null : (LiveAnswer(value: v).correctFor(q) ? Z.correct : Z.wrong)),
            ),
          ),
      ],
    );
  }

  Widget _done(Lang l, TextTheme text) {
    final right = results.fold(0, (a, r) => a + r.$1), total = results.fold(0, (a, r) => a + r.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ltr('classResult', l), style: text.headlineMedium),
        Text(total == 0 ? '—' : '${(right * 100 / total).round()}%', key: const ValueKey('liveScore'), style: text.displayLarge?.copyWith(color: Z.accent)),
        Text('${server?.joined.length ?? 0} ${ltr('joined', l)}', style: text.bodyLarge),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              for (var k = 0; k < results.length; k++)
                ListTile(
                  title: MathText('${k + 1}. ${questions[k].stem.t(l)}', style: text.bodyLarge),
                  trailing: Text('${results[k].$1} / ${results[k].$2}', style: text.headlineMedium),
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: BigButton(key: const ValueKey('liveDone'), icon: Icons.done_all, label: tr('done', l), onPressed: () => Navigator.pop(context)),
        ),
      ],
    );
  }
}
