# Zynetix Smart Classroom — architecture

Zynetix School (formerly Quest Academy) on classroom smartboards in Karnataka PU colleges.
Students have no phones and teachers are not tech-savvy. The design follows from four rules:

| Rule | What it means in the design |
|---|---|
| Works with no internet | Content arrives as signed packs and is installed on the board. Everything the board does (lessons, sims, labs, 3D, quizzes, Self-Learning, PIN) runs from local storage. Logs queue in an outbox and sync whenever a connection appears. |
| Readable from the back bench | Board theme: body text ≥ 32 px, headings ≥ 56 px, tap targets ≥ 96 px, high contrast, no hover-only UI. |
| At most 3 taps to start a lesson | Home → **Continue** card (1 tap) or Teacher Mode → subject tab → topic **Start** (3 taps). Chapters are expanded lists on the subject tab, not a separate screen. |
| No student personal data | A class is a *section* with a roll count. Logs carry roll numbers and answers only. The schema has no name fields, and the API rejects unknown fields. |

## Pieces

```
apps/board          Flutter (Android first). Kiosk-locked. Teacher Mode + Self-Learning Mode.
apps/admin          Next.js. College admin: timetable, self-learning scheduler, syllabus heatmap, usage.
apps/cms            Next.js. Content team: block editor, question bank, pack versions & publishing.
services/api        NestJS + PostgreSQL (Prisma) + S3. Activation, licences, pack sync, session logs.
packages/lesson-schema   Zod types: the single source of truth for blocks, lessons, questions, packs, logs.
packages/web-ui     Shared React UI for admin and cms.
tools/pack-builder  Validates content/ and builds signed .zpack files.
content/            Syllabus tree (NCERT 1st/2nd PUC) + seeded chapter sources.
```

## Reuse of Zynetix Board (amjad03/Kinetix)

The board app depends on the Kinetix Flutter packages as **git dependencies pinned to one
commit** (`6db5f65`). It does not copy them, so fixes made in Kinetix reach both products.

| Lesson block | Kinetix source | Widget |
|---|---|---|
| `3d_model` | `kinetix_3d` (46 offline three.js models, en/hi/kn labels) | `Model3dViewer(modelId, variant, lang)` |
| `simulation` · `animation` | `kinetix_animations` (29 captioned animations) | `AnimationPlayer(animation: animationById(id))` |
| `simulation` · `kinetix_sim` | `kinetix_labs` simulations (graph plotter, pendulum, lens/mirror, Ohm's law) | `LabView(id, preset)` |
| `simulation` · `phet` | PhET HTML5 sims, as Kinetix bundles them (CC-BY 4.0) | WebView on a loopback server (pattern from the Kinetix board's `SimAssetServer`) |
| `virtual_lab` | `kinetix_labs` benches (116 labs, 37 Class 11 + 48 Class 12) | `LabView(id)` |
| Pen control | `kinetix_ink` | `InkCanvas(controller, transparent: true)` over the block |
| Theme | `kinetix_ui` design tokens | scaled up for the back bench |
| Kiosk | Kinetix board `Kiosk.kt` (lock task as device owner) | ported into `apps/board/android` |

PhET sims are not shipped in the APK. Each pack carries only the sims its lessons use, under `media/phet/`.

## Lesson model

A **lesson** covers one topic and is an ordered list of **blocks**:
`intro, concept, 3d_model, simulation, virtual_lab, example, class_quiz, pyq, trick, recap`
(and `whiteboard, interactive, challenge, activity`). From the Zynetix School import
(tools/school-import): `explainer` (misconception, watch steps, try it, story, "it's like") and
`concept_video` (the owner's own YouTube or Drive videos; streamed when online, a "Needs internet"
card offline, never downloaded).
Every block can have a bilingual `narration` (read aloud by device TTS, `en-IN` / `kn-IN`)
and a `seconds` hint for Self-Learning.

### Teacher Mode

The player has big **Back · Pause · Next · Pen · Quiz** controls. The teacher drives the lesson.
- **Quiz** pulls a quick 3-question class quiz from the topic's question bank at any point.
- **Pen** draws over any block, and the ink is cleared when the block changes.

### Self-Learning Mode

`PeriodPlanner` turns a topic's lesson into a timed period script that fits the period length:

1. **Narrated lesson:** intro, concepts, 3D, sims and labs, each read aloud and auto-advanced.
2. **Examples:** steps revealed one by one, in time with the narration.
3. **Class quiz:** the class answers together (see below).
4. **Recap.**
5. **Homework:** stays on screen until the period ends.

If the period is short, optional blocks are dropped first, then sims and labs are shortened.
Only the teacher PIN exits. Admin can schedule a Self-Learning period for an absent teacher,
and the board starts it on its own at the scheduled time. The timetable is cached on the board.

### Class participation (no phones)

- **Monitor pad:** after a show of hands, the class monitor taps the class's answer (A–D).
- **Roll picker:** picks a random roll number from 1…N, skipping rolls marked absent for that
  session. The monitor marks the answer right or wrong.
- **Team challenge:** rolls are split into 2–4 teams (odd/even or ranges). Teams take turns and a scoreboard shows the totals.

## Content packs

A pack is a `.zpack` zip containing `manifest.json`, `manifest.sig`, `chapter.json`, `questions.json`, `lessons/*.json` and `media/**`, and `formulas.json` (the chapter's formula sheet, for the class tools' formula drill) when it has one.
- `manifest.json` lists the SHA-256 of every other file.
- `manifest.sig` is an Ed25519 signature over the manifest bytes.
- The board checks the signature against built-in public keys (identified by `keyId`) and then every hash, before it installs a pack.
- Versions are semver, and a newer version replaces an older one in a single atomic directory swap.
- The seed packs ship inside the APK, so a new board teaches before it ever goes online.

## Licences

The API issues a licence for each activated board: `{deviceId, collegeId, sectionIds, packs: ["*"], validUntil}`, signed with Ed25519.
- The board checks the licence offline. After `validUntil` it gives 30 days' grace with a warning banner.
- After the grace period, teaching continues from installed packs, but new packs are not installed.
- We never lock a classroom in the middle of the year.

## Sync protocol

`POST /v1/board/sync` with `{installed: {packId: version}, outbox: SessionLog[]}` returns:
- the newly accepted log ids,
- packs to download, as pre-signed S3 URLs,
- the timetable and Self-Learning schedule for the board's sections,
- a refreshed licence,
- config: the PIN hash and period lengths.

The sync is idempotent because logs carry UUIDs.
