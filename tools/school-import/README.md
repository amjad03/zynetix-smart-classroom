# Zynetix School import (PUC)

Brings the Zynetix School content (the `quest-academy` repo) into this repo's content packs, for
PUC chapters only (Karnataka PU, CBSE 11–12, ISC, and NEET / JEE Main / JEE Advanced / KCET / COMEDK).

```
node extract.mjs [--src /home/user/quest-academy]   # → work/school.json (data only)
node import.mjs  [--dry] [--only <packDir,…>] [--chapters]
cd ../pack-builder && npx tsc -p tsconfig.json && node dist/validate.js
```

**extract.mjs** bundles the TypeScript content modules with esbuild (React, framer-motion and the
app shell stubbed, so only data is read): the exam question bank (`src/content/exam/…`), formula
sheets, mock-test patterns (`src/lib/exam.ts`), the visual explainers (`src/explainers`, text only),
the Class 11–12 course lessons incl. PUC Computer Science and Electronics, and the concept-video
mapping (`src/content/videos`).

**import.mjs** maps them onto `content/syllabus` chapters and writes into `content/packs/<pack>/`:

| What | Where | Schema |
| --- | --- | --- |
| Exam questions (mcq, numeric, multi-correct) and CS / Electronics course quizzes | `questions.json`, ids `zs-…`, topic by best word match | `Question` |
| Formula sheet | `formulas.json` | `FormulaSheet` |
| Explainer (misconception, watch steps, try, story, analogy) | a `zs-explainer…` block before the lesson's examples | `ExplainerBlock` |
| Concept video (the owner's own videos; YouTube or Drive) | a `zs-video` block after the intro | `ConceptVideoBlock` |
| Mock-test patterns | `apps/board/assets/classroom/patterns.json` | `MockPattern` |

Imported items carry the `zs-` prefix: a re-run replaces exactly those and leaves the rest. A pack
whose files change gets a new version (minor on the first import, patch after). Videos are never
downloaded: the board streams them when online and shows "Needs internet" offline. Imported text
is English; Kannada falls back to English until translated (block chrome is bilingual).
