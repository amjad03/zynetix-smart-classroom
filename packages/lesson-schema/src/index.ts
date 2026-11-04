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
  'accountancy', 'business_studies', 'economics', 'commerce',
  // Language
  'english',
]);
export type Subject = z.infer<typeof Subject>;

/** 1st PUC (NCERT Class 11) and 2nd PUC (NCERT Class 12). */
export const Year = z.enum(['puc1', 'puc2']);
export type Year = z.infer<typeof Year>;

/** Board exams (PUC = Karnataka II PUC, CBSE = CBSE Class 12) and entrance exams. */
/** JEE = JEE Main; JEE_ADV = JEE Advanced. */
export const Exam = z.enum(['PUC', 'CBSE', 'ISC', 'KCET', 'COMEDK', 'NEET', 'JEE', 'JEE_ADV', 'CUET']);

/** The curriculum a college follows. Both use NCERT books for most subjects; scope and exam pattern differ. */
export const Board = z.enum(['kar_pu', 'cbse', 'isc']);
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
    /** Four options, labelled A–D on the board (none for numeric questions). */
    options: z.array(L10n).max(4),
    /** Index into options (0 = A). For multi_correct, the first correct option; see `answers`. */
    answer: z.number().int().min(0).max(3),
    /** multi_correct (JEE Advanced): every correct option index. */
    answers: z.array(z.number().int().min(0).max(3)).min(1).max(4).optional(),
    /** numeric (JEE Main/Advanced integer or decimal type): the value and the accepted ± tolerance. */
    numericAnswer: z.number().optional(),
    tolerance: z.number().min(0).optional(),
    explanation: L10n.optional(),
    exams: z.array(Exam).min(1),
    difficulty: Difficulty,
    pyq: PyqRef.optional(),
    /** mcq (default); assertion_reason (options are the 4 standard A–R choices); case_based (needs `passage`). */
    format: z.enum(['mcq', 'assertion_reason', 'case_based', 'multi_correct', 'numeric']).default('mcq'),
    /** The case or source text a case_based question is about, shown above the stem. */
    passage: L10n.optional(),
    tags: z.array(z.string()).default([]),
  })
  .strict()
  .refine((q) => q.format !== 'case_based' || !!q.passage, { message: 'case_based questions need a passage' })
  .refine((q) => (q.format === 'numeric' ? q.numericAnswer !== undefined && q.options.length === 0 : q.options.length === 4), { message: 'numeric questions have numericAnswer and no options; others have 4 options' })
  .refine((q) => q.format !== 'multi_correct' || (!!q.answers && q.answers.includes(q.answer)), { message: 'multi_correct needs answers, including answer' });
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

// ---------------------------------------------------------------- whiteboard & interactives

/** Coordinates are on a 100 × 60 board grid (x right, y down). Colours are board ink names. */
const ink = z.enum(['white', 'yellow', 'red', 'green', 'blue', 'orange']).default('white');
const pt = z.tuple([z.number().min(0).max(100), z.number().min(0).max(60)]);
export const Draw = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('text'), at: pt, text: L10n, size: z.number().min(1).max(8).default(3), color: ink }).strict(),
  z.object({ kind: z.literal('math'), at: pt, tex: z.string(), size: z.number().min(1).max(8).default(3), color: ink }).strict(),
  z.object({ kind: z.enum(['line', 'arrow']), from: pt, to: pt, color: ink, dashed: z.boolean().optional() }).strict(),
  z.object({ kind: z.literal('rect'), from: pt, to: pt, color: ink, fill: z.boolean().optional() }).strict(),
  z.object({ kind: z.literal('circle'), at: pt, r: z.number().min(0.5).max(30), color: ink, fill: z.boolean().optional() }).strict(),
  z.object({ kind: z.literal('path'), points: z.array(pt).min(2), color: ink, closed: z.boolean().optional() }).strict(),
  /** Axes in a box; `plot` items inside the same step use the same box and ranges. */
  z.object({ kind: z.literal('axes'), from: pt, to: pt, x: z.tuple([z.number(), z.number()]), y: z.tuple([z.number(), z.number()]), xLabel: z.string().optional(), yLabel: z.string().optional(), color: ink }).strict(),
  /** y = f(x), e.g. "x^2 - 3*x", "sin(x)", "2*exp(-x/3)"; drawn in the step's axes box. */
  z.object({ kind: z.literal('plot'), fn: z.string().min(1), color: ink }).strict(),
]);
export type Draw = z.infer<typeof Draw>;
/** One board step: what appears (drawn in order), and what is said while it appears. */
export const BoardStep = z.object({ say: L10n.optional(), draw: z.array(Draw).min(1), clear: z.boolean().optional() }).strict();

