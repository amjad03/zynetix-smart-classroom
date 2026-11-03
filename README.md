# Zynetix Board APKs (test builds)

Built from `main` at commit 51908fe. **Signed with the Android debug key: for testing only.**

| File | For |
|---|---|
| `zynetix-board-1.0.0-arm64-v8a.apk` | Most smartboards and tablets from the last few years (pick this if unsure) |
| `zynetix-board-1.0.0-armeabi-v7a.apk` | Older 32-bit ARM boards |

Each includes the two seed chapters and the NCERT syllabus. Android 7.0+. Check downloads against `SHA256SUMS`.
Default PIN before activation: 1234. Long-press the clock for settings.
Kiosk (device owner): `adb shell dpm set-device-owner app.zynetix.board/.KioskAdminReceiver`
