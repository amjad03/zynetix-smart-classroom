# Content

- `syllabus/` contains 106 NCERT chapters (rationalised syllabus, which Karnataka PU follows) for 1st and 2nd PUC Physics, Chemistry, Maths and Biology. The JSON files are the source of truth; topics are edited in the CMS (or merged from new packs by `tools/content-src/merge_topics.py`).
- `packs/<id>/` holds the source for each pack:
  - `pack.json` (id, version)
  - `lessons/<topic>.json` (one lesson per topic)
  - `questions.json`
  - `media/` (PhET sims, CC BY 4.0: see `PHET-LICENSE.txt`)
- `pnpm packs` validates the packs and builds signed `.zpack` files into `content/dist/` and `apps/board/assets/packs/`.

Seeded:

| Pack | Topics | Questions | Reuses from Kinetix |
|---|---|---|---|
| 1st PUC Physics, Motion in a Straight Line | 5 | 19 | graph-plotter sim, inclined-plane lab, PhET projectile-motion |
| 2nd PUC Chemistry, Solutions | 5 | 20 | molecules and crystal-lattices 3D models, PhET molarity, osmosis animation, titration and osmosis labs |

## Before classroom use

- **Kannada:** titles, headings, narration and recaps have Kannada text. It needs a native-speaker review; Kinetix tracks its own review in `docs/i18n`. Examples and questions are in English only.
- **PYQ years:** none of the seeded questions has a PYQ year. They are written in the KCET/NEET/JEE pattern and tagged by exam. Verified paper years should be added in the CMS (`pyq: {exam, year, verified: true}`). We must not label a question as a past paper question until that is checked.
