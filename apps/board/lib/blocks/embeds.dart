import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kinetix_3d/kinetix_3d.dart';
import 'package:kinetix_animations/kinetix_animations.dart';
import 'package:kinetix_cs/kinetix_cs.dart';
import 'package:kinetix_labs/kinetix_labs.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/ui_scale.dart';
import '../engine/model.dart';

/// The interactive pieces reused from Zynetix Board (amjad03/Kinetix). Behind an interface so
/// widget tests (no WebView, no GPU) swap in placeholders.
abstract class Embeds {
  Widget model3d(Block b, Lang lang);
  Widget simulation(Block b, InstalledPack pack, Lang lang);
  Widget lab(String labId, String? preset, Lang lang);
}

class KinetixEmbeds implements Embeds {
  @override
  Widget model3d(Block b, Lang lang) => Model3dViewer(modelId: b.s('modelId')!, variant: b.s('variant'), sceneId: b.s('sceneId'), lang: lang.name, showTitle: false);

  @override
  Widget simulation(Block b, InstalledPack pack, Lang lang) => switch (b.s('source')) {
    'phet' => PackPageView(file: File('${pack.mediaDir}/phet/${b.s('simId')}.html')),
    'animation' => switch (animationById(b.s('simId')!)) {
      final a? => AnimationPlayer(animation: a, lang: lang == Lang.kn ? AnimLang.kn : AnimLang.en),
      null => _missing(b.s('simId')!),
    },
    'kinetix_cs' => csSim(b.s('simId')!),
    _ => lab(b.s('simId')!, b.s('preset'), lang),
  };

  /// Computer Science players from Kinetix: `algo.<kind>`, `sim.<kind>`, `code.<language>`.
  static Widget csSim(String id) {
    final (kind, name) = switch (id.split('.')) {
      [final k, final n] => (k, n),
      _ => ('', ''),
    };
    void noInsert(Object _) {}
    switch (kind) {
      case 'algo':
        final a = AlgoKind.values.where((v) => v.name == name).firstOrNull;
        if (a != null) return AlgoPlayer(kind: a, onInsert: noInsert);
      case 'sim':
        final k = SimKind.values.where((v) => v.name == name).firstOrNull;
        if (k != null) return SimPanel(kind: k, onInsert: noInsert);
      case 'code':
        final l = CodeLanguage.values.where((v) => v.name == name).firstOrNull;
        if (l != null) return CodeLab(initialLanguage: l);
    }
    return _missing(id);
  }

  @override
  Widget lab(String labId, String? preset, Lang lang) => LabCatalogue.byId(labId) == null
      ? _missing(labId)
      // LabView takes its language from the ambient locale.
      : Builder(
          builder: (ctx) => Localizations.override(
            context: ctx,
            locale: Locale(lang.name),
            child: LabView(id: labId, preset: preset),
          ),
        );

  static Widget _missing(String id) => Center(child: Text('“$id” is not available on this board yet.', style: const TextStyle(fontSize: 28)));
}

/// Serves an installed pack's media on 127.0.0.1 only (never the college network), the way the
/// Kinetix board serves its bundled sims, so PhET pages load with no internet.
class PackMediaServer {
  static HttpServer? _server;
  static String? _root;

  static Future<Uri> urlFor(File file) async {
    final root = file.parent.parent.path; // …/media
    if (_server == null || _root != root) {
      await _server?.close(force: true);
      _root = root;
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server!.listen((req) async {
        final path = Uri.decodeComponent(req.uri.path).replaceFirst('/', '');
        final f = File('$_root/$path');
        if (path.contains('..') || !f.existsSync()) {
          req.response.statusCode = HttpStatus.notFound;
        } else {
          req.response.headers.set('content-type', path.endsWith('.html') ? 'text/html; charset=utf-8' : 'application/octet-stream');
          await req.response.addStream(f.openRead());
        }
        await req.response.close();
      });
    }
    return Uri.parse('http://127.0.0.1:${_server!.port}/${file.path.substring(root.length + 1)}');
  }
}

class PackPageView extends StatefulWidget {
  const PackPageView({super.key, required this.file});
  final File file;
  @override
  State<PackPageView> createState() => _PackPageViewState();
}

class _PackPageViewState extends State<PackPageView> {
  WebViewController? _c;

  @override
  void initState() {
    super.initState();
    PackMediaServer.urlFor(widget.file).then((u) {
      if (!mounted) return;
      setState(
        () => _c = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          // Only the loopback page; nothing from the internet.
          ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (r) => r.url.startsWith('http://127.0.0.1') ? NavigationDecision.navigate : NavigationDecision.prevent))
          ..loadRequest(u),
      );
    });
  }

  @override
  Widget build(BuildContext context) => _c == null ? const Center(child: CircularProgressIndicator()) : Unscaled(child: WebViewWidget(controller: _c!));
}

/// Test double: a labelled box per embed.
class PlaceholderEmbeds implements Embeds {
  Widget _box(String s) => Container(key: ValueKey('embed:$s'), color: Colors.black12, alignment: Alignment.center, child: Text(s));
  @override
  Widget model3d(Block b, Lang lang) => _box('3d:${b.s('modelId')}');
  @override
  Widget simulation(Block b, InstalledPack pack, Lang lang) => _box('sim:${b.s('source')}:${b.s('simId')}');
  @override
  Widget lab(String labId, String? preset, Lang lang) => _box('lab:$labId');
}
