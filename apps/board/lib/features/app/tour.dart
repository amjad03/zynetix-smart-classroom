import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services.dart';
import '../../engine/auto_play.dart';
import '../../engine/model.dart';
import '../../engine/voice.dart';
import 'help.dart';
import 'kit.dart';

/// One step of the voice guide: what to point at, and what to say (English is spoken from a
/// bundled clip; Kannada is shown as a caption until its voice is recorded).
class GuideStep {
  const GuideStep(this.id, this.target, this.say);
  final String id;
  final GlobalKey target;
  final L10n say;
}

/// The four steps of the first-use guide on Home.
List<GuideStep> guideSteps({required GlobalKey start, required GlobalKey cards, required GlobalKey toggle, required GlobalKey help}) => [
  GuideStep('guide-1', start, const L10n('Tap the big blue button to start your class.', 'ನಿಮ್ಮ ತರಗತಿ ಪ್ರಾರಂಭಿಸಲು ದೊಡ್ಡ ನೀಲಿ ಬಟನ್ ಒತ್ತಿ.')),
  GuideStep('guide-2', cards, const L10n('These four cards teach any chapter, open the board, quiz the class, or find a 3D model.', 'ಈ ನಾಲ್ಕು ಕಾರ್ಡ್‌ಗಳು: ಯಾವುದೇ ಪಾಠ, ಬೋರ್ಡ್, ಪ್ರಶ್ನೋತ್ತರ, ಅಥವಾ 3D ಮಾದರಿ.')),
  GuideStep('guide-3', toggle, const L10n('When you feel confident, switch on Show all tools.', 'ನಿಮಗೆ ಭರವಸೆ ಬಂದಾಗ, “ಎಲ್ಲಾ ಸಾಧನಗಳನ್ನು ತೋರಿಸಿ” ಆನ್ ಮಾಡಿ.')),
  GuideStep('guide-4', help, const L10n('Stuck? Tap What do I do now? It tells you the next step, and can undo.', 'ಸಿಲುಕಿದ್ದೀರಾ? “ಈಗ ನಾನು ಏನು ಮಾಡಲಿ?” ಒತ್ತಿ. ಮುಂದಿನ ಹಂತ ಹೇಳುತ್ತದೆ, ರದ್ದೂ ಮಾಡುತ್ತದೆ.')),
];

/// The bundled guide clips (assets/guide/guide.json: id → file and length in ms).
class GuideClips {
  static Map<String, VoiceClip>? _clips;
  static Future<Map<String, VoiceClip>> load() async {
    if (_clips != null) return _clips!;
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/guide/guide.json')) as Map<String, dynamic>;
      _clips = {
        for (final e in ((j['en'] as Map?) ?? const {}).entries)
          '${e.key}': VoiceClip('asset:assets/guide/${(e.value as Map)['file']}', ((e.value as Map)['ms'] as num).toInt()),
      };
    } catch (_) {
      _clips = {};
    }
    return _clips!;
  }
}

/// 04 · The voice guide: the screen dims, a spotlight and a pointing hand on the one thing to
/// look at, a big caption, the voice, Step n of 4, Next, Skip and mute.
class GuideTour extends StatefulWidget {
  const GuideTour({super.key, required this.steps, required this.onDone});
  final List<GuideStep> steps;
  final VoidCallback onDone;
  @override
  State<GuideTour> createState() => _GuideTourState();
}

class _GuideTourState extends State<GuideTour> {
  int i = 0;
  Rect? _r;
  VoicePlayer? _player;
  bool _speaking = false;
  late Lang _lang;
  bool _started = false;

