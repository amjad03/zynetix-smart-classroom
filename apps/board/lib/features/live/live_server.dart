import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../engine/model.dart';
import '../participation.dart' show multiCorrect, numericCorrect, formatNumber;
import 'phone_page.dart';

/// One phone's answer: an option (mcq), a set of options (multi_correct) or a number (numeric).
class LiveAnswer {
  const LiveAnswer({this.choice, this.choices, this.value});
  final int? choice;
  final Set<int>? choices;
  final double? value;

  /// The option to log as "chosen" (the first picked for multi_correct, none for numeric).
  int? get chosen => choice ?? (choices == null || choices!.isEmpty ? null : (choices!.toList()..sort()).first);

  bool correctFor(Question q) => q.isNumeric
      ? numericCorrect(q, value)
      : q.isMulti
      ? multiCorrect(q, choices ?? const {})
      : choice == q.answer;

  Map<String, dynamic> toJson() => {'choice': ?choice, if (choices != null) 'choices': (choices!.toList()..sort()), 'value': ?value};
}

enum LivePhase { waiting, open, revealed }

/// Why a phone's request was refused (sent back as {"error": name}).
enum LiveError { room, roll, taken, token, closed, already, invalid, tooMany }

/// The phone quiz server: a small HTTP server on the board's own network (LAN only, nothing on
/// the internet). Students open the page it serves, type the room code and their roll number,
/// and answer the question the board has open. One answer per roll per question.
///
///   GET  /           the phone page (one self-contained HTML file, works offline)
///   POST /join       {room, roll, token?}             → {token, roll}
///   GET  /state?token=…                               → the open question, my answer, the result
///   POST /answer     {token, seq, choice|choices|value} → {ok: true}
///
/// A roll number belongs to the first phone that joins with it (a token kept on the phone), so
/// another student cannot answer for it; the teacher can [release] a roll.
class LiveServer extends ChangeNotifier {
  LiveServer({required this.rollCount, String? roomCode, Random? random, this.lang = Lang.en, this.lanOnly = true})
    : _rnd = random ?? Random.secure(),
      roomCode = roomCode ?? (random ?? Random.secure()).nextInt(10000).toString().padLeft(4, '0');

  final int rollCount;
  final String roomCode;
  final Random _rnd;

  /// The language of the phone page.
  Lang lang;

  /// Refuse requests from outside private networks (on by default; tests use loopback anyway).
  final bool lanOnly;

  HttpServer? _server;
  final _tokens = <String, int>{}; // token → roll
  final _failures = <String, int>{}; // remote address → wrong room codes
  static const maxFailures = 30;

  LivePhase phase = LivePhase.waiting;
  Question? question;

  /// Bumped for every question sent, so a late answer to an earlier question is refused.
  int seq = 0;
  final Map<int, LiveAnswer> _answers = {};

  int? get port => _server?.port;
  bool get running => _server != null;

  /// Roll numbers whose phones have joined.
  Set<int> get joined => _tokens.values.toSet();

  /// Answers to the open (or just revealed) question, by roll number.
  Map<int, LiveAnswer> get answers => Map.unmodifiable(_answers);

  /// How many phones picked each option (multi_correct counts every option picked).
  List<int> get histogram {
    final q = question;
    final out = List<int>.filled(q == null ? 4 : max(q.options.length, 4), 0);
    for (final a in _answers.values) {
      if (a.choice != null && a.choice! < out.length) out[a.choice!]++;
      for (final c in a.choices ?? const <int>{}) {
        if (c < out.length) out[c]++;
      }
    }
    return out;
  }

