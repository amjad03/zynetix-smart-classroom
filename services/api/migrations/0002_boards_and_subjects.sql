-- Karnataka PU and CBSE sections; Science + Commerce subjects.
ALTER TABLE section ADD COLUMN board text NOT NULL DEFAULT 'kar_pu' CHECK (board IN ('kar_pu', 'cbse'));
ALTER TABLE chapter ADD COLUMN boards text[] NOT NULL DEFAULT '{kar_pu,cbse}';
ALTER TABLE chapter ADD COLUMN book text;