export const WhiteboardBlock = z.object({ ...base, type: z.literal('whiteboard'), steps: z.array(BoardStep).min(1).max(20) }).strict();

const varName = z.string().regex(/^[a-zA-Z]\w*$/);
/** A number, or an expression (a string) over the block's variables, e.g. "v*cos(rad(a))*t". */
const num = z.union([z.number(), z.string().min(1)]);

/** A slider the class (or monitor) moves; `name` is used in expressions. */
export const Slider = z.object({ name: varName, label: L10n, min: z.number(), max: z.number(), step: z.number().positive(), value: z.number(), unit: z.string().optional() }).strict();
/** A named on/off switch: its name is 1 when on and 0 when off ("show forces", "friction on"). */
export const Toggle = z.object({ name: varName, label: L10n, value: z.boolean().default(false) }).strict();
/** A segmented selector: its name takes the chosen option's number (medium: air = 1, water = 1.33). */
export const Choice = z
  .object({ name: varName, label: L10n, options: z.array(z.object({ label: L10n, value: z.number() }).strict()).min(2).max(6), value: z.number() })
  .strict();
/** A named number that only buttons change (electrons added, generation number). Never reset by the time Reset. */
export const Counter = z.object({ name: varName, value: z.number().default(0), min: z.number().optional(), max: z.number().optional() }).strict();
/**
 * A momentary button. `set` assigns expressions (evaluated with the values before the press) to
 * sliders, toggles, choices or counters, e.g. {"n": "n + 1"}. `reset` rewinds time and the
 * integrator first; `play` then starts time (a "Launch" button is reset + play).
 */
export const Button = z
  .object({
    label: L10n,
    icon: z.enum(['play', 'add', 'remove', 'next', 'reset', 'launch', 'flip', 'check']).optional(),
    set: z.record(varName, num).default({}),
    reset: z.boolean().optional(),
    play: z.boolean().optional(),
  })
  .strict();
const range = z.tuple([z.number(), z.number()]);
const xy = z.tuple([z.number(), z.number()]);
/**
 * A point the class drags on a scene. Its position is the variables `<name>_x` and `<name>_y`.
 * It stays inside `box` (the view when absent), or moves only along `axis`, or slides on the
 * segment `line`; `snap` rounds both coordinates to a grid.
 */
export const Handle = z
  .object({
    name: varName,
    label: z.string().max(24).optional(),
    x: z.number(),
    y: z.number(),
    axis: z.enum(['x', 'y']).optional(),
    line: z.tuple([xy, xy]).optional(),
    box: z.object({ x: range, y: range }).strict().optional(),
    snap: z.number().positive().optional(),
    color: ink,
  })
  .strict();
/**
 * Time: the variable `t` runs from `min` to `max` (seconds of the model) with Play/Pause, speed,
 * Step, Reset and a scrubber. At `max` it stops, or starts again when `loop`. `stopWhen` pauses
 * it when the expression becomes true (e.g. "landed"). `dt` is the integrator's fixed step.
 */
export const TimeSpec = z
  .object({
    min: z.number().default(0),
    max: z.number(),
    loop: z.boolean().default(false),
    speeds: z.array(z.number().min(0.05).max(16)).min(1).max(6).default([0.25, 0.5, 1, 2, 4]),
    speed: z.number().default(1),
    autoplay: z.boolean().default(false),
    stopWhen: z.string().min(1).optional(),
    dt: z.number().positive().max(0.5).default(0.01),
    unit: z.string().max(8).default('s'),
  })
  .strict();
/** A derived variable: `name = expr`, evaluated in order (may use earlier vars, controls, state and t). */
export const SceneVar = z.object({ name: varName, expr: z.string().min(1) }).strict();
/** An integrated variable: starts at `init` (an expression of the controls) and changes at `rate` (d/dt). */
export const StateVar = z.object({ name: varName, init: num, rate: z.string().min(1) }).strict();

