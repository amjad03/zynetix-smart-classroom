"""Moves each pack's topics.json into content/syllabus/<subject>-<year>.json (the syllabus is the
single home of topics) and deletes topics.json. Safe to re-run.
Usage: merge_topics.py [packId ...]   (all packs when none given)"""
import json, pathlib, sys

root = pathlib.Path(__file__).resolve().parents[2] / 'content'
files = {p.name: json.loads(p.read_text()) for p in (root / 'syllabus').glob('*-puc*.json')}
by_id = {c['id']: (name, c) for name, chapters in files.items() for c in chapters}
moved = 0
only = set(sys.argv[1:])  # pack ids; all packs when none given
for tf in sorted((root / 'packs').glob('*/topics.json')):
    if only and tf.parent.name not in only:
        continue
    chapter_id = json.loads((tf.parent / 'pack.json').read_text())['chapterId']
    name, chapter = by_id[chapter_id]
    chapter['topics'] = json.loads(tf.read_text())
    tf.unlink()
    moved += 1
for name, chapters in files.items():
    (root / 'syllabus' / name).write_text(json.dumps(chapters, ensure_ascii=False, indent=2) + '\n')
print(f'merged topics for {moved} chapters')
