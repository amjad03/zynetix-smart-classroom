import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/model.dart';
import '../engine/period.dart';

/// This board's settings, kept on the device so everything works offline. Set at activation
/// (services/api POST /v1/devices/activate) and refreshed on every sync.
///
/// The class is a *section* with a roll count — never a list of students.
class BoardConfig extends ChangeNotifier {
  BoardConfig(this._p);
  final SharedPreferences _p;

  static Future<BoardConfig> load() async => BoardConfig(await SharedPreferences.getInstance());

  bool get activated => _p.getString('deviceToken') != null;
  String? get deviceToken => _p.getString('deviceToken');
  String get apiBase => _p.getString('apiBase') ?? 'http://10.0.2.2:4000';
  String get collegeName => _p.getString('collegeName') ?? 'Zynetix PU College';
  String get sectionId => _p.getString('sectionId') ?? 'demo-1puc-a';
  String get sectionLabel => _p.getString('sectionLabel') ?? '1st PUC · A · PCMB';
  /// puc1 / puc2: which year's chapters to list first.
  String get year => _p.getString('year') ?? 'puc1';
  /// The curriculum this section follows: kar_pu (Karnataka PU) or cbse.
  String get board => _p.getString('board') ?? 'kar_pu';
  bool get isCbse => board == 'cbse';
  /// Subjects taught in this section, in tab order (from Admin → Sections).
  List<String> get subjects => _p.getStringList('subjects') ?? const ['physics', 'chemistry', 'maths', 'biology'];
  int get rollCount => _p.getInt('rollCount') ?? 60;
  int get periodMinutes => _p.getInt('periodMinutes') ?? 40;
  Lang get lang => _p.getString('lang') == 'kn' ? Lang.kn : Lang.en;
  String? get licenceToken => _p.getString('licenceToken');
  bool get kioskOn => _p.getBool('kiosk') ?? false;

  /// Before activation the PIN is 1234 (printed on the setup card); activation replaces it.
  String get _pinHash => _p.getString('pinHash') ?? hashPin('1234', 'zynetix');
  String get _pinSalt => _p.getString('pinSalt') ?? 'zynetix';

  static String hashPin(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();
  bool checkPin(String pin) => hashPin(pin, _pinSalt) == _pinHash;

  Future<void> setLang(Lang l) async {
    await _p.setString('lang', l.name);
    notifyListeners();
  }

  /// How big the interface is drawn: normal (phones, tablets, desks), large, or classroom
  /// (a 75" board read from the back bench). The layouts are designed at classroom size and the
  /// whole app is scaled, so every screen keeps its proportions at any size.
  String get displaySize => _p.getString('displaySize') ?? 'normal';
  double get uiScale => switch (displaySize) { 'classroom' => 1.0, 'large' => 0.7, _ => 0.5 };
  Future<void> setDisplaySize(String v) async {
    await _p.setString('displaySize', v);
    notifyListeners();
  }

  Future<void> setKiosk(bool on) async {
    await _p.setBool('kiosk', on);
    notifyListeners();
  }

  /// Applies the config sent by the API (activation and sync).
  Future<void> apply(Map<String, dynamic> j) async {
    for (final e in j.entries) {
      final v = e.value;
      if (v is List) await _p.setStringList(e.key, v.cast<String>());
      if (v is String) await _p.setString(e.key, v);
      if (v is int) await _p.setInt(e.key, v);
      if (v is bool) await _p.setBool(e.key, v);
    }
    notifyListeners();
  }

  /// Self-Learning periods booked for this section (from sync), stored as JSON.
  List<ScheduledPeriod> get schedule {
    final raw = _p.getString('schedule');
    if (raw == null) return const [];
    return [for (final e in jsonDecode(raw) as List) ScheduledPeriod.fromJson(e as Map<String, dynamic>)];
  }

  ScheduledPeriod? scheduledNow(DateTime now) => schedule.where((p) => p.isNow(now)).firstOrNull;

  /// Last-known progress: topic ids taught in this section (drives the Continue card).
  List<String> get taught => _p.getStringList('taught') ?? const [];
  Future<void> markTaught(String topicId) async {
    if (taught.contains(topicId)) return;
    await _p.setStringList('taught', [...taught, topicId]);
    notifyListeners();
  }
}
