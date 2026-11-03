import 'package:flutter/services.dart';

/// Android lock-task kiosk, ported from the Kinetix board (android/…/Kiosk.kt). As device owner
/// (`adb shell dpm set-device-owner in.zynetix.zynetix_board/.KioskAdminReceiver`) the board
/// locks fully and becomes the home app; otherwise Android falls back to screen pinning.
abstract final class Kiosk {
  static const _ch = MethodChannel('zynetix/kiosk');

  static Future<Map<String, dynamic>> _call(String m, [Map<String, dynamic>? a]) async {
    try {
      return Map<String, dynamic>.from(await _ch.invokeMethod<Map<Object?, Object?>>(m, a) ?? const {});
    } on MissingPluginException {
      return const {'lockTask': 'unsupported'}; // Linux desktop, tests
    } on PlatformException catch (e) {
      return {'lockTask': 'error', 'error': e.message};
    }
  }

  static Future<Map<String, dynamic>> enter() => _call('enter');
  static Future<Map<String, dynamic>> exit() => _call('exit', {'keepBootLaunch': false});
  static Future<Map<String, dynamic>> status() => _call('status');
}
