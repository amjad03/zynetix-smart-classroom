/**
 * Zynetix Smart Classroom — the lesson and content-pack schema.
 *
 * This file is the single source of truth. The board (Dart, apps/board/lib/engine/model.dart),
 * the API, the CMS and the pack builder all follow it. `pnpm build` also writes
 * schema/*.schema.json for anything else that wants to validate packs.
 *
 * Rules that the schema enforces on purpose:
 * - No student personal data anywhere: classes are sections with a roll count, and logs carry
 *   roll numbers only.
 * - Every learner-facing string is bilingual (English required, Kannada optional until reviewed).
 */
import { z } from 'zod';

export const SCHEMA_VERSION = 1;

/** Text in English and (optionally) Kannada. `en` is required; the board falls back to it. */
export const L10n = z.object({ en: z.string().min(1), kn: z.string().optional() }).strict();
export type L10n = z.infer<typeof L10n>;

export const Subject = z.enum([
  // Science
  'physics', 'chemistry', 'maths', 'biology', 'computer_science', 'electronics', 'statistics',
  // Commerce
  'accountancy', 'business_studies', 'economics',
  // Language
  'english',
]);
export type Subject = z.infer<typeof Subject>;

/** 1st PUC (NCERT Class 11) and 2nd PUC (NCERT Class 12). */
export const Year = z.enum(['puc1', 'puc2']);
export type Year = z.infer<typeof Year>;

/** Board exams (PUC = Karnataka II PUC, CBSE = CBSE Class 12) and entrance exams. */
export const Exam = z.enum(['PUC', 'CBSE', 'KCET', 'COMEDK', 'NEET', 'JEE', 'CUET']);

/** The curriculum a college follows. Both use NCERT books for most subjects; scope and exam pattern differ. */
export const Board = z.enum(['kar_pu', 'cbse']);
export type Board = z.infer<typeof Board>;
const boards = z.array(Board).min(1).optional();
export type Exam = z.infer<typeof Exam>;

export const Difficulty = z.enum(['easy', 'medium', 'hard']);
export type Difficulty = z.infer<typeof Difficulty>;

const id = z.string().regex(/^[a-z0-9][a-z0-9._-]*$/, 'lower-case id: a-z 0-9 . _ -');

// ---------------------------------------------------------------- questions

/** A previous-year question reference. `verified` stays false until checked against the paper. */
export const PyqRef = z.object({ exam: Exam, year: z.number().int().min(1990).max(2100), verified: z.boolean() }).strict();

export const Question = z
  .object({
    id,
    chapterId: id,
    topicId: id.optional(),
    stem: L10n,
    /** Exactly four options, labelled A–D on the board. */
    options: z.array(L10n).length(4),
    /** Index into options (0 = A). */
    answer: z.number().int().min(0).max(3),
    explanation: L10n.optional(),
    exams: z.array(Exam).min(1),
    difficulty: Difficulty,
    pyq: PyqRef.optional(),
    /** mcq (default); assertion_reason (options are the 4 standard A–R choices); case_based (needs `passage`). */
    format: z.enum(['mcq', 'assertion_reason', 'case_based']).default('mcq'),
    /** The case or source text a case_based question is about, shown above the stem. */
    passage: L10n.optional(),
    tags: z.array(z.string()).default([]),
  })
  .strict()
  .refine((q) => q.format !== 'case_based' || !!q.passage, { message: 'case_based questions need a passage' });
export type Question = z.infer<typeof Question>;

// ---------------------------------------------------------------- blocks

/**
 * Every block can be narrated. `narration` is what the board reads aloud (device TTS, en-IN or
 * kn-IN) in Self-Learning mode and on demand in Teacher Mode; `seconds` is how long the block is
 * shown in Self-Learning when narration alone doesn't decide it (sims, labs, 3D).
 */
const base = {
  id,
  title: L10n.optional(),
  narration: L10n.optional(),
  seconds: z.number().int().min(5).max(1800).optional(),
  /** Self-Learning skips optional blocks first when the period is short. */
  optional: z.boolean().optional(),
  /** Shown only on boards following these curricula (e.g. a CBSE-pattern block); all when absent. */
  boards,
};

