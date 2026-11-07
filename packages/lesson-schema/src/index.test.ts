import { describe, expect, it } from 'vitest';
import { Block, FormulaSheet, Lesson, MockPattern, Question, checkQuestionRefs, revealSteps, BLOCK_TYPES } from './index';

const q = {
  id: 'q1', chapterId: 'c', stem: { en: 'x?' }, options: [{ en: 'a' }, { en: 'b' }, { en: 'c' }, { en: 'd' }],
  answer: 2, exams: ['KCET'], difficulty: 'easy',
};

describe('schema', () => {
  it('accepts every block type', () => {
    expect(BLOCK_TYPES).toHaveLength(16);
    const ok = Block.safeParse({ id: 'b', type: 'simulation', source: 'phet', simId: 'molarity', caption: { en: 'c' } });
    expect(ok.success).toBe(true);
  });
  it('rejects a question without four options', () => {
    expect(Question.safeParse({ ...q, options: q.options.slice(0, 3) }).success).toBe(false);
    expect(Question.safeParse(q).success).toBe(true);
  });
  it('rejects duplicate block ids and finds missing question refs', () => {
    const lesson = {
      id: 'l', chapterId: 'c', topicId: 't', title: { en: 'L' }, minutes: 40,
      blocks: [
        { id: 'a', type: 'class_quiz', questionIds: ['q1', 'q9'] },
        { id: 'a', type: 'recap', points: [{ en: 'p' }] },
      ],
    };
    expect(Lesson.safeParse(lesson).success).toBe(false);
    lesson.blocks[1].id = 'b';
    const parsed = Lesson.parse(lesson);
    expect(checkQuestionRefs([parsed], [Question.parse(q)])).toEqual(['l/a → q9']);
  });
  it('has no field that could hold a student name', () => {
    const json = JSON.stringify(Object.keys((Lesson as any)._def.schema.shape));
    expect(json).not.toMatch(/name|student/i);
  });
  it('takes explainers and concept videos, and checks them in a lesson', () => {
    const ex = { id: 'e', type: 'explainer', heading: { en: 'Current' }, reveal: true, misconception: { myth: { en: 'used up' }, truth: { en: 'not used up' } }, watch: [{ title: { en: 'a' }, say: { en: 'b' } }, { title: { en: 'c' }, say: { en: 'd' } }], analogy: { headline: { en: 'like water' }, pairs: [[{ en: 'pump' }, { en: 'battery' }]] } };
    const parsed = Block.parse(ex);
    expect(revealSteps(parsed)).toBe(2);
    const vid = { id: 'v', type: 'concept_video', video: { provider: 'youtube', id: 'dQw4w9WgXcQ', title: { en: 'Ohm' }, chapters: [{ at: 30, label: { en: 'V = IR' } }] } };
    expect(Block.safeParse(vid).success).toBe(true);
    expect(Block.safeParse({ ...vid, video: { ...vid.video, provider: 'vimeo' } }).success).toBe(false);
    const lesson = { id: 'l', chapterId: 'c', topicId: 't', title: { en: 'L' }, minutes: 40, blocks: [{ id: 'e', type: 'explainer', heading: { en: 'x' } }] };
    expect(Lesson.safeParse(lesson).success).toBe(false); // an empty explainer
    expect(Lesson.safeParse({ ...lesson, blocks: [ex, vid] }).success).toBe(true);
  });
  it('takes formula sheets and mock patterns', () => {
    expect(FormulaSheet.safeParse({ chapterId: 'c', formulas: [{ id: 'f1', name: { en: 'Ohm' }, tex: 'V = IR' }] }).success).toBe(true);
    expect(MockPattern.safeParse({ id: 'kcet', exam: 'KCET', title: { en: 'KCET' }, blurb: { en: 'b' }, minutes: 80, sections: [{ subject: 'physics', count: 60, plus: 1, minus: 0 }] }).success).toBe(true);
  });
});
