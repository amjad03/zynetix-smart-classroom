# Content

- `syllabus/` contains 106 NCERT chapters (rationalised syllabus, which Karnataka PU follows) for 1st and 2nd PUC Physics, Chemistry, Maths and Biology. The JSON files are the source of truth; topics are edited in the CMS (or merged from new packs by `tools/content-src/merge_topics.py`).
- `packs/<id>/` holds the source for each pack:
  - `pack.json` (id, version)
  - `lessons/<topic>.json` (one lesson per topic)
  - `questions.json`
  - `media/` (PhET sims, CC BY 4.0: see `PHET-LICENSE.txt`)
- `pnpm packs` validates the packs and builds signed `.zpack` files into `content/dist/` and `apps/board/assets/packs/`.

All 106 chapters have packs: 539 topics, 539 lessons and 2,625 exam-pattern questions.

**ISC (CISCE) Science:** the 106 Physics, Chemistry, Maths and Biology chapters are also tagged for the `isc` board, and 17 ISC-only chapters (topics not in the rationalised NCERT books, such as Doppler effect, potentiometer, radioactivity, logic gates, transport in plants, digestion, mathematical reasoning, index numbers and linear regression) have English-only packs with ISC-pattern questions. See the "ISC Science" section of REVIEW.md.

- Every topic has a lesson with an intro, concepts, a worked example, a class quiz and a recap, plus pyq, trick, 3D, simulation and lab blocks where they fit.
- The packs reuse 3D models, labs, animations and sims from Zynetix Board (Kinetix), plus 13 offline PhET sims.
- `content/REVIEW.md` lists, chapter by chapter, the facts, syllabus-scope assumptions and Kannada terms a subject teacher should check.

## Before classroom use

- **Kannada:** titles, headings, narration and recaps have Kannada text, which needs a Kannada-medium teacher's review (see REVIEW.md). Examples and questions are in English only.
- **PYQ years:** none of the seeded questions has a PYQ year. They are written in the KCET/NEET/JEE pattern and tagged by exam. Verified paper years should be added in the CMS (`pyq: {exam, year, verified: true}`). We must not label a question as a past paper question until that is checked.