export const IntroBlock = z.object({ ...base, type: z.literal('intro'), heading: L10n, hook: L10n, objectives: z.array(L10n).default([]) }).strict();

/** `body` is short paragraphs; `$…$` marks inline LaTeX. `formula` is a display LaTeX line. */
export const ConceptBlock = z
  .object({ ...base, type: z.literal('concept'), body: L10n, points: z.array(L10n).default([]), formula: z.string().optional() })
  .strict();

/** A Kinetix 3D teaching model (packages/kinetix_3d: heart, molecules, atoms…). */
export const Model3dBlock = z
  .object({ ...base, type: z.literal('3d_model'), modelId: id, variant: z.string().optional(), sceneId: z.string().optional(), caption: L10n })
  .strict();

/**
 * A simulation. `phet`: a PhET HTML5 sim bundled in the pack's media (CC-BY 4.0);
 * `animation`: a Kinetix procedural animation (packages/kinetix_animations);
 * `kinetix_sim`: a Kinetix simulation widget (lab.graph-plotter, lab.pendulum…);
 * `kinetix_cs`: a Kinetix computer-science player (algo.bubble, sim.logic, code.sql…).
 */
export const SimulationBlock = z
  .object({
    ...base,
    type: z.literal('simulation'),
    source: z.enum(['phet', 'animation', 'kinetix_sim', 'kinetix_cs']),
    simId: z.string().min(1),
    preset: z.string().optional(),
    caption: L10n,
    /** What to try, shown beside the sim and read aloud. */
    tryThis: z.array(L10n).default([]),
  })
  .strict();

/** A Kinetix virtual lab bench (packages/kinetix_labs, 116 labs). */
export const VirtualLabBlock = z.object({ ...base, type: z.literal('virtual_lab'), labId: z.string().min(1), preset: z.string().optional(), aim: L10n }).strict();

export const ExampleBlock = z
  .object({ ...base, type: z.literal('example'), problem: L10n, steps: z.array(L10n).min(1), answer: L10n })
  .strict();

/** How the class answers together. */
export const QuizMode = z.enum(['monitor', 'roll_call', 'team']);

export const ClassQuizBlock = z
  .object({ ...base, type: z.literal('class_quiz'), questionIds: z.array(id).min(1), mode: QuizMode.default('monitor'), secondsPerQuestion: z.number().int().min(10).max(300).default(45) })
  .strict();

export const PyqBlock = z.object({ ...base, type: z.literal('pyq'), questionIds: z.array(id).min(1), exams: z.array(Exam).default([]) }).strict();

export const TrickBlock = z.object({ ...base, type: z.literal('trick'), heading: L10n, body: L10n, mnemonic: L10n.optional() }).strict();

/** The end of a topic. `homework` is shown at the end of a Self-Learning period. */
export const RecapBlock = z
  .object({ ...base, type: z.literal('recap'), points: z.array(L10n).min(1), homework: z.array(L10n).default([]), homeworkQuestionIds: z.array(id).default([]) })
  .strict();

export const Block = z.discriminatedUnion('type', [
  IntroBlock,
  ConceptBlock,
  Model3dBlock,
  SimulationBlock,
  VirtualLabBlock,
  ExampleBlock,
  ClassQuizBlock,
  PyqBlock,
  TrickBlock,
  RecapBlock,
]);
export type Block = z.infer<typeof Block>;
export type BlockType = Block['type'];
export const BLOCK_TYPES = ['intro', 'concept', '3d_model', 'simulation', 'virtual_lab', 'example', 'class_quiz', 'pyq', 'trick', 'recap'] as const satisfies readonly BlockType[];

// ---------------------------------------------------------------- syllabus & lessons

