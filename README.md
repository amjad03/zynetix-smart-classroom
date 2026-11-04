# Zynetix Board APKs: production 1.2.0

Built from `main` at bdf8792. **Release-signed** with the Zynetix production key.

Signing certificate SHA-256: `8c4c01f3fb0ab2bb6cd6eb10ff61f6ad695507ebbc00c7ed55445897bb49306a` (CN=Zynetix Smart Classroom, O=Zynetix, Bengaluru).

| File | For |
|---|---|
| `zynetix-board-1.2.0-arm64-v8a.apk` | Most smartboards and tablets from the last few years (pick this if unsure) |
| `zynetix-board-1.2.0-armeabi-v7a.apk` | Older 32-bit ARM boards |

Each APK includes all 270 chapters (11 subjects, 1st and 2nd PUC, Karnataka PU and CBSE) as signed content packs, each with whiteboard explanations, interactives, 3D models, simulations and virtual labs, plus KCET, COMEDK, NEET, JEE Main, JEE Advanced and CUET practice. A board teaches with no internet from the first start. Installing over 1.0.0 or 1.1.0 keeps settings and updates every chapter.

1.2.0: the app is drawn at normal phone and tablet size, works upright and sideways, and fits every screen. On a 75" classroom board, choose Settings → Display size → Classroom board (long-press the clock, then the PIN). Android 7.0+.

If a board has the earlier **debug** test build, uninstall it first; Android won't update across signing keys.

Default PIN before activation: 1234. Long-press the clock for settings.
Kiosk (device owner): `adb shell dpm set-device-owner app.zynetix.board/.KioskAdminReceiver`

Check downloads against `SHA256SUMS`.