/** The world window of a scene: x and y ranges (x right, y up), optional axes and grid. */
export const SceneView = z
  .object({ x: range, y: range, axes: z.boolean().default(false), grid: z.boolean().default(false), xLabel: z.string().optional(), yLabel: z.string().optional(), equal: z.boolean().default(false) })
  .strict();
/** A colour: an ink name, or `scale` inks blended by `by` (0 = first, 1 = last), e.g. cold to hot. */
const color = z.union([ink, z.object({ by: z.string().min(1), scale: z.array(z.enum(['white', 'yellow', 'red', 'green', 'blue', 'orange'])).min(2).max(6) }).strict()]);
/** Fields every shape has: shown only when `visibleIf` is true; `opacity` 0..1. */
const shapeBase = { visibleIf: z.string().min(1).optional(), color: color.optional(), opacity: num.optional() };
const pts = z.array(z.tuple([num, num])).min(2).max(64);
export const SceneIcon = z.enum(['bulb', 'battery', 'resistor', 'capacitor', 'switch', 'magnet', 'lens', 'mirror', 'cell', 'beaker']);
/**
 * Shapes of a scene, in world units (sizes too, except `width`, `size` and `amp`, which are
 * screen points on the board). Every number may be an expression.
 */
export const Shape = z.discriminatedUnion('shape', [
  z.object({ shape: z.literal('circle'), ...shapeBase, x: num, y: num, r: num, fill: z.boolean().default(true), width: num.optional() }).strict(),
  z.object({ shape: z.literal('rect'), ...shapeBase, x: num, y: num, w: num, h: num, fill: z.boolean().default(true), width: num.optional() }).strict(),
  z.object({ shape: z.literal('line'), ...shapeBase, x1: num, y1: num, x2: num, y2: num, dashed: z.boolean().optional(), width: num.optional() }).strict(),
  /** A vector: from (x, y) by (dx, dy), with an optional label at its head. */
  z.object({ shape: z.literal('arrow'), ...shapeBase, x: num, y: num, dx: num, dy: num, label: z.string().max(24).optional(), width: num.optional() }).strict(),
  /** y = fn(x) from `from` to `to` (the view's x range by default), or a list of `points`. */
  z.object({ shape: z.literal('path'), ...shapeBase, fn: z.string().min(1).optional(), from: num.optional(), to: num.optional(), points: pts.optional(), closed: z.boolean().optional(), dashed: z.boolean().optional(), width: num.optional() }).strict(),
  z.object({ shape: z.literal('polygon'), ...shapeBase, points: pts.min(3), fill: z.boolean().default(true), width: num.optional() }).strict(),
  /** A wave y = fn(x) (use t to move it), drawn smoothly across the view. */
  z.object({ shape: z.literal('wave'), ...shapeBase, fn: z.string().min(1), from: num.optional(), to: num.optional(), width: num.optional() }).strict(),
  /** Text at (x, y); `{expr}` or `{expr:2}` inside it shows a value (2 decimals). */
  z.object({ shape: z.enum(['text', 'label']), ...shapeBase, x: num, y: num, text: L10n, size: num.optional(), align: z.enum(['left', 'center', 'right']).default('center') }).strict(),
  /** A zig-zag spring between two points. */
  z.object({ shape: z.literal('spring'), ...shapeBase, x1: num, y1: num, x2: num, y2: num, coils: z.number().int().min(2).max(40).default(10), amp: num.optional(), width: num.optional() }).strict(),
  /** The past positions of a point while time runs (up to `length` points). */
  z.object({ shape: z.literal('trail'), ...shapeBase, x: num, y: num, length: z.number().int().min(2).max(2000).default(300), width: num.optional() }).strict(),
  /** `count` dots; x, y, r, visibleIf and colour may use `i` (0, 1, … count − 1). */
  z.object({ shape: z.literal('particles'), ...shapeBase, count: z.number().int().min(1).max(400), x: num, y: num, r: num }).strict(),
  /** A built-in vector icon `size` world units wide, turned by `angle` degrees; `on` lights a bulb or closes a switch. */
  z.object({ shape: z.literal('icon'), ...shapeBase, icon: SceneIcon, x: num, y: num, size: num, angle: num.optional(), on: num.optional() }).strict(),
]);
export type Shape = z.infer<typeof Shape>;

