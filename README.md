# Zynetix Board APKs: production 2.0.0

Built from `main` at 2bbd2e69. **Release-signed** with the Zynetix production key.

Signing certificate SHA-256: `8c4c01f3fb0ab2bb6cd6eb10ff61f6ad695507ebbc00c7ed55445897bb49306a` (CN=Zynetix Smart Classroom, O=Zynetix, Bengaluru).

| File | For |
|---|---|
| `zynetix-board-2.0.0-arm64-v8a.apk` | Most smartboards and tablets from the last few years (pick this if unsure) |
| `zynetix-board-2.0.0-armeabi-v7a.apk` | Older 32-bit ARM boards |

Each APK includes all 337 chapter packs (12 subjects, 1st and 2nd PUC / Class XI and XII, Karnataka PU, CBSE and ISC) as signed content packs, each with whiteboard explanations, interactives, 3D models, simulations and virtual labs, plus KCET, COMEDK, NEET, JEE Main, JEE Advanced and CUET practice. A board teaches with no internet from the first start. Installing over any earlier release-signed build keeps settings and updates every chapter.

2.0.0: a new, simple-first app in the Zynetix School look. First open asks the language (English or Kannada), then "Who's teaching today?" (tap your name, no PIN unless the school turns PINs on), and Home shows your class on now from the timetable with one big "Start my class" that opens the lesson where it was left. A short voice guide runs the first time, and a practice class lets a teacher try everything without saving. The lesson has big Back and Next, Write, Board, Read aloud and Help; "What do I do now?" with Show me, Undo and Call for help is on every screen. Quiz the class by tapping the roll numbers who got it right; Finish class saves the lesson, homework and attendance (roll numbers only) to the class history. "Show all tools" reveals Today, Teach, Smartboard, Class tools (quiz, mock tests, formula drill, teams, class plan, mastery heatmap, worksheets as PDF), Library and Reports. New Smartboard: simple tools by default, all tools on demand (shapes, text, ruler, protractor, compass, set square, graph, number line, backgrounds, pages), pictures and PowerPoint slides, 3D models, labs and simulations as live objects, the chapter's subject kit, each lesson step as a page, recording, projector view and phone as remote. PUC content from Zynetix School: explainers, exam questions (NEET, JEE, KCET, COMEDK), formula sheets and mock test patterns in 160 chapters; concept videos stream only when online and are labelled "Needs internet". No AI features and no camera anywhere. Settings and teachers are behind the school PIN from the teacher menu.

1.6.0: lessons now play in a video style (hook, objectives, step-by-step reveals, worked solutions, recall recaps) in every chapter; download English voice narration per chapter (voice files are still being rendered and published, so most chapters have none to download yet); auto-play keeps narration, reveals and highlights in sync; labs and 3D models show larger and get a "Try this" step; audit fixes (periodic-table group name, Zener circuit, double-overline symbol, minimum text size on charts, Kannada titles and labels on most interactives).

1.5.0: new rounded design with Inter and Poppins on every screen; ISC (CISCE) Science and Commerce added (Physics, Chemistry, Maths, Biology, Computer Science in Java, English, Accountancy, Commerce, Economics, Business Studies), English only; 128 Zynetix Board 3D models and 166 virtual labs placed in the topics they fit, with Kannada and a "Try this" step.

1.4.0: a simulation or activity with full controls in every one of the 1,332 lessons (animated scenes with play, pause, speed and scrub; toggles, choices, buttons and draggable handles; sort, order, match, label, hotspot and fill activities).

1.3.0: the board now knows every roll number. Mastery map, re-teach another way when the class misses, exam readiness, today's plan, homework sheets, hands-up roll grid, phone quiz over the board's own Wi-Fi, paper marks, playable challenges, Game Zone (missions, boss battles, badges, section league).

1.2.0: the app is drawn at normal phone and tablet size, works upright and sideways, and fits every screen. On a 75" classroom board, choose Settings → Display size → Classroom board (long-press the clock, then the PIN). Android 7.0+.

