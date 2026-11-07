// Step 2 of the Zynetix School import (PUC only): maps the extracted content (work/school.json,
// from extract.mjs) onto this repo's chapters and writes it into the content packs:
//   - questions.json   exam question bank (NEET, JEE Main, JEE Advanced, KCET, COMEDK), and the
//                      Computer Science / Electronics course quizzes, ids `zs-…`
//   - formulas.json    the chapter's formula sheet (lesson-schema FormulaSheet)
//   - lessons/*.json   an `explainer` block (misconception, watch, try, story, analogy) and a
//                      `concept_video` block (the owner's own videos; streamed, never downloaded)
//                      where they fit the topic, ids `zs-…`
//   - pack.json        version bumped when anything changed
// and the mock-test patterns into apps/board/assets/classroom/patterns.json.
// Imported items carry the `zs-` prefix, so a re-run replaces them and leaves the rest alone.
//   node import.mjs [--dry] [--only puc1-physics-gravitation,…]
import { createRequire } from 'node:module';
import { existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, '../..');
const content = join(repo, 'content');
const dry = process.argv.includes('--dry');
const onlyArg = process.argv.indexOf('--only');
const only = onlyArg > 0 ? new Set(process.argv[onlyArg + 1].split(',')) : null;
const require = createRequire(import.meta.url);
const schema = require(join(repo, 'packages/lesson-schema/dist/index.js'));
const dump = JSON.parse(readFileSync(join(here, 'work/school.json'), 'utf8'));
const PREFIX = 'zs-';

// ---------------------------------------------------------------- text

