import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../blocks/embeds.dart';
import '../engine/model.dart';
import '../engine/narrator.dart';
import '../engine/pack_store.dart';
import '../engine/session_log.dart';
import 'config.dart';

/// Everything the screens need, created once at start-up (main.dart) or by a test.
class Services {
  Services({required this.config, required this.store, required this.outbox, required this.narrator, required this.syllabus, required this.embeds, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  final BoardConfig config;
  final PackStore store;
  final Outbox outbox;
  final Narrator narrator;
  /// subject → year → chapters (the whole NCERT tree, including chapters with no pack yet).
  final Map<String, Map<String, List<Chapter>>> syllabus;
  final Embeds embeds;
  final DateTime Function() clock;

  /// The topic to continue with in this section: the first untaught topic of the first chapter
  /// (in syllabus order, this section's year first) that has a lesson installed.
  ({InstalledPack pack, Lesson lesson})? nextTopic() {
    final taught = config.taught.toSet();
    final years = [config.year, config.year == 'puc1' ? 'puc2' : 'puc1'];
    for (final y in years) {
      for (final s in syllabus.keys) {
        for (final ch in syllabus[s]?[y] ?? const <Chapter>[]) {
          final p = store.byChapter(ch.id);
          if (p == null) continue;
          for (final t in p.chapter.topics) {
            final l = p.lessons[t.id];
            if (l != null && !taught.contains(t.id)) return (pack: p, lesson: l);
          }
        }
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
