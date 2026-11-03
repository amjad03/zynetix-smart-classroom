import 'package:flutter/material.dart';

import '../core/kiosk.dart';
import '../core/services.dart';
import '../core/theme.dart';
import 'pin.dart';

/// Hidden behind a long press on the clock and the teacher PIN: kiosk on/off and sync.
Future<void> openSettings(BuildContext context) async {
  final s = ServicesScope.of(context);
  if (!await askPin(context, s.config) || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: s.config,
      builder: (ctx, _) => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s.config.collegeName} · ${s.config.sectionLabel}', style: Theme.of(ctx).textTheme.headlineMedium),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Kiosk lock', style: TextStyle(fontSize: 34)),
            subtitle: const Text('Students cannot leave the app. Exit needs this PIN.', style: TextStyle(fontSize: 24)),
            value: s.config.kioskOn,
            onChanged: (on) async {
              await (on ? Kiosk.enter() : Kiosk.exit());
              await s.config.setKiosk(on);
            },
          ),
          const SizedBox(height: 16),
          Text('Packs: ${s.store.packs.map((p) => '${p.id} ${p.version}').join(', ')}', style: const TextStyle(fontSize: 22)),
          Text('Logs waiting to sync: ${s.outbox.pending().length}', style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 24),
          BigButton(icon: Icons.close, label: 'Close', filled: false, onPressed: () => Navigator.pop(ctx)),
        ]),
      ),
    ),
  );
}
