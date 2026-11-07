import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../engine/model.dart';

/// The teacher's phone as a remote for the board, as in KINETIX TeachBoard: the board serves a
/// small page on the classroom Wi-Fi (no internet, no app on the phone, no camera). The phone
/// scans the QR code and gets big buttons: previous / next page, new page, undo, blank the
/// screen, read aloud. A private key in the link goes with every request.
class RemoteServer {
  RemoteServer({required this.onAction, required this.state});

  /// Runs a button from the phone (`prev`, `next`, `page`, `undo`, `blank`, `read`).
  final void Function(String action) onAction;

  /// The board's state for the phone: page, pages, title, blank.
  final Map<String, Object?> Function() state;

  HttpServer? _server;
  String? url;
  final String key = _key();

  static String _key() {
    final r = math.Random.secure();
    return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  bool get running => _server != null;

  /// Starts on the Wi-Fi; returns the phone's link, or null when the board has no network.
  Future<String?> start({Lang lang = Lang.en, int port = 8765}) async {
    await stop();
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server = server;
    server.listen((req) => _handle(req, lang));
    final ip = await localIp();
    return url = ip == null ? null : 'http://$ip:${server.port}/remote?k=$key';
  }

  /// Handles one request (public for tests).
  Future<Map<String, Object?>> api(String k, String action) async {
    if (k != key) return {'ok': false, 'error': 'Scan the code on the board again.'};
    if (action != 'state') onAction(action);
    return {'ok': true, ...state()};
  }

  Future<void> _handle(HttpRequest req, Lang lang) async {
    final res = req.response;
    res.headers.set('Cache-Control', 'no-store');
    try {
      final path = req.uri.path;
      if (req.method == 'GET' && path == '/remote') {
        res.headers.contentType = ContentType.html;
        res.write(remotePage(lang));
      } else if (req.method == 'POST' && path == '/api/remote') {
        final raw = await utf8.decoder.bind(req).join();
        if (raw.length > 2000) throw const FormatException('too large');
        final body = (jsonDecode(raw) as Map).cast<String, dynamic>();
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode(await api('${body['k']}', '${body['action']}')));
      } else {
        res.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      res.statusCode = HttpStatus.badRequest;
    }
    await res.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    url = null;
  }
}

/// The board's address on the classroom Wi-Fi.
Future<String?> localIp() async {
  try {
    final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    String? fallback;
    for (final i in ifs) {
      for (final a in i.addresses) {
        final ip = a.address;
        final private = ip.startsWith('192.168.') || ip.startsWith('10.') || RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);
        if (private && (i.name.startsWith('wlan') || i.name.startsWith('en') || i.name.startsWith('eth'))) return ip;
        if (private) fallback ??= ip;
      }
    }
    return fallback;
  } catch (_) {
    return null;
  }
}

/// The phone page in the board's language.
String remotePage(Lang lang) {
  final kn = lang == Lang.kn;
  final words = {
    'title': kn ? 'ಬೋರ್ಡ್ ರಿಮೋಟ್' : 'Board remote',
    'connecting': kn ? 'ಬೋರ್ಡ್‌ಗೆ ಸಂಪರ್ಕಿಸುತ್ತಿದೆ…' : 'Connecting to the board…',
    'notConnected': kn ? 'ಸಂಪರ್ಕವಿಲ್ಲ. ಬೋರ್ಡ್‌ನ ಅದೇ Wi-Fi ಇದೆಯೇ?' : 'Not connected. Same Wi-Fi as the board?',
    'back': kn ? 'ಹಿಂದೆ' : 'Back',
    'next': kn ? 'ಮುಂದೆ' : 'Next',
    'page': kn ? 'ಹೊಸ ಪುಟ' : 'New page',
    'undo': kn ? 'ರದ್ದುಮಾಡು' : 'Undo',
    'blank': kn ? 'ಪರದೆ ಖಾಲಿ' : 'Blank screen',
    'show': kn ? 'ಪರದೆ ತೋರಿಸಿ' : 'Show screen',
    'read': kn ? 'ಓದಿ ಹೇಳಿ' : 'Read aloud',
    'pageOf': kn ? 'ಪುಟ {n} / {m}' : 'Page {n} of {m}',
  };
  return remotePageHtml.replaceFirst('/*WORDS*/{}', jsonEncode(words).replaceAll('</', '<\\/')).replaceFirst('<html lang="en">', '<html lang="${lang.name}">');
}

/// Self-contained (no outside files), in the board's colours.
const remotePageHtml = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#13165A">
<title>Board remote</title>
<style>
:root{--bg:#F6F6FA;--card:#fff;--ink:#13165A;--muted:#6B6F85;--violet:#5442D8;--soft:#EEEBFB;--red:#B4441B}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.4 system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans Kannada",sans-serif;min-height:100vh;min-height:100dvh;display:flex;flex-direction:column}
header{padding:20px 18px 6px}h1{font-size:22px;font-weight:700;margin:0}
.sub{color:var(--muted);font-size:15px;margin-top:2px}.err{color:var(--red)}
main{flex:1;width:100%;padding:12px 16px calc(20px + env(safe-area-inset-bottom));max-width:560px;margin:0 auto;display:flex;flex-direction:column;gap:12px}
button{font:inherit;border:0;border-radius:28px;padding:24px 12px;font-size:19px;font-weight:700;background:var(--card);color:var(--ink);box-shadow:0 8px 20px rgba(19,22,90,.08)}
button:active{transform:scale(.98)}button:disabled{opacity:.4}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.nav{display:grid;grid-template-columns:1fr 1.6fr;gap:12px;margin-top:auto}
.big{background:var(--violet);color:#fff;font-size:24px;padding:36px 12px}
.on{background:var(--soft)}
</style></head><body>
<header><h1 id="title">Board remote</h1><div class="sub" id="where"></div></header>
<main>
<div class="grid"><button id="page"></button><button id="undo"></button><button id="blank"></button><button id="read"></button></div>
<div class="nav"><button id="prev"></button><button id="next" class="big"></button></div>
</main>
<script>
const W=Object.assign({},/*WORDS*/{});
const k=new URLSearchParams(location.search).get('k')||'';const $=id=>document.getElementById(id);
$('title').textContent=W.title;$('where').textContent=W.connecting;
for(const [id,w] of [['page','page'],['undo','undo'],['blank','blank'],['read','read'],['prev','back'],['next','next']])$(id).textContent=W[w];
function show(s){if(!s||!s.ok){$('where').textContent=(s&&s.error)||W.notConnected;$('where').className='sub err';return}
$('where').className='sub';if(s.title)$('title').textContent=s.title;
$('where').textContent=W.pageOf.replace('{n}',s.page).replace('{m}',s.pages);$('prev').disabled=s.page<=1;
$('blank').classList.toggle('on',!!s.blank);$('blank').textContent=s.blank?W.show:W.blank}
async function act(a){try{const r=await fetch('/api/remote',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({k:k,action:a})});show(await r.json())}catch(e){show(null)}}
['prev','next','page','undo','blank','read'].forEach(a=>$(a).onclick=()=>act(a));
act('state');setInterval(()=>act('state'),3000);
</script></body></html>''';
