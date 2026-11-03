# Zynetix Smart Classroom

Zynetix School (formerly Quest Academy) on classroom smartboards for Karnataka PU colleges.
It covers NCERT 1st and 2nd PUC Physics, Chemistry, Maths and Biology, with a competitive
layer for KCET, COMEDK, NEET and JEE.

| Path | What it is | Tech |
|---|---|---|
| `apps/board` | Board app: kiosk-locked and offline-first, with **Teacher Mode** and **Self-Learning Mode** | Flutter (Android first) |
| `apps/admin` | College Admin: timetable, self-learning scheduler, syllabus heatmap, usage reports | Next.js |
| `apps/cms` | Content CMS: block editor, question bank (exam / difficulty / PYQ year), versioned packs | Next.js |
| `services/api` | Device activation, licences, content-pack sync, session logs | NestJS + PostgreSQL + S3 |
| `packages/lesson-schema` | Lesson, block, question, pack and log schema (single source of truth) | TypeScript + Zod |
| `tools/pack-builder` | Validates `content/` and builds signed `.zpack` files | Node |
| `content/` | NCERT syllabus tree and the seeded chapters | JSON |

The design is described in [docs/architecture.md](docs/architecture.md). The board reuses
the 3D models, labs, simulations, animations and ink engine from
[Zynetix Board (amjad03/Kinetix)](https://github.com/amjad03/Kinetix) as pinned git
dependencies.

## Rules

- Works with no internet.
- Big tap targets, readable from the back bench.
- At most 3 taps to start a lesson.
- No student personal data: roll numbers only.

## Screenshots

Board screens are 1920×1080 and rendered with the app's own fonts (`apps/board/screenshots/`). In these renders, 3D models and PhET pages show a labelled card, because they run in a WebView on the board.

| Board | |
|---|---|
| ![Home](apps/board/screenshots/png/01-home.png) | ![Home in Kannada](apps/board/screenshots/png/02-home-kannada.png) |
| ![Teacher Mode](apps/board/screenshots/png/03-teacher-mode.png) | ![Lesson intro](apps/board/screenshots/png/04-player-intro.png) |
| ![Concept with formula](apps/board/screenshots/png/05-player-concept-formula.png) | ![Kinetix virtual lab](apps/board/screenshots/png/06-player-virtual-lab.png) |
| ![Worked example](apps/board/screenshots/png/07-player-example.png) | ![Roll-call quiz](apps/board/screenshots/png/08-quiz-roll-call.png) |
| ![Team challenge](apps/board/screenshots/png/09-quiz-team-challenge.png) | ![Pen over a lesson](apps/board/screenshots/png/10-player-pen.png) |
| ![Self-Learning period](apps/board/screenshots/png/11-self-learning.png) | ![Teacher PIN](apps/board/screenshots/png/12-teacher-pin.png) |
| ![Smartboard with the Insert panel](apps/board/screenshots/png/13-smartboard-insert.png) | ![Whiteboard block, step by step](apps/board/screenshots/png/14-player-whiteboard.png) |
| ![Function-plot interactive](apps/board/screenshots/png/15-player-interactive-plot.png) | ![Exam Practice](apps/board/screenshots/png/16-exam-practice.png) |
| ![Numeric question with keypad](apps/board/screenshots/png/17-quiz-numeric-keypad.png) | |

| College Admin | Content CMS |
|---|---|
| ![Usage](docs/screenshots/admin-01-usage.png) | ![Packs](docs/screenshots/cms-01-packs.png) |
| ![Self-learning scheduler](docs/screenshots/admin-02-self-learning-scheduler.png) | ![Block editor](docs/screenshots/cms-02-block-editor.png) |
| ![Syllabus heatmap](docs/screenshots/admin-04-syllabus-heatmap.png) | ![Question bank](docs/screenshots/cms-03-question-bank.png) |
| ![Timetable](docs/screenshots/admin-03-timetable.png) | ![Boards](docs/screenshots/admin-05-boards.png) |

The Admin usage and heatmap screens show demo lesson logs generated for the screenshots.

## Run it

```bash
pnpm install && pnpm build          # schema, pack builder, API, web apps
pnpm packs                          # validate + sign content packs into the board app

# API (PostgreSQL 16 on localhost; see services/api/README.md)
cd services/api && pnpm db:migrate && pnpm db:seed && pnpm start:dev     # :4000

# College Admin (:3001, admin@demo-pu.in) and Content CMS (:3002, editor@zynetix.in), password zynetix123
cd apps/admin && pnpm dev
cd apps/cms && pnpm dev

# Board (Flutter 3.47+, Android SDK for the APK)
cd apps/board && flutter test && flutter run
```

Tests:

| Package | Tests |
|---|---|
| lesson-schema | 4 (vitest) |
| pack-builder | 5 (vitest) |
| api | 9 end-to-end tests against PostgreSQL (jest) |
| cms | 6 (vitest) |
| board | 45 (flutter test) |

The Admin and CMS apps were also smoke-tested end to end in Chromium against the seeded API.
