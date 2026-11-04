# Zynetix Board APKs: production 1.5.2

Built from `main` at cc05191. **Release-signed** with the Zynetix production key.

Signing certificate SHA-256: `8c4c01f3fb0ab2bb6cd6eb10ff61f6ad695507ebbc00c7ed55445897bb49306a` (CN=Zynetix Smart Classroom, O=Zynetix, Bengaluru).

| File | For |
|---|---|
| `zynetix-board-1.5.2-arm64-v8a.apk` | Most smartboards and tablets from the last few years (pick this if unsure) |
| `zynetix-board-1.5.2-armeabi-v7a.apk` | Older 32-bit ARM boards |

Each APK includes all 337 chapter packs (12 subjects, 1st and 2nd PUC / Class XI and XII, Karnataka PU, CBSE and ISC) as signed content packs, each with whiteboard explanations, interactives, 3D models, simulations and virtual labs, plus KCET, COMEDK, NEET, JEE Main, JEE Advanced and CUET practice. A board teaches with no internet from the first start. Installing over 1.0.0 or 1.1.0 keeps settings and updates every chapter.

1.5.0: new rounded design with Inter and Poppins on every screen; ISC (CISCE) Science and Commerce added (Physics, Chemistry, Maths, Biology, Computer Science in Java, English, Accountancy, Commerce, Economics, Business Studies), English only; 128 Zynetix Board 3D models and 166 virtual labs placed in the topics they fit, with Kannada and a "Try this" step.

1.4.0: a simulation or activity with full controls in every one of the 1,332 lessons (animated scenes with play, pause, speed and scrub; toggles, choices, buttons and draggable handles; sort, order, match, label, hotspot and fill activities).

1.3.0: the board now knows every roll number. Mastery map, re-teach another way when the class misses, exam readiness, today's plan, homework sheets, hands-up roll grid, phone quiz over the board's own Wi-Fi, paper marks, playable challenges, Game Zone (missions, boss battles, badges, section league).

1.2.0: the app is drawn at normal phone and tablet size, works upright and sideways, and fits every screen. On a 75" classroom board, choose Settings → Display size → Classroom board (long-press the clock, then the PIN). Android 7.0+.

If a board has the earlier **debug** test build, uninstall it first; Android won't update across signing keys.

Default PIN before activation: 1234. Long-press the clock for settings.
Kiosk (device owner): `adb shell dpm set-device-owner app.zynetix.board/.KioskAdminReceiver`

Check downloads against `SHA256SUMS`.
