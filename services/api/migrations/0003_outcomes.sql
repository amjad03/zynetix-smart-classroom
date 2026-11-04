-- Outcomes: every logged answer as a row (roll numbers only, never names), so the college can see
-- who understands what, by topic, week, section and subject. Filled on sync; one row per answer.

CREATE TABLE answer (
  log_id      uuid NOT NULL REFERENCES session_log(id) ON DELETE CASCADE,
  idx         int  NOT NULL,                       -- position in the log's answers array
  section_id  text NOT NULL REFERENCES section(id),
  question_id text NOT NULL,
  topic_id    text NOT NULL,                       -- the question's topic (from the log, else the question bank, else the session)
  chapter_id  text NOT NULL,
  subject     text,                                -- from the chapter, when known
  roll        int,                                 -- null when the class answered together
  team        int,
  mode        text NOT NULL,                       -- monitor | roll_call | team
  source      text NOT NULL,                       -- roll_call, team, monitor, hands, phone, paper, exam, challenge…
  correct     boolean NOT NULL,
  at          timestamptz NOT NULL,
  PRIMARY KEY (log_id, idx)
);
CREATE INDEX answer_section_at ON answer(section_id, at);
CREATE INDEX answer_section_topic ON answer(section_id, topic_id, roll);

-- Demo colleges (screenshots, sales demos) are flagged so every Outcomes page says so.
ALTER TABLE college ADD COLUMN demo boolean NOT NULL DEFAULT false;

-- Logs synced before this migration: their answers become rows too (topic from the question bank).
INSERT INTO answer(log_id, idx, section_id, question_id, topic_id, chapter_id, subject, roll, team, mode, source, correct, at)
SELECT l.id, (a.n - 1)::int, l.section_id, a.v->>'questionId',
       coalesce(a.v->>'topicId', q.topic_id, l.topic_id),
       coalesce(a.v->>'chapterId', q.chapter_id, l.chapter_id),
       c.subject,
       (a.v->>'roll')::int, (a.v->>'team')::int, a.v->>'mode',
       coalesce(a.v->>'source', a.v->>'mode'), (a.v->>'correct')::boolean,
       coalesce((a.v->>'at')::timestamptz, l.started_at)
FROM session_log l
CROSS JOIN LATERAL jsonb_array_elements(l.answers) WITH ORDINALITY AS a(v, n)
LEFT JOIN question q ON q.id = a.v->>'questionId'
LEFT JOIN chapter c ON c.id = coalesce(a.v->>'chapterId', q.chapter_id, l.chapter_id)
ON CONFLICT DO NOTHING;
