import 'package:flutter/services.dart';

/// Other apps on the board (MainActivity.kt answers `zynetix/apps`): is one installed, and
/// opening it. Off Android (tests, desktop) nothing is installed.
abstract final class Apps {
  static const _ch = MethodChannel('zynetix/apps');

  /// The full Zynetix Board (Kinetix) app.
  static const kinetixBoard = 'in.kinetix.board';

  static Future<bool> isInstalled(String package) async {
    try {
      return await _ch.invokeMethod<bool>('isInstalled', {'package': package}) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> launch(String package) async {
    try {
      return await _ch.invokeMethod<bool>('launch', {'package': package}) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