/** Zynetix School markdown → board text: `$…$` maths stays; bold, italics, code and links become plain text. */
export function plain(md) {
  if (typeof md !== 'string') return '';
  let s = md;
  s = s.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1');
  // Bold/italic markers outside maths.
  s = s.split('$').map((part, i) => (i % 2 ? part : part.replace(/\*\*([^*]+)\*\*/g, '$1').replace(/__([^_]+)__/g, '$1').replace(/(^|[\s(])\*([^*\s][^*]*?)\*(?=[\s).,;:!?]|$)/g, '$1$2').replace(/`([^`]+)`/g, '$1'))).join('$');
  s = s.replace(/\n{2,}/g, '\n').replace(/[ \t]+\n/g, '\n').trim();
  return s;
}
const en = (s) => ({ en: plain(s) });
const sentences = (s, n) => {
  const p = plain(s).replace(/\n/g, ' ');
  // A sentence ends at . ! or ? before a space and a capital (not inside 6.626 or e.g. maths).
  const parts = p.split(/(?<=[.!?])\s+(?=[A-Z"'(\u2018\u201C])/);
  return parts.slice(0, n).join(' ').trim();
};
const STOP = new Set('a an the of and or in on to for with by from at as is are be its it this that these those into their his her what which how why when where who whom than then there here not no all any each some more most less very can could will would should may might must do does did done using use used between over under about after before per via vs also only same other such both either neither one two three four five first second third part parts introduction basics basic concept concepts law laws type types'.split(' '));
const stem = (w) => w.replace(/(ies)$/, 'y').replace(/(sses)$/, 'ss').replace(/([^s])s$/, '$1');
const tokens = (s) => (plain(s).toLowerCase().replace(/\$[^$]*\$/g, ' ').match(/[a-z][a-z0-9'-]+/g) ?? []).map((w) => stem(w.replace(/'s$/, ''))).filter((w) => w.length > 2 && !STOP.has(w));
const norm = (s) => tokens(s).join(' ');
const jaccard = (a, b) => {
  const A = new Set(a), B = new Set(b);
  const i = [...A].filter((x) => B.has(x)).length;
  return i / (A.size + B.size - i || 1);
};
/** JSON as the content files write it (indent 1), keeping each number as written (10.0 stays 10.0). */
const json = (v) => JSON.stringify(v, null, 1) + '\n';
const rawParse = (text) => JSON.parse(text, (k, v, ctx) => (typeof v === 'number' && ctx?.source !== undefined && ctx.source !== String(v) ? JSON.rawJSON(ctx.source) : v));
const slug = (s) => s.toLowerCase().replace(/[^a-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '');

// ---------------------------------------------------------------- the repo's chapters and packs

const chapters = [];
for (const f of readdirSync(join(content, 'syllabus')).filter((f) => f.endsWith('.json') && f !== 'index.json')) chapters.push(...JSON.parse(readFileSync(join(content, 'syllabus', f), 'utf8')));
const packs = new Map(); // chapterId → {dir, meta}
for (const dir of readdirSync(join(content, 'packs'))) {
  const pj = join(content, 'packs', dir, 'pack.json');
  if (!existsSync(pj)) continue;
  const meta = JSON.parse(readFileSync(pj, 'utf8'));
  packs.set(meta.chapterId, { dir, meta });
}
const PUC_SUBJECTS = new Set(['physics', 'chemistry', 'maths', 'biology', 'computer_science', 'electronics']);
const puc = chapters.filter((c) => PUC_SUBJECTS.has(c.subject) && packs.has(c.id));
const topicsOf = (c) => {
  const pk = packs.get(c.id);
  const tf = join(content, 'packs', pk.dir, 'topics.json');
  return existsSync(tf) ? JSON.parse(readFileSync(tf, 'utf8')) : c.topics;
};

const SUBJECT = { physics: 'physics', chemistry: 'chemistry', maths: 'maths', biology: 'biology' };
const YEAR = { 11: 'puc1', 12: 'puc2' };

/** The repo chapter for a Zynetix School chapter title in a subject and year (best title match). */
function findChapter(subject, year, title) {
  const cands = puc.filter((c) => c.subject === subject && (!year || c.year === year));
  let best, score = 0;
  for (const c of cands) {
    const s = norm(c.title.en) === norm(title) ? 1 : jaccard(tokens(c.title.en), tokens(title));
    if (s > score) { best = c; score = s; }
  }
  return score >= 0.6 ? best : undefined;
}

/** The broad chapters of the older practice bank (no class given) → this repo's chapter. */
const BROAD = {
  'physics|Units & Measurement': 'puc1-physics-01', 'physics|Kinematics': 'puc1-physics-02', 'physics|Laws of Motion': 'puc1-physics-04',
  'physics|Work, Energy & Power': 'puc1-physics-05', 'physics|Gravitation': 'puc1-physics-07', 'physics|Thermodynamics': 'puc1-physics-11',
  'physics|Oscillations & Waves': 'puc1-physics-13', 'physics|Electrostatics': 'puc2-physics-01', 'physics|Current Electricity': 'puc2-physics-03',
  'physics|Magnetism': 'puc2-physics-04', 'physics|Optics': 'puc2-physics-09', 'physics|Modern Physics': 'puc2-physics-11',
  'chemistry|Mole Concept': 'puc1-chemistry-01', 'chemistry|Atomic Structure': 'puc1-chemistry-02', 'chemistry|Periodic Table': 'puc1-chemistry-03',
  'chemistry|Chemical Bonding': 'puc1-chemistry-04', 'chemistry|Thermochemistry': 'puc1-chemistry-05', 'chemistry|Equilibrium': 'puc1-chemistry-06',
  'chemistry|Organic Basics': 'puc1-chemistry-08', 'chemistry|Hydrocarbons': 'puc1-chemistry-09', 'chemistry|Electrochemistry': 'puc2-chemistry-02',
  'chemistry|Chemical Kinetics': 'puc2-chemistry-03', 'chemistry|Coordination Compounds': 'puc2-chemistry-05',
  'maths|Sets & Functions': 'puc1-maths-02', 'maths|Trigonometry': 'puc1-maths-03', 'maths|Quadratic Equations': 'puc1-maths-04',
  'maths|Sequences & Series': 'puc1-maths-08', 'maths|Coordinate Geometry': 'puc1-maths-09', 'maths|Limits & Continuity': 'puc1-maths-12',
  'maths|Probability': 'puc2-maths-13', 'maths|Matrices & Determinants': 'puc2-maths-03', 'maths|Differentiation': 'puc2-maths-05',
  'maths|Integration': 'puc2-maths-07', 'maths|Vectors & 3D': 'puc2-maths-10',
  'biology|Cell Biology': 'puc1-biology-08', 'biology|Biomolecules': 'puc1-biology-09', 'biology|Plant Physiology': 'puc1-biology-11',
  'biology|Human Physiology': 'puc1-biology-15', 'biology|Reproduction': 'puc2-biology-02', 'biology|Genetics': 'puc2-biology-04',
  'biology|Molecular Biology': 'puc2-biology-05', 'biology|Evolution': 'puc2-biology-06', 'biology|Biotechnology': 'puc2-biology-09',
  'biology|Ecology': 'puc2-biology-12',
};
const byPrefix = (p) => puc.find((c) => c.id.startsWith(p + '-'));
function chapterFor(subject, grade, title) {
  const s = SUBJECT[subject];
  if (!s) return undefined;
  if (grade) return findChapter(s, YEAR[grade], title);
  const p = BROAD[`${subject}|${title}`];
  return p ? byPrefix(p) : undefined;
}

// ---------------------------------------------------------------- topic matching

/** Words of a topic: its title (twice) and what its lesson says (concept titles and bodies). */
const topicWords = new Map();
function lessonFiles(c) {
  const dir = join(content, 'packs', packs.get(c.id).dir, 'lessons');
  return readdirSync(dir).filter((f) => f.endsWith('.json')).sort().map((f) => ({ file: join(dir, f), lesson: rawParse(readFileSync(join(dir, f), 'utf8')) }));
}
function wordsOfTopic(c, t) {
  const k = t.id;
  if (topicWords.has(k)) return topicWords.get(k);
  const l = lessonFiles(c).find((x) => x.lesson.topicId === t.id)?.lesson;
  const extra = (l?.blocks ?? []).filter((b) => b.type === 'concept' || b.type === 'intro').map((b) => `${b.title?.en ?? ''} ${b.heading?.en ?? ''} ${b.body?.en ?? ''}`).join(' ');
  const w = [...tokens(t.title.en), ...tokens(t.title.en), ...tokens(extra)];
  topicWords.set(k, w);
  return w;
}
/** The topic whose words best overlap the text (IDF-weighted over the chapter), or undefined. */
function bestTopic(c, text, { min = 1.2 } = {}) {
  const topics = topicsOf(c);
  const docs = topics.map((t) => new Set(wordsOfTopic(c, t)));
  const want = new Set(tokens(text));
  let best, score = 0;
  topics.forEach((t, i) => {
    let s = 0;
    for (const w of want) if (docs[i].has(w)) s += Math.log((topics.length + 1) / (docs.filter((d) => d.has(w)).length));
    if (s > score) { best = t; score = s; }
  });
  return score >= min ? best : undefined;
}

// ---------------------------------------------------------------- questions

const EXAMS = new Set(['NEET', 'JEE', 'JEE_ADV', 'KCET', 'COMEDK']);
const DIFF = { 1: 'easy', 2: 'medium', 3: 'hard' };
const stats = { questions: 0, skipped: 0, formulas: 0, explainers: 0, curated: 0, videos: 0 };

function convertExam(q, c) {
  const exams = (q.exams ?? []).filter((e) => EXAMS.has(e));
  if (!exams.length) return undefined;
  let difficulty = DIFF[q.difficulty ?? 2] ?? 'medium';
  if (exams.includes('JEE_ADV') && difficulty === 'easy') difficulty = 'medium';
  const base = { id: PREFIX + slug(q.id), chapterId: c.id, stem: en(q.q), exams, difficulty, tags: ['zynetix-school'] };
  if (q.explain) base.explanation = en(q.explain);
  if (q.kind === 'numeric') {
    if (q.unit) base.stem = { en: `${base.stem.en} (in ${q.unit})` };
    return { ...base, options: [], answer: 0, numericAnswer: q.answer, ...(q.tolerance !== undefined ? { tolerance: q.tolerance } : {}), format: 'numeric' };
  }
  if (!Array.isArray(q.options) || q.options.length !== 4) return undefined;
  const options = q.options.map(en);
  if (new Set(options.map((o) => o.en.trim())).size !== 4 || options.some((o) => !o.en)) return undefined;
  if (q.kind === 'multi') {
    const answers = [...new Set(q.answers)].sort();
    if (!answers.length || answers.some((a) => a > 3)) return undefined;
    return { ...base, options, answer: answers[0], answers, format: 'multi_correct' };
  }
  return { ...base, options, answer: q.answer, format: 'mcq' };
}

/** A course quiz question (Computer Science, Electronics): 4-option MCQs and true/false. */
function convertQuiz(q, id, c) {
  const base = { id, chapterId: c.id, stem: en(q.q), exams: ['PUC'], difficulty: DIFF[q.difficulty ?? 1] ?? 'easy', tags: ['zynetix-school', 'course'] };
  if (c.boards.includes('cbse')) base.exams.push('CBSE');
  if (q.explain) base.explanation = en(q.explain);
  if (q.kind === 'mcq' && q.options?.length === 4) {
    const options = q.options.map(en);
    if (new Set(options.map((o) => o.en.trim())).size !== 4 || options.some((o) => !o.en)) return undefined;
    return { ...base, options, answer: q.answer, format: 'mcq' };
  }
  if (q.kind === 'truefalse') return { ...base, options: [{ en: 'True', kn: 'ಸರಿ' }, { en: 'False', kn: 'ತಪ್ಪು' }], answer: q.answer ? 0 : 1, format: 'either_or' };
  return undefined;
}

// ---------------------------------------------------------------- Zynetix School course lessons → chapters

const FAMILY = { physics: 'phy', chemistry: 'che', maths: 'mat', biology: 'bio', computer_science: 'cmp', electronics: 'ele' };
const lessonById = new Map(dump.lessons.map((l) => [l.id, l]));
const COURSE = { physics: 'physics-senior', chemistry: 'chemistry-senior', maths: 'maths-senior', biology: 'biology-senior', computer_science: 'computer-science', electronics: 'electronics' };
/** Course lessons written for a repo chapter (the course's chapter links, then the closest title). */
function courseLessons(c) {
  const fam = FAMILY[c.subject], grade = c.year === 'puc1' ? '11' : '12';
  const keys = Object.keys(dump.chapterLessons).filter((k) => k.startsWith(fam + '|'));
  const title = (k) => k.slice(fam.length + 1).replace(/^\d+:/, '');
  let best, score = 0;
  for (const k of keys) {
    const g = /^\w+\|(\d+):/.exec(k)?.[1];
    if (g && g !== grade) continue;
    const s = norm(title(k)) === norm(c.title.en) ? 1 : jaccard(tokens(title(k)), tokens(c.title.en));
    if (s > score) { best = k; score = s; }
  }
  const linked = best && score >= 0.5 ? dump.chapterLessons[best].map((id) => lessonById.get(id)).filter((l) => l && l.course === COURSE[c.subject]) : [];
  if (linked.length) return linked;
  // No link: the course topic (chapter) whose title is closest, or contained in the chapter's.
  const ct = new Set(tokens(c.title.en));
  const byTopic = new Map();
  for (const l of dump.lessons) if (l.course === COURSE[c.subject] && (l.topic.startsWith(`c${grade}-`) || !/^c1[12]-/.test(l.topic))) (byTopic.get(l.topic) ?? byTopic.set(l.topic, []).get(l.topic)).push(l);
  let pick, ps = 0;
  for (const [, ls] of byTopic) {
    const tt = tokens(ls[0].topicTitle);
    const s = tt.length && tt.every((w) => ct.has(w)) ? Math.max(0.6, jaccard(tt, [...ct])) : jaccard(tt, [...ct]);
    if (s > ps) { pick = ls; ps = s; }
  }
  return ps >= 0.5 ? pick : [];
}

/** Pairs each topic with its closest course lesson (each lesson at most once). */
function assignLessons(c, lessons) {
  const topics = topicsOf(c);
  const cand = [];
  for (const t of topics)
    for (const l of lessons) {
      if (l.track === 'exam') continue;
      const words = [l.title, l.summary, ...l.blocks.filter((b) => b.type === 'heading').map((b) => b.text)].join(' ');
      const A = new Set(wordsOfTopic(c, t)), B = new Set(tokens(words));
      const s = jaccard(tokens(t.title.en), tokens(l.title)) * 2 + [...A].filter((w) => B.has(w)).length / Math.sqrt(A.size * B.size || 1);
      cand.push({ t, l, s });
    }
  cand.sort((a, b) => b.s - a.s);
  const out = new Map(), used = new Set();
  for (const { t, l, s } of cand) if (s >= 0.3 && !out.has(t.id) && !used.has(l.id)) { out.set(t.id, l); used.add(l.id); }
  return out;
}

/** An explainer from a course lesson: its common mistake, its sections to watch, its activities to try. */
function explainerFromLesson(l) {
  const mistake = l.blocks.find((b) => b.type === 'mistake');
  const watch = [];
  for (let i = 0; i < l.blocks.length && watch.length < 6; i++) {
    const b = l.blocks[i];
    if (b.type !== 'heading') continue;
    // What the section says: its first paragraph, or its first list items.
    let say = '';
    for (const x of l.blocks.slice(i + 1)) {
      if (x.type === 'heading') break;
      if (x.type === 'text') { say = sentences(x.md, 2); break; }
      if (x.type === 'list' && x.items?.length) { say = x.items.slice(0, 2).map((t) => sentences(t, 1)).join(' '); break; }
    }
    if (say.length > 12 && say.length < 420) watch.push({ title: en(b.text), say: { en: say } });
  }
  const keypoints = l.blocks.find((b) => b.type === 'keypoints')?.items ?? [];
  if (watch.length < 2 && keypoints.length >= 2) {
    watch.length = 0;
    keypoints.slice(0, 6).forEach((k, i) => watch.push({ title: { en: `Key idea ${i + 1}`, kn: `ಮುಖ್ಯ ಅಂಶ ${i + 1}` }, say: { en: sentences(k, 2) } }));
  }
  const steps = [];
  for (const b of l.blocks) {
    if (steps.length >= 4) break;
    if (b.type === 'activity') {
      const a = b.activity;
      if (a.kind === 'reveal' && a.options?.length >= 2 && a.options.length <= 4 && a.answer < a.options.length) {
        const opts = a.options.map(en);
        if (new Set(opts.map((o) => o.en)).size !== opts.length) continue;
        steps.push({ task: en(a.prompt), predict: { question: en(a.prompt), options: opts, answer: a.answer, ...(a.trap !== undefined && a.trap < opts.length ? { trap: a.trap } : {}) }, explain: en(a.explain) });
      } else if (a.prompt && a.explain) steps.push({ task: en(a.prompt), explain: en(a.explain) });
    }
    if (b.type === 'checkpoint')
      for (const q of b.questions ?? []) {
        if (steps.length >= 4 || q.kind !== 'mcq' || !(q.options?.length >= 2 && q.options.length <= 4) || !q.explain) continue;
        const opts = q.options.map(en);
        if (new Set(opts.map((o) => o.en)).size !== opts.length || q.answer >= opts.length) continue;
        steps.push({ task: { en: 'Predict first, then check.', kn: 'ಮೊದಲು ಊಹಿಸಿ, ನಂತರ ಪರಿಶೀಲಿಸಿ.' }, predict: { question: en(q.q), options: opts, answer: q.answer }, explain: en(q.explain) });
      }
  }
  const like = l.blocks.find((b) => b.type === 'callout' && /\b(like|think of|imagine|analogy)\b/i.test(b.md ?? ''));
  const block = { id: PREFIX + 'explainer', type: 'explainer', heading: en(l.title), optional: true, source: `zynetix-school:${l.id}` };
  if (l.summary) block.tagline = en(l.summary);
  if (mistake) block.misconception = { myth: en(mistake.wrong), truth: { en: `${plain(mistake.right)}${mistake.why ? ' ' + sentences(mistake.why, 2) : ''}`.trim() } };
  if (watch.length >= 2) { block.watch = watch; block.reveal = true; }
  if (steps.length) block.try = { goal: en(l.summary || l.title), steps, takeaway: keypoints[0] ? en(keypoints[0]) : en(l.title) };
  if (like) block.analogy = { headline: { en: sentences(like.md, 2) }, pairs: [] };
  if (!block.misconception && !block.watch && !block.try) return undefined;
  block.narration = block.misconception ? { en: `Many people think: ${block.misconception.myth.en} Actually: ${block.misconception.truth.en}` } : { en: block.heading.en };
  return block;
}

/** A Zynetix School visual explainer (the stand-alone ones) as a block. */
function explainerFromCurated(e) {
  const b = { id: PREFIX + 'explainer-' + slug(e.id), type: 'explainer', heading: en(e.title), tagline: en(e.tagline), optional: true, source: `zynetix-school:explainer/${e.id}` };
  if (e.misconception) b.misconception = { myth: en(e.misconception.myth), truth: en(e.misconception.truth) };
  if (e.watch?.length) { b.watch = e.watch.slice(0, 12).map((s) => ({ title: en(s.title), say: en(s.say) })); b.reveal = true; }
  if (e.mission) {
    const steps = e.mission.steps.slice(0, 8).map((s) => {
      const st = { task: en(s.task), explain: en(s.explain) };
      if (s.hint) st.hint = en(s.hint);
      if (s.predict && s.predict.options.length >= 2 && s.predict.options.length <= 4) st.predict = { question: en(s.predict.question), options: s.predict.options.map(en), answer: s.predict.answer, ...(s.predict.trap !== undefined ? { trap: s.predict.trap } : {}) };
      return st;
    });
    b.try = { goal: en(e.mission.goal), steps, takeaway: en(e.mission.takeaway) };
  }
  const story = (e.story ?? []).filter((p) => p.caption).slice(0, 8).map((p) => ({ caption: en(p.caption), ...(p.speech ? { speech: en(p.speech) } : {}) }));
  if (story.length) b.story = story;
  if (e.like) b.analogy = { headline: en(e.like.headline), ...(e.like.everyday ? { everyday: en(e.like.everyday) } : {}), ...(e.like.concept ? { concept: en(e.like.concept) } : {}), pairs: (e.like.pairs ?? []).slice(0, 8).map(([a, c]) => [en(a), en(c)]), ...(e.like.limits ? { limits: en(e.like.limits) } : {}) };
  b.narration = b.misconception ? { en: `Many people think: ${b.misconception.myth.en} Actually: ${b.misconception.truth.en}` } : { en: b.heading.en };
  return b;
}

/** The stand-alone explainers pitched at PUC students, and the topic each fits. */
const CURATED = {
  'gravity-falling': ['puc1-physics-02', /free fall/i],
  'electric-circuits': ['puc2-physics-03', /current/i],
  'atoms-reactions': ['puc1-chemistry-01', /laws of chemical combination/i],
  'coding-variables': ['puc1-computer-science-05', /variables/i],
  'coding-if-else': ['puc1-computer-science-06', /selection/i],
  'coding-loops': ['puc1-computer-science-06', /for loop/i],
  'coding-binary': ['puc1-computer-science-02', /^number systems/i],
  'coding-bubble-sort': ['puc2-computer-science-05', /bubble/i],
  'coding-big-o-search': ['puc2-computer-science-06', /binary search/i],
  'coding-internet-packets': ['puc2-computer-science-10', /internet/i],
};

// ---------------------------------------------------------------- videos

/** The owner's videos for a course lesson: YouTube (channel matches) or Drive episodes. */
function videoBlock(courseLessonId) {
  const v = dump.videos[courseLessonId];
  if (!v) return undefined;
  const list = v.video?.provider === 'youtube' ? [{ id: v.video.id, title: v.video.title }] : v.drive ?? [];
  const provider = v.video?.provider === 'youtube' ? 'youtube' : 'drive';
  if (!list.length) return undefined;
  const ref = (e) => ({ provider, id: e.id, title: { en: e.title }, ...(provider === 'youtube' && v.video?.duration ? { seconds: Math.round(v.video.duration) } : {}) });
  const b = { id: PREFIX + 'video', type: 'concept_video', video: ref(list[0]), optional: true, caption: { en: 'A concept video from Zynetix School. It plays when the board is online.', kn: 'ಜೈನೆಟಿಕ್ಸ್ ಸ್ಕೂಲ್‌ನ ಪರಿಕಲ್ಪನಾ ವೀಡಿಯೊ. ಬೋರ್ಡ್ ಆನ್‌ಲೈನ್‌ನಲ್ಲಿದ್ದಾಗ ಪ್ಲೇ ಆಗುತ್ತದೆ.' } };
  if (list.length > 1) b.playlist = list.slice(1, 31).map(ref);
  b.narration = { en: `Concept video: ${list[0].title}` };
  return b;
}

// ---------------------------------------------------------------- per chapter

const examByChapter = new Map();
for (const q of dump.questions) {
  const c = chapterFor(q.subject, q.grade, q.chapter);
  if (!c) { stats.skipped++; continue; }
  (examByChapter.get(c.id) ?? examByChapter.set(c.id, []).get(c.id)).push(q);
}
const formulasByChapter = new Map();
for (const f of dump.formulas) {
  const grade = /^(11|12)$/.test(String(f.grade ?? '')) ? f.grade : undefined;
  const c = chapterFor(f.subject, grade, f.chapter) ?? (['11', '12'].map((g) => chapterFor(f.subject, g, f.chapter)).find(Boolean));
  if (!c) continue;
  (formulasByChapter.get(c.id) ?? formulasByChapter.set(c.id, []).get(c.id)).push(...f.items);
}

const bump = (v, minor) => {
  const [a, b, c] = v.split('.').map(Number);
  return minor ? `${a}.${b + 1}.0` : `${a}.${b}.${c + 1}`;
};
const report = { lessonsWithVideo: 0, lessonsWithExplainer: 0, lessonsWithQuestions: 0, lessonsWithFormulas: 0, pucLessons: 0, packsChanged: 0, chapters: {} };

for (const c of puc) {
  const pk = packs.get(c.id);
  if (only && !only.has(pk.dir)) continue;
  const root = join(content, 'packs', pk.dir);
  const topics = topicsOf(c);
  const qFile = join(root, 'questions.json');
  const questionsBefore = readFileSync(qFile, 'utf8');
  const own = rawParse(questionsBefore).filter((q) => !q.id.startsWith(PREFIX));
  const seen = new Set(own.map((q) => norm(q.stem.en)));
  const added = [];
  const push = (q) => {
    if (!q) return;
    const r = schema.Question.safeParse(q);
    if (!r.success) return;
    const k = norm(q.stem.en);
    if (!k || seen.has(k) || added.some((x) => x.id === q.id)) return;
    seen.add(k);
    const t = bestTopic(c, `${q.stem.en} ${q.explanation?.en ?? ''}`);
    if (t) q.topicId = t.id;
    if (q.exams.includes('CBSE') && t?.boards && !t.boards.includes('cbse')) q.exams = q.exams.filter((e) => e !== 'CBSE');
    added.push(q);
  };
  for (const q of examByChapter.get(c.id) ?? []) push(convertExam(q, c));
  // Course lessons: quizzes (Computer Science, Electronics) and explainers/videos for every subject.
  const lessons = courseLessons(c);
  if (c.subject === 'computer_science' || c.subject === 'electronics')
    for (const l of lessons) (l.quiz ?? []).forEach((q, i) => push(convertQuiz(q, `${PREFIX}${slug(l.id.split('/').slice(1).join('-'))}-${i + 1}`, c)));
  const questions = [...own, ...added];

  // Formulas.
  const items = formulasByChapter.get(c.id) ?? [];
  const fseen = new Set();
  const formulas = [];
  for (const it of items) {
    if (!it.tex || fseen.has(it.tex)) continue;
    fseen.add(it.tex);
    const f = { id: `${PREFIX}f${formulas.length + 1}`, name: en(it.name), tex: it.tex };
    if (it.note) f.note = en(it.note);
    const t = bestTopic(c, `${it.name} ${it.note ?? ''}`);
    if (t) f.topicId = t.id;
    formulas.push(f);
  }
  const fFile = join(root, 'formulas.json');
  const formulasBefore = existsSync(fFile) ? readFileSync(fFile, 'utf8') : '';
  const formulasAfter = formulas.length ? json(schema.FormulaSheet.parse({ chapterId: c.id, formulas })) : '';

  // Lessons: explainer + concept video per topic.
  const byTopic = assignLessons(c, lessons);
  const files = lessonFiles(c);
  const lessonWrites = [];
  let video = 0, expl = 0, withQ = 0, withF = 0;
  for (const { file, lesson } of files) {
    report.pucLessons++;
    const before = readFileSync(file, 'utf8');
    const blocks = lesson.blocks.filter((b) => !b.id.startsWith(PREFIX));
    const cl = byTopic.get(lesson.topicId);
    const curated = Object.entries(CURATED).find(([, [p, re]]) => c.id.startsWith(p + '-') && re.test(topics.find((t) => t.id === lesson.topicId)?.title.en ?? ''));
    const ex = curated ? explainerFromCurated(dump.explainers.find((e) => e.id === curated[0])) : cl ? explainerFromLesson(cl) : undefined;
    const vid = cl ? videoBlock(cl.id) : undefined;
    if (vid) {
      const at = blocks.findIndex((b) => b.type === 'intro');
      blocks.splice(at + 1, 0, vid);
      video++;
    }
    if (ex) {
      const at = blocks.findIndex((b) => ['example', 'trick', 'class_quiz', 'pyq', 'recap'].includes(b.type));
      blocks.splice(at < 0 ? blocks.length : at, 0, ex);
      expl++;
      if (curated) stats.curated++;
    }
    const next = { ...lesson, blocks };
    const after = json(next);
    const parsed = schema.Lesson.safeParse(JSON.parse(after));
    if (!parsed.success) throw new Error(`${lesson.id}: ${parsed.error.issues.map((i) => `${i.path.join('.')} ${i.message}`).join('; ')}`);
    if (after !== before) lessonWrites.push([file, after]);
    if (questions.some((q) => q.topicId === lesson.topicId && q.id.startsWith(PREFIX))) withQ++;
    if (formulas.some((f) => f.topicId === lesson.topicId)) withF++;
  }
  report.lessonsWithVideo += video;
  report.lessonsWithExplainer += expl;
  report.lessonsWithQuestions += withQ;
  report.lessonsWithFormulas += withF;
  stats.questions += added.length;
  stats.formulas += formulas.length;
  stats.videos += video;
  stats.explainers += expl;

  const questionsAfter = json(questions);
  const changed = lessonWrites.length > 0 || questionsAfter !== questionsBefore || formulasAfter !== formulasBefore;
  report.chapters[c.id] = { questions: added.length, formulas: formulas.length, explainers: expl, videos: video, lessons: files.length };
  if (!changed) continue;
  report.packsChanged++;
  if (dry) continue;
  for (const [f, s] of lessonWrites) writeFileSync(f, s);
  writeFileSync(qFile, questionsAfter);
  if (formulasAfter) writeFileSync(fFile, formulasAfter);
  // First import: a minor version; later changes: a patch.
  const firstImport = !questionsBefore.includes(`"id": "${PREFIX}`) && !formulasBefore;
  pk.meta.version = bump(pk.meta.version, firstImport);
  writeFileSync(join(root, 'pack.json'), json(pk.meta));
}

// ---------------------------------------------------------------- mock-test patterns

const KN = {
  KCET: 'ಕೆಸಿಇಟಿ', NEET: 'ನೀಟ್', 'JEE Main': 'ಜೆಇಇ ಮೇನ್', 'JEE Advanced': 'ಜೆಇಇ ಅಡ್ವಾನ್ಸ್ಡ್', COMEDK: 'ಕಾಮೆಡ್‌ಕೆ',
  physics: 'ಭೌತಶಾಸ್ತ್ರ', chemistry: 'ರಸಾಯನಶಾಸ್ತ್ರ', maths: 'ಗಣಿತ', biology: 'ಜೀವಶಾಸ್ತ್ರ',
};
const EXAM_NAME = { KCET: 'KCET', NEET: 'NEET', JEE: 'JEE Main', JEE_ADV: 'JEE Advanced', COMEDK: 'COMEDK' };
const PICK = ['kcet-pcm', 'kcet-pcb', 'neet-ug-full', 'jee-main-full', 'jee-adv-paper', 'comedk-full', 'neet-mini', 'jee-mini'];
const mocks = [];
for (const id of PICK) {
  const m = dump.mocks.find((x) => x.id === id);
  if (!m) continue;
  const bySubject = new Map();
  for (const s of m.sections) {
    const x = bySubject.get(s.subject) ?? { subject: s.subject, count: 0, plus: s.marking.correct, minus: Math.abs(s.marking.wrong) };
    x.count += s.count;
    bySubject.set(s.subject, x);
  }
  const sections = [...bySubject.values()];
  const exam = EXAM_NAME[m.exam] ?? m.exam;
  const total = sections.reduce((a, s) => a + s.count, 0), marks = sections.reduce((a, s) => a + s.count * s.plus, 0);
  const per = m.timing?.mode === 'sectional' ? m.timing.minutesPerSubject : undefined;
  const subjKn = sections.map((s) => `${KN[s.subject]} ${s.count}`).join(', ');
  const markingKn = sections[0].minus ? `+${sections[0].plus} / −${sections[0].minus}` : `ಪ್ರತಿ ಸರಿ ಉತ್ತರಕ್ಕೆ +${sections[0].plus}, ಋಣಾತ್ಮಕ ಅಂಕ ಇಲ್ಲ`;
  const titleKn = m.kind === 'full' ? `${KN[exam] ?? exam} · ${id.startsWith('kcet-pcm') ? 'ಪಿಸಿಎಂ' : id.startsWith('kcet-pcb') ? 'ಪಿಸಿಬಿ' : 'ಪೂರ್ಣ ಪತ್ರಿಕೆ'}` : `${KN[exam] ?? exam} · ಕಿರು ಪರೀಕ್ಷೆ`;
  mocks.push(schema.MockPattern.parse({
    id, exam, title: { en: m.title.en, kn: titleKn },
    blurb: { en: m.blurb.en, kn: `${total} ಪ್ರಶ್ನೆಗಳು, ${per ? `ಪ್ರತಿ ವಿಷಯಕ್ಕೆ ${per} ನಿಮಿಷ` : `${m.minutes} ನಿಮಿಷ`}: ${subjKn}. ${marks} ಅಂಕ, ${markingKn}.` },
    minutes: m.minutes, ...(per ? { minutesPerSection: per } : {}), sections,
  }));
}
const patternsFile = join(repo, 'apps/board/assets/classroom/patterns.json');
if (!dry && !only) writeFileSync(patternsFile, json({ source: 'Zynetix School lib/exam.ts (tools/school-import); patterns follow recent papers', mocks }));

console.log(JSON.stringify({ ...stats, mocks: mocks.length, ...report, chapters: undefined }, null, 1));
if (process.argv.includes('--chapters')) console.log(JSON.stringify(report.chapters, null, 1));
