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
| cms | 4 (vitest) |
| board | 18 (flutter test) |

The Admin and CMS apps were also smoke-tested end to end in Chromium against the seeded API.
