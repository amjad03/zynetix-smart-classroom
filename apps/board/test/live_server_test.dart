// The phone quiz server, driven with real HTTP requests on localhost.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:zynetix_board/engine/model.dart';
import 'package:zynetix_board/features/live/live_server.dart';

Question mcq([String id = 'q1']) => Question(id: id, topicId: 't1', chapterId: 'c1', stem: const L10n('2 + 2?', '೨ + ೨?'), options: const [L10n('3'), L10n('4'), L10n('5'), L10n('6')], answer: 1, exams: const [], difficulty: 'easy');
Question multi() => Question(id: 'q2', topicId: 't1', stem: const L10n('Even numbers'), options: const [L10n('2'), L10n('3'), L10n('4'), L10n('5')], answer: 0, answers: const [0, 2], exams: const [], difficulty: 'easy', format: 'multi_correct');
Question numeric() => Question(id: 'q3', topicId: 't1', stem: const L10n('g in m/s²'), options: const [], answer: 0, numericAnswer: 9.8, tolerance: 0.1, exams: const [], difficulty: 'easy', format: 'numeric');

void main() {
  late LiveServer server;
  late Uri base;

  setUp(() async {
    server = LiveServer(rollCount: 60, roomCode: '4321', random: Random(1));
    await server.start(port: 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
  });
  tearDown(() => server.stop());

  Future<(int, Map<String, dynamic>)> post(String path, Map<String, dynamic> body) async {
    final r = await http.post(base.resolve(path), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    return (r.statusCode, jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> state(String token) async => jsonDecode((await http.get(base.resolve('/state?token=$token'))).body) as Map<String, dynamic>;

  Future<String> join(int roll) async {
    final (code, j) = await post('/join', {'room': '4321', 'roll': '$roll'});
    expect(code, 200, reason: '$j');
    return j['token'] as String;
  }

  test('serves the self-contained phone page', () async {
    final r = await http.get(base.resolve('/'));
    expect(r.statusCode, 200);
    expect(r.headers['content-type'], contains('text/html'));
    expect(r.body, contains('<script>'));
    // Nothing is fetched from the internet: no external scripts, styles or fonts.
    expect(RegExp(r'''(src|href)=["']https?:''').hasMatch(r.body), isFalse);
    expect(r.body, isNot(contains('cdn')));
  });

  test('rejects a wrong room code and a roll number outside the class', () async {
    expect((await post('/join', {'room': '1111', 'roll': '5'})).$1, 403);
    expect((await post('/join', {'room': '1111', 'roll': '5'})).$2['error'], 'room');
    expect((await post('/join', {'room': '4321', 'roll': '0'})).$1, 400);
    expect((await post('/join', {'room': '4321', 'roll': '61'})).$1, 400);
    expect((await post('/join', {'room': '4321', 'roll': 'abc'})).$1, 400);
    expect(server.joined, isEmpty);
  });

  test('locks out after too many wrong room codes', () async {
    for (var i = 0; i < LiveServer.maxFailures; i++) {
      await post('/join', {'room': '0000', 'roll': '1'});
    }
    expect((await post('/join', {'room': '4321', 'roll': '1'})).$1, 429);
  });

  test('a roll number belongs to the first phone; that phone can rejoin', () async {
    final t = await join(7);
    expect(server.joined, {7});
    final (code, j) = await post('/join', {'room': '4321', 'roll': '7'});
    expect((code, j['error']), (409, 'taken'));
    expect((await post('/join', {'room': '4321', 'roll': '7', 'token': t})).$1, 200);
    server.release(7);
    expect((await post('/join', {'room': '4321', 'roll': '7'})).$1, 200);
  });

  test('one answer per roll per question, graded at reveal, shown on the phone', () async {
    final a = await join(1), b = await join(2), c = await join(3);
    expect((await state(a))['phase'], 'waiting');
    // Nothing open yet.
    expect((await post('/answer', {'token': a, 'seq': 0, 'choice': 1})).$1, 409);

    server.open(mcq());
    final s = await state(a);
    expect(s['phase'], 'open');
    expect(s['stem'], '2 + 2?');
    expect(s['options'], ['3', '4', '5', '6']);
    expect(s['format'], 'single');
    expect(s.containsKey('answer'), isFalse, reason: 'the answer is not sent before the reveal');
    final seq = s['seq'];

    expect((await post('/answer', {'token': a, 'seq': seq, 'choice': 1})).$1, 200);
    expect((await post('/answer', {'token': a, 'seq': seq, 'choice': 2})).$2['error'], 'already');
    expect((await post('/answer', {'token': b, 'seq': seq, 'choice': 2})).$1, 200);
    expect((await post('/answer', {'token': c, 'seq': seq, 'choice': 9})).$1, 400);
    expect((await post('/answer', {'token': 'nope', 'seq': seq, 'choice': 1})).$1, 401);
    expect((await post('/answer', {'token': c, 'seq': seq - 1, 'choice': 1})).$2['error'], 'closed');
    expect(server.answers.keys.toSet(), {1, 2});
    expect(server.histogram.take(4), [0, 1, 1, 0]);
    expect((await state(a))['mine'], {'choice': 1});

    expect(server.reveal(), {1: true, 2: false});
    expect((await state(a))['correct'], true);
    expect((await state(b))['correct'], false);
    expect((await state(b))['answer'], 'B');
    expect((await state(c))['correct'], isNull);
    // Closed after the reveal.
    expect((await post('/answer', {'token': c, 'seq': seq, 'choice': 1})).$1, 409);

    // The next question clears the answers.
    server.open(mcq('q9'));
    expect(server.answers, isEmpty);
    expect((await post('/answer', {'token': a, 'seq': server.seq, 'choice': 0})).$1, 200);
  });

  test('multi-correct and numeric answers', () async {
    final a = await join(10), b = await join(11);
    server.open(multi());
    expect((await state(a))['format'], 'multi');
    expect((await post('/answer', {'token': a, 'seq': server.seq, 'choices': [2, 0]})).$1, 200);
    expect((await post('/answer', {'token': b, 'seq': server.seq, 'choices': []})).$1, 400);
    expect((await post('/answer', {'token': b, 'seq': server.seq, 'choices': [0]})).$1, 200);
    expect(server.histogram.take(4), [2, 0, 1, 0]);
    expect(server.reveal(), {10: true, 11: false});
    expect((await state(a))['answer'], 'A, C');

    server.open(numeric());
    expect((await state(a))['format'], 'numeric');
    expect((await post('/answer', {'token': a, 'seq': server.seq, 'value': '9.85'})).$1, 200);
    expect((await post('/answer', {'token': b, 'seq': server.seq, 'value': 'x'})).$1, 400);
    expect((await post('/answer', {'token': b, 'seq': server.seq, 'value': 10})).$1, 200);
    expect(server.values.length, 2);
    expect(server.reveal(), {10: true, 11: false});
    expect((await state(b))['answer'], '9.8 ± 0.1');
  });

  test('the page language follows the board', () async {
    server.lang = Lang.kn;
    final a = await join(4);
    server.open(mcq());
    final s = await state(a);
    expect(s['lang'], 'kn');
    expect(s['stem'], '೨ + ೨?');
  });

  test('refuses bad bodies and unknown paths', () async {
    final r = await http.post(base.resolve('/join'), body: 'not json');
    expect(r.statusCode, 400);
    expect((await http.post(base.resolve('/join'), body: 'x' * 5000)).statusCode, 400);
    expect((await http.get(base.resolve('/secret'))).statusCode, 404);
  });

  test('private and public addresses', () {
    expect(LiveServer.isPrivate(InternetAddress('192.168.43.10')), isTrue);
    expect(LiveServer.isPrivate(InternetAddress('10.0.0.5')), isTrue);
    expect(LiveServer.isPrivate(InternetAddress('172.20.1.1')), isTrue);
    expect(LiveServer.isPrivate(InternetAddress('127.0.0.1')), isTrue);
    expect(LiveServer.isPrivate(InternetAddress('8.8.8.8')), isFalse);
    expect(LiveServer.isPrivate(InternetAddress('172.32.0.1')), isFalse);
  });

  test('room codes are 4 digits', () {
    for (var i = 0; i < 20; i++) {
      expect(LiveServer(rollCount: 10).roomCode, matches(RegExp(r'^\d{4}$')));
    }
  });
}
