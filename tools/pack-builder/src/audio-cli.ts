// Builds a chapter's signed narration audio pack from tools/voice output:
//   node dist/audio-cli.js <packDir> <en|kn>   → content/dist/audio/<packId>-audio-<lang>-<version>.zpack
// Signs with the dev key in keys/ unless PACK_SIGNING_KEY_FILE + PACK_KEY_ID are set (production,
// kept outside the repo). Unlike cli.ts it never touches the board's seed packs or trusted key.
import { createPrivateKey } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { buildAudioPack, checkAudio, loadOrCreateKey, readAudioSource, readSource } from './build';

const [dir, lang] = process.argv.slice(2);
if (!dir || (lang !== 'en' && lang !== 'kn')) {
  console.error('usage: audio-cli <packDir> <en|kn>');
  process.exit(2);
}
const repo = resolve(__dirname, '../../..');
const content = join(repo, 'content');
const keyId = process.env.PACK_KEY_ID ?? 'dev-2026';
const key = process.env.PACK_SIGNING_KEY_FILE
  ? { keyId, privateKey: createPrivateKey(readFileSync(process.env.PACK_SIGNING_KEY_FILE)) }
  : loadOrCreateKey(join(__dirname, '../keys'), keyId);
const audio = readAudioSource(content, dir, lang);
if (!audio) throw new Error(`no content/audio/${dir}/${lang}/clips.json: render it with tools/voice first`);
const problems = checkAudio(readSource(content, dir), audio.clips.map((c) => c.clip));
if (problems.length) console.warn(`${problems.length} voice lines without a current clip (they play silently):\n  ${problems.slice(0, 20).join('\n  ')}`);
const { bytes, manifest } = buildAudioPack(audio, key);
const out = join(content, 'dist', 'audio');
mkdirSync(out, { recursive: true });
const file = `${manifest.id}-${manifest.version}.zpack`;
writeFileSync(join(out, file), bytes);
const ms = manifest.clips.reduce((a, c) => a + c.ms, 0);
console.log(`${file}  ${(bytes.length / 1024).toFixed(0)} KB  ${manifest.clips.length} clips, ${(ms / 60000).toFixed(1)} min, key ${key.keyId}`);
