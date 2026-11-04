# Zynetix API

Built with NestJS, PostgreSQL 16 (plain SQL in `migrations/`) and S3 in ap-south-1. Without `S3_BUCKET` it uses local disk.

| Area | Endpoints |
|---|---|
| Auth | `POST /v1/auth/login` returns a staff JWT. Roles are `admin` (one college), `editor` (content team) and `super`. |
| Boards | `POST /v1/devices/activate` takes a one-time code plus a PIN chosen on the board. `POST /v1/board/sync` sends logs up and brings packs, timetable, Self-Learning schedule, config and a signed licence down. |
| Admin | Sections, boards, activation codes, board PIN reset, timetable, the Self-Learning scheduler, `reports/syllabus` (heatmap) and `reports/usage`. |
| Outcomes | `GET /v1/admin/outcomes` (per section × subject: class mastery by week, topics taught vs mastered, share of roll numbers stuck per topic, lecturer), `outcomes/sections/:id?subject=` (topics × roll numbers), `outcomes/sections/:id/rolls/:roll`, `outcomes/readiness` (Exam-ready / On track / Needs work / Not enough data per exam), `outcomes/league?weeks=`, `outcomes/report?month=YYYY-MM`. Each synced answer is stored once in `answer` (topic from the log, else the question bank). Boards get this week's league in `config.league` (a JSON string). |
| CMS | Chapters/topics, the question bank (filter by exam, difficulty, PYQ year, text), lesson drafts validated against the schema and question bank, media upload, and `POST packs/:id/versions`, which builds, signs and stores a new pack version. |

Privacy:
- Session logs are validated with the strict `SessionLog` schema, so any extra field (a name, for example) rejects the log.
- The section always comes from the device, never from the board's claim.

Licences:
- Licences are signed with Ed25519, and the board checks them offline.
- After expiry there are 30 days' grace, during which teaching and logging continue.
- After the grace period, teaching and logging still continue, but no new packs are sent.

```bash
cp .env.example .env
pnpm db:migrate && pnpm db:seed   # admin@demo-pu.in / editor@zynetix.in, password zynetix123; board code DEMO1PUC
pnpm start:dev                    # http://localhost:4000
pnpm db:seed:demo                 # optional: 9 weeks of clearly-marked demo answers for the Outcomes pages
pnpm test                         # end-to-end tests (zynetix_test database) + Outcomes maths unit tests
```
