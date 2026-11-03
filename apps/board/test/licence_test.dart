import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynetix_board/engine/licence.dart';

void main() {
  late SimpleKeyPair kp;
  late List<int> pub;
  setUpAll(() async {
    kp = await Ed25519().newKeyPair();
    pub = (await kp.extractPublicKey()).bytes;
  });
  Future<String> token(String validUntil, {SimpleKeyPair? signer}) async {
    final body = utf8.encode(jsonEncode({'deviceId': 'd', 'validUntil': validUntil, 'graceDays': 30}));
    final sig = await Ed25519().sign(body, keyPair: signer ?? kp);
    return '${base64Url.encode(body).replaceAll('=', '')}.${base64Url.encode(sig.bytes).replaceAll('=', '')}';
  }

  test('valid, grace, lapsed by date', () async {
    final t = await token('2027-03-31');
    expect((await Licence.check(token: t, publicKey: pub, now: DateTime(2027, 3, 31, 18))).state, LicenceState.valid);
    final g = await Licence.check(token: t, publicKey: pub, now: DateTime(2027, 4, 10));
    expect(g.state, LicenceState.grace);
    expect(g.daysLeft, 21);
    final l = await Licence.check(token: t, publicKey: pub, now: DateTime(2027, 5, 2));
    expect(l.state, LicenceState.lapsed);
    expect(l.canUpdateContent, isFalse);
  });

  test('a token signed by another key, or edited, is invalid', () async {
    final other = await Ed25519().newKeyPair();
    expect((await Licence.check(token: await token('2099-01-01', signer: other), publicKey: pub, now: DateTime(2027))).state, LicenceState.invalid);
    final t = await token('2027-01-01');
    final forged = '${base64Url.encode(utf8.encode('{"validUntil":"2099-01-01"}')).replaceAll('=', '')}.${t.split('.')[1]}';
    expect((await Licence.check(token: forged, publicKey: pub, now: DateTime(2027))).state, LicenceState.invalid);
    expect((await Licence.check(token: null, publicKey: pub, now: DateTime(2027))).state, LicenceState.notActivated);
  });
}
