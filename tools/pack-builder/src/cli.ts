// Builds every pack in content/packs into content/dist and copies them into the board app's seed assets.
import { copyFileSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { createPrivateKey } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { buildPack, loadOrCreateKey, publicKeyHex, readSource } from './build';

const repo = resolve(__dirname, '../../..');
const content = join(repo, 'content');
const out = join(content, 'dist');
const seed = join(repo, 'apps/board/assets/packs');
mkdirSync(out, { recursive: true });
mkdirSync(seed, { recursive: true });
// Production: PACK_SIGNING_KEY_FILE + PACK_KEY_ID (kept outside the repo). Dev: a local key in keys/.
const keyId = process.env.PACK_KEY_ID ?? 'dev-2026';
const key = process.env.PACK_SIGNING_KEY_FILE
  ? { keyId, privateKey: createPrivateKey(readFileSync(process.env.PACK_SIGNING_KEY_FILE)) }
  : loadOrCreateKey(join(__dirname, '../keys'), keyId);
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
// The board trusts exactly the key these packs were signed with.
writeFileSync(join(seed, 'trusted-key.json'), JSON.stringify({ keyId: key.keyId, ed25519: publicKeyHex(key.privateKey) }, null, 2) + '\n');
const syl = join(repo, 'apps/board/assets/syllabus');
mkdirSync(syl, { recursive: true });
for (const f of readdirSync(join(content, 'syllabus'))) copyFileSync(join(content, 'syllabus', f), join(syl, f));
