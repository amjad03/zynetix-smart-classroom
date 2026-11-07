// Bundled by extract.mjs against the quest-academy (Zynetix School) source. React, framer-motion
// and the app shell are stubbed: only the content data (text, questions, formulas) is read.
import { examQuestions } from '@/content/exam/questions';
import { formulaSheets } from '@/content/exam/formulas';
import { MOCK_TESTS, EXAM_META } from '@/lib/exam';
import { EXPLAINERS } from '@/explainers';
import { extraTopics, CHAPTER_LESSONS } from '@/content/subjects/extra';
import { driveLessonVideos } from '@/content/videos/drive';
import { lessonVideo } from '@/content/videos';
import manifest from '@/content/board-lessons/manifest.json';
import * as b_bio11_1 from '@/content/exam/bank/bio11-1';
import * as b_bio11_2 from '@/content/exam/bank/bio11-2';
import * as b_bio11_3 from '@/content/exam/bank/bio11-3';
import * as b_bio12_1 from '@/content/exam/bank/bio12-1';
import * as b_bio12_2 from '@/content/exam/bank/bio12-2';
import * as b_bio12_3 from '@/content/exam/bank/bio12-3';
import * as b_che11_1 from '@/content/exam/bank/che11-1';
import * as b_che11_2 from '@/content/exam/bank/che11-2';
import * as b_che11_3 from '@/content/exam/bank/che11-3';
import * as b_che12_1 from '@/content/exam/bank/che12-1';
import * as b_che12_2 from '@/content/exam/bank/che12-2';
import * as b_che12_3 from '@/content/exam/bank/che12-3';
import * as b_mat11_1 from '@/content/exam/bank/mat11-1';
import * as b_mat11_2 from '@/content/exam/bank/mat11-2';
import * as b_mat11_3 from '@/content/exam/bank/mat11-3';
import * as b_mat11_4 from '@/content/exam/bank/mat11-4';
import * as b_mat12_1 from '@/content/exam/bank/mat12-1';
import * as b_mat12_2 from '@/content/exam/bank/mat12-2';
import * as b_mat12_3 from '@/content/exam/bank/mat12-3';
import * as b_mat12_4 from '@/content/exam/bank/mat12-4';
import * as b_phy11_1 from '@/content/exam/bank/phy11-1';
import * as b_phy11_2 from '@/content/exam/bank/phy11-2';
import * as b_phy11_3 from '@/content/exam/bank/phy11-3';
import * as b_phy11_4 from '@/content/exam/bank/phy11-4';
import * as b_phy12_1 from '@/content/exam/bank/phy12-1';
import * as b_phy12_2 from '@/content/exam/bank/phy12-2';
import * as b_phy12_3 from '@/content/exam/bank/phy12-3';
import * as b_phy12_4 from '@/content/exam/bank/phy12-4';

/** Bank formula sheets with their class (the bank files are per class: phy11-…, mat12-…). */
const BANK_FILES: [string, { formulas?: unknown[] }][] = [['11', b_bio11_1], ['11', b_bio11_2], ['11', b_bio11_3], ['12', b_bio12_1], ['12', b_bio12_2], ['12', b_bio12_3], ['11', b_che11_1], ['11', b_che11_2], ['11', b_che11_3], ['12', b_che12_1], ['12', b_che12_2], ['12', b_che12_3], ['11', b_mat11_1], ['11', b_mat11_2], ['11', b_mat11_3], ['11', b_mat11_4], ['12', b_mat12_1], ['12', b_mat12_2], ['12', b_mat12_3], ['12', b_mat12_4], ['11', b_phy11_1], ['11', b_phy11_2], ['11', b_phy11_3], ['11', b_phy11_4], ['12', b_phy12_1], ['12', b_phy12_2], ['12', b_phy12_3], ['12', b_phy12_4]];
const graded = new Map<unknown, string>();
for (const [g, m] of BANK_FILES) for (const f of m.formulas ?? []) graded.set(f, g);

const text = (v: unknown): string | undefined => (typeof v === 'string' ? v : undefined);

const courses = ['physics-senior', 'chemistry-senior', 'biology-senior', 'maths-senior', 'computer-science', 'electronics'];
const lessons: Record<string, unknown>[] = [];
const videos: Record<string, unknown> = {};
for (const course of courses)
  for (const t of extraTopics(course))
    for (const l of t.lessons) {
      const id = `${course}/${t.slug}/${l.slug}`;
      lessons.push({ id, course, topic: t.slug, topicTitle: t.title, title: l.title, summary: l.summary, track: l.track, blocks: l.blocks, quiz: l.quiz ?? [], challenge: l.challenge });
      const v = lessonVideo(id);
      const d = driveLessonVideos(id);
      if (v || d) videos[id] = { video: v, drive: d };
    }

const explainers = EXPLAINERS.map((e) => ({
  id: e.id, title: e.title, tagline: e.tagline, area: e.area, ages: e.ages, lessons: e.lessons,
  misconception: e.misconception,
  watch: (e.watch ?? []).map((s) => ({ title: s.title, say: s.say })),
  mission: e.mission && { goal: e.mission.goal, takeaway: e.mission.takeaway, steps: e.mission.steps.map((s) => ({ task: s.task, predict: s.predict, hint: s.hint, explain: s.explain })) },
  story: (e.story ?? []).map((p) => ({ caption: p.caption, speech: text(p.speech) })),
  like: e.like && { headline: e.like.headline, everyday: e.like.everyday.label, concept: e.like.concept.label, pairs: e.like.pairs, limits: e.like.limits },
}));

export const dump = {
  questions: examQuestions,
  formulas: formulaSheets.map((f) => ({ ...f, grade: graded.get(f) })),
  mocks: MOCK_TESTS,
  examMeta: EXAM_META,
  explainers,
  lessons,
  chapterLessons: CHAPTER_LESSONS,
  videos,
  boardLessons: manifest,
};