  Services get s => ServicesScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _lang = s.config.lang;
      _player = s.voicePlayer();
      _enter();
    }
  }

  @override
  void dispose() {
    final p = _player;
    _player = null;
    if (p != null) unawaited(p.stop().then((_) => p.dispose()));
    super.dispose();
  }

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = widget.steps[i].target.currentContext?.findRenderObject() as RenderBox?;
      final me = context.findRenderObject() as RenderBox?;
      if (t == null || me == null || !t.attached) return;
      final r = rectIn(me, t);
      if (r != _r) setState(() => _r = r);
    });
  }

  Future<void> _enter() async {
    _measure();
    await _player?.stop();
    final muted = s.school.guideMuted;
    final step = widget.steps[i];
    // English is spoken; Kannada voice comes later (the caption is shown).
    if (muted || _lang != Lang.en) {
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final clip = (await GuideClips.load())[step.id];
    if (clip == null || !mounted) return;
    final at = i;
    setState(() => _speaking = true);
    await _player?.play(clip);
    if (mounted && at == i) setState(() => _speaking = false);
  }

  void _go(int to) {
    if (to >= widget.steps.length) {
      _finish();
      return;
    }
    setState(() => i = to);
    _enter();
  }

  void _finish() {
    unawaited(_player?.stop());
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    final r = _r;
    if (r == null) return const ColoredBox(color: Color(0xE60B0D33));
    final l = _lang, step = widget.steps[i], muted = s.school.guideMuted;
    final phone = usePhoneLayout(context);
    final k = phone ? .6 : 1.0;
    final other = l == Lang.en ? Lang.kn : Lang.en;
    final card = Container(
      key: const ValueKey('tourCard'),
      padding: EdgeInsets.fromLTRB(60 * k, 52 * k, 60 * k, 52 * k),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(56 * k), boxShadow: S.shadow),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tr(l, 'Step ${i + 1} of ${widget.steps.length}', 'ಹಂತ ${i + 1} / ${widget.steps.length}'), style: tx(36 * k, c: S.violet, w: FontWeight.w700, h: 1.1)),
          SizedBox(width: 24 * k),
          for (var j = 0; j < widget.steps.length; j++)
            Container(margin: EdgeInsets.only(right: 12 * k), width: (j == i ? 64 : 22) * k, height: 22 * k, decoration: BoxDecoration(color: j == i ? S.violet : S.line, borderRadius: BorderRadius.circular(99))),
          const Spacer(),
          if (!phone) _Speaking(on: _speaking, lang: l),
        ]),
        SizedBox(height: 30 * k),
        Text(step.say.t(l), key: const ValueKey('tourSay'), style: hd(84 * k, l: l)),
        SizedBox(height: 18 * k),
        Text(step.say.t(other), style: tx(38 * k, c: S.muted)),
        if (l == Lang.kn) ...[SizedBox(height: 10 * k), Text('ಕನ್ನಡ ಧ್ವನಿ ಶೀಘ್ರದಲ್ಲೇ ಬರಲಿದೆ · Kannada voice coming soon', style: tx(28 * k, c: S.muted))],
        SizedBox(height: 40 * k),
        Wrap(spacing: 20 * k, runSpacing: 20 * k, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ZxButton(
            muted ? tr(l, 'Voice on', 'ಧ್ವನಿ ಆನ್') : tr(l, 'Mute voice', 'ಧ್ವನಿ ನಿಲ್ಲಿಸಿ'),
            key: const ValueKey('tourMute'),
            icon: muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            bg: S.mist,
            fg: S.ink,
            height: 120 * k,
            size: 36 * k,
            onTap: () {
              s.school.setGuideMuted(!muted);
              if (!muted) {
                unawaited(_player?.stop());
                setState(() => _speaking = false);
              } else {
                _enter();
              }
            },
          ),
          if (s.config.kannadaOffered)
            Container(
              height: 120 * k,
              padding: EdgeInsets.all(10 * k),
              decoration: BoxDecoration(color: S.mist, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final (v, name) in [(Lang.en, 'English'), (Lang.kn, 'ಕನ್ನಡ')])
                  Press(
                    key: ValueKey('tourLang-${v.name}'),
                    onTap: () {
                      setState(() => _lang = v);
                      s.config.setLang(v);
                      _enter();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 40 * k),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: v == l ? S.ink : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                      child: Text(name, style: tx(34 * k, c: v == l ? Colors.white : S.ink, w: FontWeight.w700, h: 1)),
                    ),
                  ),
              ]),
            ),
          Press(
            key: const ValueKey('tourSkip'),
            onTap: _finish,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20 * k, vertical: 30 * k),
              child: Text(tr(l, 'Skip guide', 'ಮಾರ್ಗದರ್ಶಿ ಬಿಡಿ'), style: tx(38 * k, c: S.violet, w: FontWeight.w700).copyWith(decoration: TextDecoration.underline, decorationColor: S.violet)),
            ),
          ),
          ZxButton(
            i == widget.steps.length - 1 ? tr(l, 'Done', 'ಮುಗಿಯಿತು') : tr(l, 'Next', 'ಮುಂದೆ'),
            key: const ValueKey('tourNext'),
            trailing: i == widget.steps.length - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded,
            bg: S.violet,
            height: 120 * k,
            size: 38 * k,
            onTap: () => _go(i + 1),
          ),
        ]),
      ]),
    );
    return Stack(children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}, child: SpotLayer(hole: r, caption: step.say.t(l), lang: l, card: card))),
      // Tapping the lit-up thing moves the guide on (it does not open anything yet).
      Positioned.fromRect(rect: r, child: GestureDetector(key: const ValueKey('tourHole'), behavior: HitTestBehavior.opaque, onTap: () => _go(i + 1))),
      Positioned(
        left: 0, right: 0, top: 44 * k,
        child: IgnorePointer(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16 * k),
                padding: EdgeInsets.fromLTRB(28 * k, 16 * k, 36 * k, 16 * k),
                decoration: BoxDecoration(color: const Color(0xFFFFC857), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.record_voice_over_rounded, size: 44 * k, color: S.ink),
                  SizedBox(width: 16 * k),
                  Flexible(child: Text(tr(l, 'Your first class, with a guide', 'ಮಾರ್ಗದರ್ಶಿಯೊಂದಿಗೆ ನಿಮ್ಮ ಮೊದಲ ತರಗತಿ'), maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(36 * k, c: S.ink, w: FontWeight.w700, h: 1.1))),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _Speaking extends StatelessWidget {
  const _Speaking({required this.on, required this.lang});
  final bool on;
  final Lang lang;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 12, 30, 12),
    decoration: BoxDecoration(color: S.soft, borderRadius: BorderRadius.circular(999)),
    child: Row(children: [
      Container(width: 72, height: 72, decoration: const BoxDecoration(color: S.violet, shape: BoxShape.circle), child: Icon(on ? Icons.volume_up_rounded : Icons.subtitles_rounded, size: 44, color: Colors.white)),
      const SizedBox(width: 18),
      if (on)
        for (final h in const <double>[18, 36, 52, 30, 44, 22, 40, 16])
          Container(margin: const EdgeInsets.only(right: 8), width: 9, height: h, decoration: BoxDecoration(color: S.violet, borderRadius: BorderRadius.circular(9))),
      const SizedBox(width: 10),
      Text(on ? tr(lang, 'Voice is speaking', 'ಧ್ವನಿ ಮಾತನಾಡುತ್ತಿದೆ') : tr(lang, 'Read the words', 'ಪದಗಳನ್ನು ಓದಿ'), style: tx(30, c: S.violet, w: FontWeight.w600, h: 1)),
    ]),
  );
}
