import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../core/ui_scale.dart';
import '../engine/model.dart';
import '../features/simple/kit.dart' show S;
import 'embeds.dart';

/// Is the board online? A DNS lookup of the video host (no request is made). Widget tests are
/// offline. Replaceable for tests.
Future<bool> Function() boardOnline = _lookup;

Future<bool> _lookup() async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
  try {
    final r = await InternetAddress.lookup('www.youtube-nocookie.com').timeout(const Duration(seconds: 4));
    return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// A concept video block (lesson-schema ConceptVideoBlock): the owner's own video streams in an
/// embedded player when the board is online; offline, a friendly "Needs internet" card. Videos
/// are never downloaded. The rail has the caption, the video's markers (YouTube: jump to that
/// moment) and the chapter's other videos.
class ConceptVideoView extends StatefulWidget {
  const ConceptVideoView({super.key, required this.block, required this.lang, required this.embeds});
  final Block block;
  final Lang lang;
  final Embeds embeds;
  @override
  State<ConceptVideoView> createState() => _ConceptVideoViewState();
}

class _ConceptVideoViewState extends State<ConceptVideoView> {
  bool? _online;
  int _index = 0, _start = 0;

  List<VideoRef> get videos => [
    ?VideoRef.maybe(widget.block.raw['video']),
    for (final v in (widget.block.raw['playlist'] as List?) ?? const []) ?VideoRef.maybe(v),
  ];

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _online = null);
    final on = await boardOnline();
    if (mounted) setState(() => _online = on);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang, narrow = context.narrow;
    final vs = videos;
    if (vs.isEmpty) return ContentPanel(tag: blockName(BlockType.conceptVideo, l), child: Text(tr('needsInternet', l), style: zText(32)));
    final v = vs[_index.clamp(0, vs.length - 1)];
    final caption = widget.block.maybe('caption');
    final Widget main = switch (_online) {
      true => KeyedSubtree(key: ValueKey('player:${v.id}:$_start'), child: widget.embeds.video(v, start: _start)),
      false => _Offline(video: v, lang: l, onRetry: _check),
      null => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(dimension: 64, child: CircularProgressIndicator(strokeWidth: 5, color: Z.onStage2)),
            const SizedBox(height: 24),
            Text(tr('checkingConnection', l), style: zText(28, FontWeight.w500).copyWith(color: Z.onStage2)),
          ],
        ),
      ),
    };
    return StageLayout(
      stage: ZStage(title: v.title.t(l), hint: '${tr('block.concept_video', l)} · ${tr('onlineOnly', l)}', padding: const EdgeInsets.all(16), child: ClipRRect(borderRadius: BorderRadius.circular(Z.panelRadius), child: main)),
      rail: [
        RailPanel(
          title: tr('about', l),
          trailing: ZTag(tr('onlineOnly', l), icon: Icons.wifi_rounded, color: S.violet, background: S.lavender),
          children: [RailNote(caption?.t(l) ?? tr('videoOffline', l))],
        ),
        if (v.provider == 'youtube' && v.chapters.isNotEmpty)
          RailPanel(
            title: tr('jumpTo', l),
            gap: 16,
            children: [
              for (final (at, label) in v.chapters)
                ZSmallButton(
                  key: ValueKey('mark-$at'),
                  icon: Icons.play_arrow_rounded,
                  label: '${at ~/ 60}:${(at % 60).toString().padLeft(2, '0')}  ${label.t(l)}',
                  onPressed: _online == true ? () => setState(() => _start = at) : null,
                ),
            ],
          ),
        if (vs.length > 1)
          RailPanel(
            title: tr('moreVideos', l),
            gap: 12,
            children: [
              for (final (i, o) in vs.indexed)
                _VideoRow(
                  key: ValueKey('video-row-$i'),
                  title: o.title.t(l),
                  current: i == _index,
                  onTap: () => setState(() {
                    _index = i;
                    _start = 0;
                  }),
                  narrow: narrow,
                ),
            ],
          ),
      ],
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({super.key, required this.title, required this.current, required this.onTap, required this.narrow});
  final String title;
  final bool current, narrow;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: current ? S.lavender : Z.well,
    borderRadius: BorderRadius.circular(Z.radius),
    child: InkWell(
      borderRadius: BorderRadius.circular(Z.radius),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: narrow ? 14 : 18),
        child: Row(
          children: [
            Icon(current ? Icons.play_circle_rounded : Icons.play_circle_outline_rounded, size: narrow ? 36 : 42, color: current ? S.violet : Z.muted),
            const SizedBox(width: 16),
            Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: zText(narrow ? 26 : 30, current ? FontWeight.w600 : FontWeight.w500).copyWith(color: Z.ink))),
          ],
        ),
      ),
    ),
  );
}

/// Offline: what the video is, that it needs the internet, and Check again.
class _Offline extends StatelessWidget {
  const _Offline({required this.video, required this.lang, required this.onRetry});
  final VideoRef video;
  final Lang lang;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final narrow = context.narrow;
    return Container(
      key: const ValueKey('video-offline'),
      color: Z.transport,
      alignment: Alignment.center,
      padding: EdgeInsets.all(narrow ? 28 : 56),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: narrow ? 104 : 136,
                height: narrow ? 104 : 136,
                decoration: const BoxDecoration(color: S.lavender, shape: BoxShape.circle),
                child: Icon(Icons.wifi_off_rounded, size: narrow ? 56 : 72, color: S.violet),
              ),
              SizedBox(height: narrow ? 20 : 32),
              Text(tr('needsInternet', lang), textAlign: TextAlign.center, style: zTitle(narrow ? 40 : 52).copyWith(color: Z.onStage)),
              const SizedBox(height: 12),
              Text(video.title.t(lang), textAlign: TextAlign.center, style: zText(narrow ? 28 : 32, FontWeight.w600).copyWith(color: Z.stageAccent)),
              const SizedBox(height: 16),
              Text(tr('videoOffline', lang), textAlign: TextAlign.center, style: zText(narrow ? 26 : 30, FontWeight.w400).copyWith(color: Z.onStage2, height: 1.45)),
              SizedBox(height: narrow ? 24 : 36),
              IntrinsicWidth(child: StagePill(key: const ValueKey('video-retry'), label: tr('checkAgain', lang), light: true, onPressed: onRetry)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The embedded player: YouTube (no cookies) or the Drive preview player, in a WebView that only
/// goes to the video hosts. Nothing is downloaded or stored.
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({super.key, required this.video, this.start = 0});
  final VideoRef video;
  final int start;
  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late final WebViewController _c;
  static const _hosts = ['youtube-nocookie.com', 'youtube.com', 'ytimg.com', 'googlevideo.com', 'google.com', 'gstatic.com', 'googleusercontent.com', 'about:blank'];

  @override
  void initState() {
    super.initState();
    final url = widget.video.embedUrl(start: widget.start);
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) {
            final host = Uri.tryParse(r.url)?.host ?? r.url;
            return _hosts.any((h) => host == h || host.endsWith('.$h') || r.url.startsWith(h)) ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
        ),
      );
    if (widget.video.provider == 'youtube') {
      // An iframe on a page of our own, so the player gets a referrer (YouTube needs one).
      _c.loadHtmlString(
        '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body{margin:0;height:100%;background:#000}iframe{border:0;width:100%;height:100%}</style></head>'
        '<body><iframe src="$url" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe></body></html>',
        baseUrl: 'https://www.youtube-nocookie.com',
      );
    } else {
      _c.loadRequest(url);
    }
  }

  @override
  Widget build(BuildContext context) => Unscaled(child: WebViewWidget(controller: _c));
}
