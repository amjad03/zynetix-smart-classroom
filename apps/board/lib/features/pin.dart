import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engine/model.dart';

/// Asks for the teacher PIN on a large keypad. Returns true when it is right.
/// Five wrong tries lock the keypad for a minute (students will try).
Future<bool> askPin(BuildContext context, BoardConfig config) async =>
    await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => PinDialog(config: config)) ?? false;

class PinDialog extends StatefulWidget {
  const PinDialog({super.key, required this.config});
  final BoardConfig config;
  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  static int _wrong = 0;
  static DateTime? _lockedUntil;
  String pin = '';
  bool error = false;

  Lang get l => widget.config.lang;
  bool get locked => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  void _key(String k) {
    if (locked) return;
    setState(() {
      error = false;
      if (k == '⌫') {
        if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
      } else if (pin.length < 6) {
        pin += k;
      }
    });
  }

  void _ok() {
    if (widget.config.checkPin(pin)) {
      _wrong = 0;
      Navigator.pop(context, true);
      return;
    }
    if (++_wrong >= 5) {
      _lockedUntil = DateTime.now().add(const Duration(minutes: 1));
      _wrong = 0;
    }
    setState(() {
      pin = '';
      error = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget key(String k) => Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 130,
            height: Z.tap,
            child: OutlinedButton(key: ValueKey('pin-$k'), onPressed: () => _key(k), child: Text(k, style: const TextStyle(fontSize: 44))),
          ),
        );
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('enterPin', l), style: text.headlineLarge),
          const SizedBox(height: 16),
          Text(pin.isEmpty ? '—' : '●' * pin.length, style: const TextStyle(fontSize: 56, letterSpacing: 12)),
          if (error || locked) Text(locked ? '${tr('wrongPin', l)} · 60s' : tr('wrongPin', l), style: const TextStyle(fontSize: 30, color: Z.wrong)),
          const SizedBox(height: 16),
          for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['⌫', '0']]) Row(mainAxisSize: MainAxisSize.min, children: [for (final k in row) key(k)]),
          const SizedBox(height: 16),
          Row(mainAxisSize: MainAxisSize.min, children: [
            BigButton(icon: Icons.close, label: tr('cancel', l), filled: false, onPressed: () => Navigator.pop(context, false)),
            const SizedBox(width: 24),
            BigButton(key: const ValueKey('pin-ok'), icon: Icons.lock_open, label: tr('exit', l), onPressed: pin.length >= 4 && !locked ? _ok : null),
          ]),
        ]),
      ),
    );
  }
}
