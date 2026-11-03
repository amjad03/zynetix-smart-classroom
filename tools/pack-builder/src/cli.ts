// Builds every pack in content/packs into content/dist and copies them into the board app's seed assets.
import { copyFileSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { buildPack, loadOrCreateKey, readSource } from './build';

const repo = resolve(__dirname, '../../..');
const content = join(repo, 'content');
const out = join(content, 'dist');
const seed = join(repo, 'apps/board/assets/packs');
mkdirSync(out, { recursive: true });
mkdirSync(seed, { recursive: true });
const key = loadOrCreateKey(join(__dirname, '../keys'), process.env.PACK_KEY_ID ?? 'dev-2026');
const index: { id: string; version: string; file: string }[] = [];
for (const dir of readdirSync(join(content, 'packs'))) {
  const src = readSource(content, dir);
  const { bytes, manifest } = buildPack(src, key);
  const file = `${manifest.id}-${manifest.version}.zpack`;
  writeFileSync(join(out, file), bytes);
  copyFileSync(join(out, file), join(seed, file));
  index.push({ id: manifest.id, version: manifest.version, file });
  console.log(`${file}  ${(bytes.length / 1024).toFixed(0)} KB  ${src.lessons.length} lessons, ${src.questions.length} questions`);
}
writeFileSync(join(seed, 'index.json'), JSON.stringify(index, null, 2) + '\n');
copyFileSync(join(__dirname, `../keys/${key.keyId}.public.json`), join(seed, 'trusted-key.json'));
const syl = join(repo, 'apps/board/assets/syllabus');
mkdirSync(syl, { recursive: true });
for (const f of readdirSync(join(content, 'syllabus'))) copyFileSync(join(content, 'syllabus', f), join(syl, f));
