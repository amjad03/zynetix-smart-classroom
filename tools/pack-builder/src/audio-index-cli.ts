// Adds a built audio pack to the voice CDN index and signs the index:
//   node dist/audio-index-cli.js <dir with audio-index.json> <file.zpack>
// Writes <dir>/audio-index.json and audio-index.json.sig (raw Ed25519 signature of the exact bytes),
// and prints {entry, replaced, publicKey} as JSON. The pack's own signature is checked first.
// Key: PACK_SIGNING_KEY_FILE + PACK_KEY_ID (production), else the dev key in keys/.
import { createPrivateKey } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { addToAudioIndex, loadOrCreateKey, publicKeyHex, type AudioIndex } from './build';

const [dir, file] = process.argv.slice(2);
if (!dir || !file) {
  console.error('usage: audio-index-cli <indexDir> <file.zpack>');
  process.exit(2);
}
const keyId = process.env.PACK_KEY_ID ?? 'dev-2026';
const key = process.env.PACK_SIGNING_KEY_FILE
  ? { keyId, privateKey: createPrivateKey(readFileSync(process.env.PACK_SIGNING_KEY_FILE)) }
  : loadOrCreateKey(join(__dirname, '../keys'), keyId);
const at = join(dir, 'audio-index.json');
const index = existsSync(at) ? (JSON.parse(readFileSync(at, 'utf8')) as AudioIndex) : undefined;
if (index && index.keyId !== key.keyId) throw new Error(`index is signed by ${index.keyId}, not ${key.keyId}`);
const { bytes, sig, entry, replaced } = addToAudioIndex(index, new Uint8Array(readFileSync(file)), basename(file), key);
writeFileSync(at, bytes);
writeFileSync(`${at}.sig`, sig);
console.log(JSON.stringify({ entry, replaced: replaced ?? null, publicKey: publicKeyHex(key.privateKey) }));
