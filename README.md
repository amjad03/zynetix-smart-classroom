# Zynetix Board APKs: production 1.0.0

Built from `main` at d68a9de. **Release-signed** with the Zynetix production key.

Signing certificate SHA-256: `8c4c01f3fb0ab2bb6cd6eb10ff61f6ad695507ebbc00c7ed55445897bb49306a` (CN=Zynetix Smart Classroom, O=Zynetix, Bengaluru).

| File | For |
|---|---|
| `zynetix-board-1.0.0-arm64-v8a.apk` | Most smartboards and tablets from the last few years (pick this if unsure) |
| `zynetix-board-1.0.0-armeabi-v7a.apk` | Older 32-bit ARM boards |

Each APK includes all 106 NCERT 1st/2nd PUC chapters (539 lessons, 2,625 questions) as signed content packs, so a board teaches with no internet from the first start. Android 7.0+.

If a board has the earlier **debug** test build, uninstall it first; Android won't update across signing keys.

Default PIN before activation: 1234. Long-press the clock for settings.
Kiosk (device owner): `adb shell dpm set-device-owner app.zynetix.board/.KioskAdminReceiver`

Check downloads against `SHA256SUMS`.
