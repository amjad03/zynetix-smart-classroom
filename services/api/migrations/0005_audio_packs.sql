-- Narration audio packs: one signed .zpack per chapter pack and language (tools/voice +
-- pack-builder build-audio). Boards download one when the teacher asks ("Download voice") and
-- keep it offline; sync offers newer versions of those they have.
CREATE TABLE audio_pack_version (
  pack_id     text NOT NULL REFERENCES pack(id),
  lang        text NOT NULL CHECK (lang IN ('en', 'kn')),
  version     text NOT NULL,
  storage_key text NOT NULL,
  sha256      text NOT NULL,
  bytes       int  NOT NULL,
  clips       int  NOT NULL,
  seconds     int  NOT NULL,
  voice       jsonb NOT NULL,
  published_at timestamptz NOT NULL DEFAULT now(),
  published_by text,
  PRIMARY KEY (pack_id, lang, version)
);
