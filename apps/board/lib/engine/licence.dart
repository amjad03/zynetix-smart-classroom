import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Where this board's licence stands, checked offline from the signed token the API sends
/// (services/api signLicence: base64url(json) "." base64url(Ed25519 signature)).
enum LicenceState { notActivated, valid, grace, lapsed, invalid }

class LicenceStatus {
  const LicenceStatus(this.state, {this.validUntil, this.daysLeft = 0});
  final LicenceState state;
  final DateTime? validUntil;
  /// Grace days left (grace), or days until expiry (valid).
  final int daysLeft;

  /// Teaching never stops; only new content stops after the grace period.
  bool get canUpdateContent => state == LicenceState.valid || state == LicenceState.grace || state == LicenceState.notActivated;
}

abstract final class Licence {
  static List<int> _b64(String s) => base64Url.decode(base64Url.normalize(s));

  static Future<LicenceStatus> check({required String? token, required List<int> publicKey, required DateTime now}) async {
    if (token == null || token.isEmpty) return const LicenceStatus(LicenceState.notActivated);
    final parts = token.split('.');
    if (parts.length != 2) return const LicenceStatus(LicenceState.invalid);
    try {
      final body = _b64(parts[0]);
      final ok = await Ed25519().verify(body, signature: Signature(_b64(parts[1]), publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)));
      if (!ok) return const LicenceStatus(LicenceState.invalid);
      final j = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
      // Valid through the whole last day.
      final until = DateTime.parse(j['validUntil'] as String).add(const Duration(days: 1));
      final grace = j['graceDays'] as int? ?? 30;
      if (now.isBefore(until)) return LicenceStatus(LicenceState.valid, validUntil: until, daysLeft: until.difference(now).inDays);
      final graceEnd = until.add(Duration(days: grace));
      if (now.isBefore(graceEnd)) return LicenceStatus(LicenceState.grace, validUntil: until, daysLeft: graceEnd.difference(now).inDays);
      return LicenceStatus(LicenceState.lapsed, validUntil: until);
    } catch (_) {
      return const LicenceStatus(LicenceState.invalid);
    }
  }
}