If a board has the earlier **debug** test build, uninstall it first; Android won't update across signing keys.

Default school PIN before activation: 1234 (Settings, from the teacher menu on Home).
Kiosk (device owner): `adb shell dpm set-device-owner app.zynetix.board/.KioskAdminReceiver`

Check downloads against `SHA256SUMS`.

---

# Zynetix Classroom content pack: PUC PhET sims (phet-1)

`zynetix-content-phet-1.zip` (51.2 MB, Git LFS): a `zynetix-content-pack` (formatVersion 1) with 47 PhET HTML5 simulations for 1st and 2nd PUC Physics, Chemistry, Biology and Maths topics that the Classroom APK does not ship, each mapped to its lesson topics. Zynetix Classroom 1.2.0+ updates from it by default (Settings → This board → Content → Update over Wi-Fi), or install it from USB. The lessons show a topic's sim as a step when the pack has it. Built by amjad03/kinetix `packages/kinetix_lessons/tool/build_phet_pack.py`.

The simulations are by **PhET Interactive Simulations, University of Colorado Boulder** (https://phet.colorado.edu), licensed under CC BY 4.0, unchanged English pages; the zip carries `PHET-LICENSE.txt`.

---

# Zynetix Classroom APKs: 1.1.0

Zynetix Board — Classroom edition (`in.zynetix.classroom`, "Zynetix Classroom"), version 1.1.0 (versionCode 2002 arm64-v8a / 1002 armeabi-v7a), built from amjad03/kinetix `claude/classroom-edition` (ce57aae4). **Release-signed** with the Zynetix production key (same certificate as above). Installs over 1.0.0, keeping classes, marks and boards. Android 9.0+.

| File | For | Size |
|---|---|---|
| `zynetix-classroom-1.1.0-arm64-v8a.apk` | Most smartboards and tablets from the last few years (pick this if unsure) | 90.8 MB |
| `zynetix-classroom-1.1.0-armeabi-v7a.apk` | Older 32-bit ARM boards | 90.8 MB |

1.1.0: half the download (only the sims and 3D models the lessons use; no camera, casting, speech or handwriting plugins); Settings → This board → Check for update (reads `classroom-update.json` here, checks the SHA-256) and Install from USB…, with a quiet dot on Settings when an update waits; Open Zynetix when the board starts (no device owner) and Make Zynetix the home app; Save PDF to USB / Downloads beside every Print, and Save first on boards with no print service; Python in the Computer Science lessons runs offline; a quicker start on slow panels; no Android cloud backup of the settings (the school PIN's hash).

`classroom-update.json` is the update manifest the app reads. Stored with Git LFS like 1.0.0.

---

# Zynetix Classroom APKs: 1.0.0

Zynetix Board — Classroom edition (`in.zynetix.classroom`, "Zynetix Classroom"), version 1.0.0 (build 1), built from amjad03/kinetix `claude/classroom-edition`. **Release-signed** with the Zynetix production key (same certificate as above). It installs next to the Zynetix Board.

| File | For |
|---|---|
| `zynetix-classroom-1.0.0-arm64-v8a.apk` | Most smartboards and tablets from the last few years (pick this if unsure) |
| `zynetix-classroom-1.0.0-armeabi-v7a.apk` | Older 32-bit ARM boards |

For PU colleges without the Zynetix ERP: no AI anywhere, works offline from the board's own timetable, teachers and classes (roll numbers only, school PIN 1234), and opens on the Simple board. Lessons: every 1st and 2nd PUC chapter bundled (step by step, Read aloud, English / Kannada, Put on board). Class tools: class quiz by roll number, mock tests (PUC and entrance patterns, print / PDF with answer key), formula drill, teams, class plan, mastery map, worksheets. Phones show the whole board scaled to fit. Android 7.0+.

These two files are stored with Git LFS (each is over GitHub's 100 MB limit); the download links work the same way.
