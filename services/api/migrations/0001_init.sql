-- Zynetix Smart Classroom. No student personal data: a section has a roll count, logs carry roll numbers.

CREATE TABLE college (
  id          text PRIMARY KEY,
  name        text NOT NULL,
  district    text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE section (
  id          text PRIMARY KEY,
  college_id  text NOT NULL REFERENCES college(id),
  label       text NOT NULL,                       -- "1st PUC · A · PCMB"
  year        text NOT NULL CHECK (year IN ('puc1','puc2')),
  subjects    text[] NOT NULL DEFAULT '{physics,chemistry,maths,biology}',
  roll_count  int  NOT NULL CHECK (roll_count BETWEEN 1 AND 300),
  period_minutes int NOT NULL DEFAULT 40
);

CREATE TABLE staff (
  id          serial PRIMARY KEY,
  email       text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  role        text NOT NULL CHECK (role IN ('admin','editor','super')),
  college_id  text REFERENCES college(id)          -- null for editors/super (content team)
);

CREATE TABLE device (
  id          text PRIMARY KEY,
  college_id  text NOT NULL REFERENCES college(id),
  section_id  text NOT NULL REFERENCES section(id),
  name        text NOT NULL,
  token_hash  text NOT NULL,
  pin_hash    text NOT NULL,
  pin_salt    text NOT NULL,
  activated_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz
);

CREATE TABLE activation_code (
  code        text PRIMARY KEY,
  college_id  text NOT NULL REFERENCES college(id),
  section_id  text NOT NULL REFERENCES section(id),
  expires_at  timestamptz NOT NULL,
  used_by     text REFERENCES device(id)
);

CREATE TABLE licence (
  college_id  text PRIMARY KEY REFERENCES college(id),
  valid_until date NOT NULL,
  max_devices int NOT NULL DEFAULT 50
);

-- Syllabus and content (CMS).
CREATE TABLE chapter (
  id          text PRIMARY KEY,
  subject     text NOT NULL,
  year        text NOT NULL,
  number      int  NOT NULL,
  title       jsonb NOT NULL,
  topics      jsonb NOT NULL DEFAULT '[]',
  exams       text[] NOT NULL DEFAULT '{}'
);

CREATE TABLE question (
  id          text PRIMARY KEY,
  chapter_id  text NOT NULL REFERENCES chapter(id),
  topic_id    text,
  data        jsonb NOT NULL,                      -- the full Question (lesson-schema)
  exams       text[] NOT NULL,
  difficulty  text NOT NULL,
  pyq_exam    text,
  pyq_year    int,
  pyq_verified boolean NOT NULL DEFAULT false,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX question_chapter ON question(chapter_id);

CREATE TABLE pack (
  id          text PRIMARY KEY,
  chapter_id  text NOT NULL REFERENCES chapter(id)
);

-- Draft lessons (one per topic) edited in the CMS; a published version freezes them into a .zpack.
CREATE TABLE lesson_draft (
  pack_id     text NOT NULL REFERENCES pack(id),
  topic_id    text NOT NULL,
  data        jsonb NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  text,
  PRIMARY KEY (pack_id, topic_id)
);

CREATE TABLE pack_media (
  pack_id     text NOT NULL REFERENCES pack(id),
  path        text NOT NULL,                       -- media/phet/molarity.html
  storage_key text NOT NULL,
  PRIMARY KEY (pack_id, path)
);

CREATE TABLE pack_version (
  pack_id     text NOT NULL REFERENCES pack(id),
  version     text NOT NULL,
  storage_key text NOT NULL,
  sha256      text NOT NULL,
  bytes       int  NOT NULL,
  notes       text,
  published_at timestamptz NOT NULL DEFAULT now(),
  published_by text,
  PRIMARY KEY (pack_id, version)
);

-- College timetable and Self-Learning bookings for absent teachers.
CREATE TABLE timetable_slot (
  id          serial PRIMARY KEY,
  section_id  text NOT NULL REFERENCES section(id),
  day         int  NOT NULL CHECK (day BETWEEN 1 AND 6),   -- Mon..Sat
  period      int  NOT NULL,
  start_time  text NOT NULL,                       -- HH:mm
  end_time    text NOT NULL,
  subject     text NOT NULL,
  teacher     text,                                -- staff name, not student data
  UNIQUE (section_id, day, period)
);

CREATE TABLE self_learning_booking (
  id          serial PRIMARY KEY,
  section_id  text NOT NULL REFERENCES section(id),
  date        date NOT NULL,
  start_time  text NOT NULL,
  end_time    text NOT NULL,
  topic_id    text NOT NULL,
  reason      text,
  created_by  text,
  UNIQUE (section_id, date, start_time)
);

CREATE TABLE session_log (
  id          uuid PRIMARY KEY,
  device_id   text NOT NULL REFERENCES device(id),
  section_id  text NOT NULL REFERENCES section(id),
  mode        text NOT NULL CHECK (mode IN ('teacher','self_learning')),
  chapter_id  text NOT NULL,
  topic_id    text NOT NULL,
  lesson_id   text NOT NULL,
  pack_version text NOT NULL,
  started_at  timestamptz NOT NULL,
  ended_at    timestamptz,
  completed   boolean NOT NULL,
  blocks_shown jsonb NOT NULL,
  answers     jsonb NOT NULL,
  present     int
);
CREATE INDEX session_log_section ON session_log(section_id, started_at);