/** The fields of a playfield, shared by `interactive` and `challenge` (see InteractiveBlock). */
const InteractiveKind = z.enum(['function_plot', 'vectors', 'bar_chart', 'pie_chart', 'unit_circle', 'number_line', 'readouts', 'scene']);
const playfield = {
  kind: InteractiveKind,
  fns: z.array(z.object({ fn: z.string().min(1), label: z.string().optional(), color: ink }).strict()).max(4).optional(),
  x: z.tuple([z.number(), z.number()]).optional(),
  y: z.tuple([z.number(), z.number()]).optional(),
  xLabel: z.string().optional(),
  yLabel: z.string().optional(),
  vectors: z.array(z.tuple([z.union([z.number(), z.string()]), z.union([z.number(), z.string()])])).max(4).optional(),
  data: z.record(z.union([z.number(), z.string()])).optional(),
  points: z.array(z.union([z.number(), z.string()])).max(8).optional(),
  /** function_plot: fixed targets drawn as flags at (x, y), e.g. where a projectile must land. */
  marks: z.array(z.object({ x: z.number(), y: z.number().default(0), label: z.string().max(24).optional() }).strict()).max(4).optional(),
  readouts: z.array(z.object({ label: L10n, expr: z.string(), unit: z.string().optional(), digits: z.number().int().min(0).max(6).default(2) }).strict()).max(4).default([]),
  // Controls beyond sliders (any kind). Handles need a scene.
  toggles: z.array(Toggle).max(4).optional(),
  choices: z.array(Choice).max(3).optional(),
  counters: z.array(Counter).max(4).optional(),
  buttons: z.array(Button).max(4).optional(),
  handles: z.array(Handle).max(4).optional(),
  /** Model time `t` with play/pause, speed, step, reset and a scrubber. */
  time: TimeSpec.optional(),
  /** Derived variables (any kind; readouts, fns and shapes may use them). */
  vars: z.array(SceneVar).max(24).optional(),
  /** Integrated variables (need `time`). */
  state: z.array(StateVar).max(8).optional(),
  integrator: z.enum(['euler', 'rk2']).default('rk2'),
  /** scene: the world window and the shapes drawn in it, back to front. */
  view: SceneView.optional(),
  shapes: z.array(Shape).max(60).optional(),
};
/**
 * Generic, data-driven interactives (no code per topic):
 * - function_plot: `fns` y = f(x, sliders…) on `x`/`y` ranges (graphs, demand/supply, waves, decay…)
 * - vectors: `vectors` [[x,y]…] where entries may be slider names; shows resultant
 * - bar_chart / pie_chart: `data` {label: value or slider name}
 * - unit_circle: angle slider `theta` (degrees) with sin/cos/tan read-outs
 * - number_line: `points` (values or slider names) on `x` range
 * - readouts: just computed values; `readouts` [{label, expr, unit}] work for every kind
 * - scene: an animated drawing (`view`, `shapes`) driven by every control, `time`, `vars` and
 *   `state` (docs/simulations.md is the authoring guide)
 */
export const InteractiveBlock = z
  .object({
    ...base,
    type: z.literal('interactive'),
    ...playfield,
    caption: L10n,
    sliders: z.array(Slider).max(4).default([]),
    tryThis: z.array(L10n).default([]),
  })
  .strict();

/**
 * A playable problem on a playfield (same fields as `interactive`): the class sets the
 * controls so that `goal` (an expression) lands within `tolerance` of `target`, e.g. "land the
 * projectile on x = 40 m", "set the price where Qd = Qs".
 * - `solution`: control values that hit the target (the pack builder checks it really does);
 *   every slider must be in it, toggles, choices and handle coordinates (`P_x`) may be.
 * - With `time`, locking in runs the model from the start until `stopWhen` or the end of time and
 *   the goal is taken there (it may use vars, state and t), e.g. "where the ball landed".
 * - `attempts`: tries before the answer is revealed; stars are 3, 2, 1 for a hit on the 1st, 2nd,
 *   3rd-or-later try. `timeLimit`: seconds per try (none when absent).
 * - `mode`: who plays: the whole class (monitor), teams taking turns, or a picked roll number.
 * - The goal's value is shown only after each try ("too high / too low"), never while dragging,
 *   so the class has to reason first; `readouts` must not give it away.
 */