  /// numeric: the values sent, most common first.
  List<(double value, int count)> get values {
    final m = <double, int>{};
    for (final a in _answers.values) {
      if (a.value != null) m[a.value!] = (m[a.value!] ?? 0) + 1;
    }
    return [for (final e in m.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// Starts listening on every IPv4 interface at [port] (any free port if it is taken).
  Future<void> start({int port = 8080}) async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } on SocketException {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server!.listen((r) => unawaited(_handle(r)));
    notifyListeners();
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
  }

  /// Sends [q] to the phones: answers to the previous question are cleared.
  void open(Question q) {
    question = q;
    seq++;
    _answers.clear();
    phase = LivePhase.open;
    notifyListeners();
  }

  /// Closes answering and shows right or wrong on the phones. Returns each roll's result.
  Map<int, bool> reveal() {
    final q = question;
    if (q == null) return const {};
    phase = LivePhase.revealed;
    notifyListeners();
    return {for (final e in _answers.entries) e.key: e.value.correctFor(q)};
  }

  /// Frees a roll number so another phone can join with it (a student changed phones).
  void release(int roll) {
    _tokens.removeWhere((_, r) => r == roll);
    notifyListeners();
  }

  /// The board's addresses on its local networks (Wi-Fi, hotspot, Ethernet), best first.
  static Future<List<String>> lanAddresses() async {
    final out = <String>[];
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          if (!a.isLoopback && isPrivate(a)) out.add(a.address);
        }
      }
    } catch (_) {}
    int rank(String a) => a.startsWith('192.168.') ? 0 : (a.startsWith('10.') ? 1 : 2);
    return out..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// Loopback, link-local or a private (RFC 1918 / carrier-grade NAT) address.
  static bool isPrivate(InternetAddress a) {
    if (a.isLoopback || a.isLinkLocal) return true;
    if (a.type != InternetAddressType.IPv4) return false;
    final b = a.rawAddress;
    return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] < 32) || (b[0] == 192 && b[1] == 168) || (b[0] == 100 && b[1] >= 64 && b[1] < 128);
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    res.headers.set('Cache-Control', 'no-store');
    try {
      final remote = req.connectionInfo?.remoteAddress;
      if (lanOnly && remote != null && !isPrivate(remote)) {
        return await _send(res, 403, {'error': 'lan'});
      }
      final path = req.uri.path;
      if (req.method == 'GET' && (path == '/' || path == '/index.html')) {
        res.statusCode = 200;
        res.headers.contentType = ContentType.html;
        res.write(phonePage);
        return await res.close();
      }
      if (req.method == 'GET' && path == '/state') return await _send(res, 200, _state(req.uri.queryParameters['token']));
      if (req.method == 'POST' && (path == '/join' || path == '/answer')) {
        final body = await _body(req);
        if (body == null) return await _send(res, 400, {'error': LiveError.invalid.name});
        final r = path == '/join' ? _join(body, remote?.address ?? '') : _answer(body);
        return await _send(res, r.$1, r.$2);
      }
      return await _send(res, 404, {'error': 'not found'});
    } catch (_) {
      try {
        await _send(res, 500, {'error': 'server'});
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> _body(HttpRequest req) async {
    final bytes = <int>[];
    await for (final chunk in req) {
      bytes.addAll(chunk);
      if (bytes.length > 4096) return null;
    }
    try {
      final j = jsonDecode(utf8.decode(bytes));
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _send(HttpResponse res, int status, Map<String, dynamic> body) async {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
    await res.close();
  }

  static (int, Map<String, dynamic>) _err(int status, LiveError e) => (status, {'error': e.name});

  (int, Map<String, dynamic>) _join(Map<String, dynamic> b, String from) {
    if ((_failures[from] ?? 0) >= maxFailures) return _err(429, LiveError.tooMany);
    if ('${b['room']}'.trim() != roomCode) {
      _failures[from] = (_failures[from] ?? 0) + 1;
      return _err(403, LiveError.room);
    }
    final roll = int.tryParse('${b['roll']}'.trim());
    if (roll == null || roll < 1 || roll > rollCount) return _err(400, LiveError.roll);
    final mine = b['token'] is String ? b['token'] as String : null;
    final holder = _tokens.entries.where((e) => e.value == roll).firstOrNull;
    if (holder != null) {
      if (holder.key == mine) return (200, {'token': mine, 'roll': roll});
      return _err(409, LiveError.taken);
    }
    if (mine != null) _tokens.remove(mine); // the phone switches to another roll number
    final token = List.generate(16, (_) => _rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _tokens[token] = roll;
    notifyListeners();
    return (200, {'token': token, 'roll': roll});
  }

  Map<String, dynamic> _state(String? token) {
    final roll = token == null ? null : _tokens[token];
    if (roll == null) return {'error': LiveError.token.name, 'lang': lang.name};
    final q = question;
    final mine = _answers[roll];
    return {
      'roll': roll,
      'lang': lang.name,
      'phase': phase.name,
      'seq': seq,
      if (q != null && phase != LivePhase.waiting) ...{
        'format': q.isNumeric ? 'numeric' : (q.isMulti ? 'multi' : 'single'),
        'stem': q.stem.t(lang),
        'options': [for (final o in q.options.take(4)) o.t(lang)],
        'mine': mine?.toJson(),
        if (phase == LivePhase.revealed) ...{
          'correct': mine?.correctFor(q),
          'answer': q.isNumeric ? '${formatNumber(q.numericAnswer ?? double.nan)}${(q.tolerance ?? 0) > 0 ? ' ± ${formatNumber(q.tolerance!)}' : ''}' : (q.correctSet.toList()..sort()).map((i) => 'ABCD'[i]).join(', '),
        },
      },
    };
  }

  (int, Map<String, dynamic>) _answer(Map<String, dynamic> b) {
    final roll = b['token'] is String ? _tokens[b['token']] : null;
    if (roll == null) return _err(401, LiveError.token);
    final q = question;
    if (q == null || phase != LivePhase.open || b['seq'] != seq) return _err(409, LiveError.closed);
    if (_answers.containsKey(roll)) return _err(409, LiveError.already);
    final n = min(q.options.length, 4);
    final LiveAnswer a;
    if (q.isNumeric) {
      final v = b['value'] is num ? (b['value'] as num).toDouble() : double.tryParse('${b['value']}'.trim().replaceAll('−', '-'));
      if (v == null || !v.isFinite) return _err(400, LiveError.invalid);
      a = LiveAnswer(value: v);
    } else if (q.isMulti) {
      final raw = b['choices'];
      if (raw is! List || raw.isEmpty || raw.any((c) => c is! int || c < 0 || c >= n)) return _err(400, LiveError.invalid);
      a = LiveAnswer(choices: raw.cast<int>().toSet());
    } else {
      final c = b['choice'];
      if (c is! int || c < 0 || c >= n) return _err(400, LiveError.invalid);
      a = LiveAnswer(choice: c);
    }
    submit(roll, a);
    return (200, {'ok': true});
  }

  /// Takes [roll]'s answer to the open question (the first one only). The phones' route; also
  /// used by tests of the board screen.
  bool submit(int roll, LiveAnswer a) {
    if (phase != LivePhase.open || _answers.containsKey(roll)) return false;
    _answers[roll] = a;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
