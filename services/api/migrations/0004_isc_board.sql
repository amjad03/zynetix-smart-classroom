-- ISC (CISCE Class XI/XII) sections alongside Karnataka PU and CBSE.
ALTER TABLE section DROP CONSTRAINT IF EXISTS section_board_check;
ALTER TABLE section ADD CONSTRAINT section_board_check CHECK (board IN ('kar_pu', 'cbse', 'isc'));
