import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../blocks/embeds.dart';
import '../engine/licence.dart';
import '../engine/mastery.dart';
import '../engine/model.dart';
import '../engine/narrator.dart';
import '../engine/pack_store.dart';
import '../engine/session_log.dart';
import '../engine/auto_play.dart';
import '../engine/sync.dart';
import '../engine/voice.dart';
import '../features/app/school.dart';
import 'config.dart';

/// Everything the screens need, created once at start-up (main.dart) or by a test.
class Services {
  Services({
    required this.config,
    required this.store,
    required this.outbox,
    required this.narrator,
    required this.syllabus,
    required this.embeds,
    this.licenceKey = const [],
    this.voice,
    VoicePlayer Function()? voicePlayer,
    DateTime Function()? clock,
    MasteryStore? mastery,
    SchoolStore? school,
  }) : school = school ?? SchoolStore(now: clock),
       voicePlayer = voicePlayer ?? SilentVoicePlayer.new,
       clock = clock ?? DateTime.now,
       mastery = mastery ?? MasteryStore(now: clock);

  /// What this section knows, per topic and per roll number (lib/engine/mastery.dart).
  final MasteryStore mastery;

  /// Teachers, timetable, finished classes and class-tool results (lib/features/app/school.dart).
  final SchoolStore school;

  final BoardConfig config;
  final PackStore store;
  final Outbox outbox;
  final Narrator narrator;

  /// Downloaded chapter voices (narration audio packs); null: lessons are silent.
  final VoiceStore? voice;

  /// A new narration player for a lesson (just_audio on the board).
  final VoicePlayer Function() voicePlayer;

  /// subject → year → chapters (the whole NCERT tree, including chapters with no pack yet).
  final Map<String, Map<String, List<Chapter>>> syllabus;
  final Embeds embeds;

  /// Ed25519 public key that signs licences (assets/keys/licence-key.json).
  final List<int> licenceKey;

  Future<LicenceStatus> licence() => Licence.check(token: config.licenceToken, publicKey: licenceKey, now: clock());
  final DateTime Function() clock;
  late final SyncClient sync = SyncClient(config: config, store: store, outbox: outbox, voice: voice);

  /// Subjects shown on this board: the section's subjects that have a syllabus, in its order.
  List<String> get subjects => [
    for (final s in config.subjects)
      if (syllabus.containsKey(s)) s,
  ];

  /// The section's chapters for [subject] and [year], as its curriculum (board) teaches them.
  List<Chapter> chapters(String subject, String year) => [
    for (final c in syllabus[subject]?[year] ?? const <Chapter>[])
      if (c.forBoard(config.board)) c,
  ];

  /// The topic to continue with in this section: the next untaught topic in the chapter taught
  /// most recently, then the following chapters in syllabus order (this section's year first).
  ({InstalledPack pack, Lesson lesson})? nextTopic() {
    final taught = config.taught.toSet();
    final years = [config.year, config.year == 'puc1' ? 'puc2' : 'puc1'];
    final order = <Chapter>[
      for (final y in years)
        for (final s in subjects) ...chapters(s, y),
    ];
    var start = 0;
    if (config.taught.isNotEmpty) {
      final last = config.taught.last;
      final i = order.indexWhere((c) => last.startsWith('${c.id}.'));
      if (i >= 0) start = i;
    }
    for (final ch in [...order.skip(start), ...order.take(start)]) {
      final p = store.byChapter(ch.id);
      if (p == null) continue;
      for (final t in p.chapter.topicsFor(config.board)) {
        final l = p.lessons[t.id];
        if (l != null && !taught.contains(t.id)) return (pack: p, lesson: l);
      }
    }
    return null;
  }

  ({InstalledPack pack, Lesson lesson})? lessonFor(String topicId) {
    for (final p in store.packs) {
      final l = p.lessons[topicId];
      if (l != null) return (pack: p, lesson: l);
    }
    return null;
  }

  static Future<Map<String, Map<String, List<Chapter>>>> loadSyllabus(AssetBundle bundle) async {
    final index = jsonDecode(await bundle.loadString('assets/syllabus/index.json')) as Map<String, dynamic>;
    final out = <String, Map<String, List<Chapter>>>{};
    for (final s in (index['subjects'] as List).cast<Map<String, dynamic>>()) {
      final list = jsonDecode(await bundle.loadString('assets/syllabus/${s['file']}')) as List;
      (out[s['subject'] as String] ??= {})[s['year'] as String] = [for (final c in list) Chapter.fromJson(c as Map<String, dynamic>)];
    }
    return out;
  }

  /// Installs the packs shipped inside the APK (assets/packs) that are newer than what is on disk.
  static Future<void> installSeedPacks(PackStore store, AssetBundle bundle) async {
    final index = jsonDecode(await bundle.loadString('assets/packs/index.json')) as List;
    final have = store.installed();
    for (final p in index.cast<Map<String, dynamic>>()) {
      final cur = have[p['id']];
      if (cur != null && PackStore.compareVersions(cur, p['version'] as String) >= 0) continue;
      final data = await bundle.load('assets/packs/${p['file']}');
      await store.install(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
  }
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({super.key, required this.services, required super.child});
  final Services services;
  static Services of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ServicesScope>()!.services;
  @override
  bool updateShouldNotify(ServicesScope old) => old.services != services;
}
