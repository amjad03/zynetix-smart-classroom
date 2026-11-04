import { describe, expect, it } from 'vitest';
import { Block, Lesson, Question, checkQuestionRefs, BLOCK_TYPES } from './index';

const q = {
  id: 'q1', chapterId: 'c', stem: { en: 'x?' }, options: [{ en: 'a' }, { en: 'b' }, { en: 'c' }, { en: 'd' }],
  answer: 2, exams: ['KCET'], difficulty: 'easy',
};

describe('schema', () => {
  it('accepts every block type', () => {
    expect(BLOCK_TYPES).toHaveLength(13);
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
});
