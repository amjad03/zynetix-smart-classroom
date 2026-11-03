# Zynetix Board app

The Flutter board app, Android first. It works offline and can be locked as a kiosk.

- **Home:** Teacher Mode, Self-Learning Mode, and a one-tap **Continue** card. Long-press the clock and enter the PIN to open settings (kiosk, packs, outbox).
- **Teacher Mode:** subject tabs list the chapters with their topics open, so a lesson starts in 3 taps. The player controls are Back · Pause · Next · Pen · Quiz · Read aloud · EN/ಕನ್ನಡ.
- **Self-Learning:** `PeriodPlanner` builds a timed script (lesson → examples → class quiz → recap → homework) and `PeriodRunner` runs it, reading each block aloud with the device TTS. Only the teacher PIN exits. Scheduled periods start by themselves when the board is on Home.
- **Participation:** monitor pad, random roll picker (absent rolls skipped, each roll called once per round) and team challenge. Logs carry roll numbers only.
- **Blocks:** `lib/blocks/`. The 3D, lab, animation and pen pieces come from the Kinetix packages (`lib/blocks/embeds.dart`), and PhET pages are served from the pack on 127.0.0.1.
- **Packs:** `lib/engine/pack_store.dart` checks the Ed25519 signature and every SHA-256 before installing a pack. The seed packs in `assets/packs` are installed on first run.

```bash
flutter pub get
flutter test                 # 17 tests: packs, period planner/runner, roll picker, 3-tap start, PIN exit
flutter build apk --release  # needs the Android SDK
```

Kiosk, as device owner:

```bash
adb shell dpm set-device-owner in.zynetix.zynetix_board/.KioskAdminReceiver
```

Default PIN before activation: `1234`. Activation replaces it.