export const ChallengeBlock = z
  .object({
    ...base,
    type: z.literal('challenge'),
    ...playfield,
    /** The mission, read aloud: what to hit and how. */
    prompt: L10n,
    sliders: z.array(Slider).min(1).max(4),
    goal: z.string().min(1),
    goalLabel: L10n,
    goalUnit: z.string().optional(),
    target: z.number(),
    tolerance: z.number().positive(),
    solution: z.record(z.number()),
    attempts: z.number().int().min(1).max(10).default(3),
    timeLimit: z.number().int().min(10).max(600).optional(),
    mode: QuizMode.default('team'),
    hint: L10n.optional(),
    /** Shown on success or after the last try: why the solution works. */
    explanation: L10n,
  })
  .strict();

// ---------------------------------------------------------------- activities (non-numeric)

const itemId = z.string().regex(/^[a-z0-9][a-z0-9_-]*$/);
/** A spot on an activity diagram (world units of `view`): a circle of radius `r`, or a `w` × `h` box centred at (x, y). */
export const Target = z.object({ id: itemId, x: z.number(), y: z.number(), r: z.number().positive().optional(), w: z.number().positive().optional(), h: z.number().positive().optional(), label: L10n }).strict();
/**
 * A touch activity, checked with feedback (Check, Show answer, Reset), for any subject:
 * - sort: drag `items` into 2–4 `buckets` (each item names its bucket in `answer`)
 * - order: arrange `steps` (given in the right order; shown shuffled)
 * - match: connect each `pairs` left to its right (rights shown shuffled)
 * - label: drag each target's label onto its spot on a diagram (`view` + `shapes`, + `distractors`)
 * - hotspot: tap the right spot(s) on a diagram: `targets`, the right ones in `answer`
 * - fill: choose the word for each blank `__1__`, `__2__`… of `passage` from `blanks[n-1].options`
 * With `questionId`, the class's first Check is recorded as an answer (source "activity").
 */
export const ActivityBlock = z
  .object({
    ...base,
    type: z.literal('activity'),
    kind: z.enum(['sort', 'order', 'match', 'label', 'hotspot', 'fill']),
    prompt: L10n,
    questionId: id.optional(),
    buckets: z.array(z.object({ id: itemId, label: L10n }).strict()).min(2).max(4).optional(),
    items: z.array(z.object({ text: L10n, answer: itemId }).strict()).min(2).max(16).optional(),
    steps: z.array(L10n).min(3).max(10).optional(),
    pairs: z.array(z.object({ left: L10n, right: L10n }).strict()).min(2).max(8).optional(),
    view: SceneView.optional(),
    shapes: z.array(Shape).max(60).optional(),
    targets: z.array(Target).min(2).max(10).optional(),
    distractors: z.array(L10n).max(4).optional(),
    answer: z.array(itemId).min(1).optional(),
    passage: L10n.optional(),
    blanks: z.array(z.object({ options: z.array(L10n).min(2).max(5), answer: z.number().int().min(0).max(4) }).strict()).min(1).max(10).optional(),
    /** Shown after Check or Show answer: why. */
    explanation: L10n.optional(),
  })
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
  WhiteboardBlock,
  InteractiveBlock,
  ChallengeBlock,
  ActivityBlock,
]);
export type Block = z.infer<typeof Block>;
export type BlockType = Block['type'];
export const BLOCK_TYPES = ['intro', 'concept', '3d_model', 'simulation', 'virtual_lab', 'example', 'class_quiz', 'pyq', 'trick', 'recap', 'whiteboard', 'interactive', 'challenge', 'activity'] as const satisfies readonly BlockType[];

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
    /** The question's topic and chapter (older boards leave them out; the API looks them up). */
    topicId: id.optional(),
    chapterId: id.optional(),
    /** How the answer was captured: roll_call, team, monitor, hands, phone, paper, exam, challenge… A short code, never free text. */
    source: z.string().regex(/^[a-z][a-z_]{1,23}$/).optional(),
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
