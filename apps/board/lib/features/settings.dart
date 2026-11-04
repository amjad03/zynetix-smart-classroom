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
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: s.config,
      builder: (ctx, _) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text('Display size', style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'normal',
                    label: Text('Normal', style: zText(28)),
                  ),
                  ButtonSegment(
                    value: 'large',
                    label: Text('Large', style: zText(28)),
                  ),
                  ButtonSegment(
                    value: 'classroom',
                    label: Text('Classroom board', style: zText(28)),
                  ),
                ],
                selected: {s.config.displaySize},
                onSelectionChanged: (v) => s.config.setDisplaySize(v.first),
              ),
              const SizedBox(height: 24),
              Text('Chapters installed: ${s.store.packs.length}', style: const TextStyle(fontSize: 22)),
              Text('Logs waiting to sync: ${s.outbox.pending().length}', style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  if (!s.config.activated) BigButton(icon: Icons.qr_code_2, label: 'Activate board', onPressed: () => _activate(ctx, s)),
                  if (s.config.activated)
                    BigButton(
                      icon: Icons.sync,
                      label: 'Sync now',
                      onPressed: () async {
                        final msg = await s.sync.sync().then((n) => 'Synced. $n new pack(s).', onError: (Object e) => 'Offline or failed: $e');
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontSize: 26))));
                      },
                    ),
                  BigButton(icon: Icons.close, label: 'Close', filled: false, onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// First set-up by IT: server, the code from Admin → Boards, a name, and the teacher PIN.
Future<void> _activate(BuildContext context, Services s) async {
  final api = TextEditingController(text: s.config.apiBase), code = TextEditingController(), name = TextEditingController(text: 'Board'), pin = TextEditingController();
  const style = TextStyle(fontSize: 30);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Activate board', style: TextStyle(fontSize: 40)),
      content: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: api,
              style: style,
              decoration: const InputDecoration(labelText: 'Server'),
            ),
            TextField(
              controller: code,
              style: style,
              decoration: const InputDecoration(labelText: 'Activation code'),
            ),
            TextField(
              controller: name,
              style: style,
              decoration: const InputDecoration(labelText: 'Board name (room)'),
            ),
            TextField(
              controller: pin,
              style: style,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New teacher PIN (4–6 digits)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: style),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Activate', style: style),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await s.sync.activate(apiBase: api.text.trim(), code: code.text, name: name.text, pin: pin.text);
    await s.sync.sync();
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e', style: style)));
  }
}
