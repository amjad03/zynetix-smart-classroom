import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'blocks/embeds.dart';
import 'core/config.dart';
import 'core/kiosk.dart';
import 'core/services.dart';
import 'core/theme.dart';
import 'core/ui_scale.dart';
import 'engine/mastery.dart';
import 'engine/narrator.dart';
import 'engine/pack_store.dart';
import 'engine/session_log.dart';
import 'features/home.dart';
import 'features/self_learning.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final dir = await getApplicationSupportDirectory();
  final key = parseTrustedKey(await rootBundle.loadString('assets/packs/trusted-key.json'));
  final store = PackStore(Directory('${dir.path}/packs'), trustedKeys: {key.key: key.value})..loadAll();
  await Services.installSeedPacks(store, rootBundle);
  final config = await BoardConfig.load();
  final services = Services(
    config: config,
    store: store,
    outbox: Outbox(File('${dir.path}/outbox.jsonl')),
    narrator: DeviceNarrator(),
    syllabus: await Services.loadSyllabus(rootBundle),
    embeds: KinetixEmbeds(),
    licenceKey: parseTrustedKey(await rootBundle.loadString('assets/keys/licence-key.json')).value,
    mastery: MasteryStore(file: File('${dir.path}/mastery.jsonl')),
  );
  if (config.kioskOn) unawaited(Kiosk.enter());
  runApp(ZynetixBoardApp(services: services));
}

class ZynetixBoardApp extends StatefulWidget {
  const ZynetixBoardApp({super.key, required this.services, this.home = const HomeScreen()});
  final Services services;
  final Widget home;
  @override
  State<ZynetixBoardApp> createState() => _ZynetixBoardAppState();
}

class _ZynetixBoardAppState extends State<ZynetixBoardApp> {
  final _nav = GlobalKey<NavigatorState>();
  Timer? _watch;

  @override
  void initState() {
    super.initState();
    // A scheduled Self-Learning period starts by itself when the board is on Home.
    _watch = Timer.periodic(const Duration(seconds: 30), (_) => _checkSchedule());
    // Sync whenever there is a connection; failures are normal (offline) and silent.
    _sync = Timer.periodic(const Duration(minutes: 15), (_) => _trySync());
    _trySync();
  }

  Timer? _sync;
  Future<void> _trySync() async {
    try {
      await widget.services.sync.sync();
    } catch (_) {}
  }

  void _checkSchedule() {
    final s = widget.services, nav = _nav.currentState;
    if (nav == null || nav.canPop()) return; // someone is teaching: never interrupt
    final p = s.config.scheduledNow(s.clock());
    final l = p == null ? null : s.lessonFor(p.topicId);
    if (p == null || l == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => SelfLearningScreen(pack: l.pack, lesson: l.lesson, periodSeconds: p.secondsLeft(s.clock())),
      ),
    );
  }

  @override
  void dispose() {
    _watch?.cancel();
    _sync?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ServicesScope(
    services: widget.services,
    child: MaterialApp(
      navigatorKey: _nav,
      title: 'Zynetix Smart Classroom',
      debugShowCheckedModeBanner: false,
      theme: zynetixTheme(),
      home: widget.home,
      builder: (context, child) => ListenableBuilder(
        listenable: widget.services.config,
        builder: (context, _) => UiScale(scale: widget.services.config.uiScale, child: child!),
      ),
    ),
  );
}