/** `boards` narrows a topic to some curricula (a section one board dropped); the chapter's boards otherwise. */
export const Topic = z.object({ id, title: L10n, ncert: z.string().optional(), boards }).strict();
export const Chapter = z
  .object({
    id, subject: Subject, year: Year, number: z.number().int().min(1), title: L10n, topics: z.array(Topic).default([]), exams: z.array(Exam).default([]),
    /** Curricula that teach this chapter. */
    boards: z.array(Board).min(1).default(['kar_pu', 'cbse']),
    /** The NCERT (or Department of PUE) book the chapter is from, when a subject has several. */
    book: z.string().optional(),
  })
  .strict();
export type Chapter = z.infer<typeof Chapter>;

/** One topic's lesson: an ordered list of blocks. */
export const Lesson = z
  .object({ id, chapterId: id, topicId: id, title: L10n, minutes: z.number().int().min(5).max(120), blocks: z.array(Block).min(1) })
  .strict()
  .superRefine((l, ctx) => {
    const seen = new Set<string>();
    for (const b of l.blocks) {
      if (seen.has(b.id)) ctx.addIssue({ code: 'custom', message: `duplicate block id ${b.id}` });
      seen.add(b.id);
    }
  });
export type Lesson = z.infer<typeof Lesson>;

// ---------------------------------------------------------------- content packs

/**
 * A content pack is a zip: manifest.json, chapter.json, lessons/*.json, questions.json, media/…
 * plus manifest.sig (Ed25519 over the exact bytes of manifest.json). The manifest lists the
 * SHA-256 of every other file, so one signature covers the whole pack.
 */
export const PackFile = z.object({ path: z.string().min(1), sha256: z.string().regex(/^[0-9a-f]{64}$/), bytes: z.number().int().min(0) }).strict();

export const PackManifest = z
  .object({
    schemaVersion: z.literal(SCHEMA_VERSION),
    id,
    /** Semantic version; the board installs a higher version over a lower one. */
    version: z.string().regex(/^\d+\.\d+\.\d+$/),
    title: L10n,
    subject: Subject,
    year: Year,
    chapterId: id,
    createdAt: z.string(),
    /** The signing key's id, so keys can be rotated. */
    keyId: z.string(),
    files: z.array(PackFile).min(1),
  })
  .strict();
export type PackManifest = z.infer<typeof PackManifest>;

// ---------------------------------------------------------------- session logs (board → API)

/** One answer by the class or by a roll number. Never a name. */
export const AnswerLog = z
  .object({
    questionId: id,
    mode: QuizMode,
    /** Roll number for roll_call; team index for team; absent for monitor (whole class). */
    roll: z.number().int().min(1).max(300).optional(),
    team: z.number().int().min(0).max(7).optional(),
    chosen: z.number().int().min(0).max(3).nullable(),
    correct: z.boolean(),
    at: z.string(),
  })
  .strict();

export const SessionLog = z
  .object({
    id: z.string().uuid(),
    sectionId: z.string(),
    mode: z.enum(['teacher', 'self_learning']),
    chapterId: id,
    topicId: id,
    lessonId: id,
    packVersion: z.string(),
    startedAt: z.string(),
    endedAt: z.string().nullable(),
    blocksShown: z.array(z.string()),
    completed: z.boolean(),
    answers: z.array(AnswerLog).default([]),
    /** Present-roll count entered by the monitor, if any (a number, not a list). */
    present: z.number().int().min(0).max(300).optional(),
  })
  .strict();
export type SessionLog = z.infer<typeof SessionLog>;

/** Looks up a question by id; throws if a lesson refers to a missing one. */
export function checkQuestionRefs(lessons: Lesson[], questions: Question[]): string[] {
  const ids = new Set(questions.map((q) => q.id));
  const missing: string[] = [];
  for (const l of lessons)
    for (const b of l.blocks) {
      const refs = b.type === 'class_quiz' || b.type === 'pyq' ? b.questionIds : b.type === 'recap' ? b.homeworkQuestionIds : [];
      for (const r of refs) if (!ids.has(r)) missing.push(`${l.id}/${b.id} → ${r}`);
    }
  return missing;
}
