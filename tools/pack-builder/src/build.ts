/**
 * Builds signed content packs (.zpack) from content/packs/<id>/ (see docs/architecture.md).
 * Used by the CLI for the seed packs and by the API when the CMS publishes a pack.
 */
import { createHash, createPrivateKey, createPublicKey, generateKeyPairSync, sign, KeyObject } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';
import { zipSync } from 'fflate';
import { Chapter, Lesson, PackManifest, Question, SCHEMA_VERSION, checkQuestionRefs } from '@zynetix/lesson-schema';

export interface PackSource {
  id: string;
  version: string;
  chapter: Chapter;
  lessons: Lesson[];
  questions: Question[];
  /** Media files: path inside the pack (media/…) → bytes. */
  media: Record<string, Uint8Array>;
}

export interface SigningKey { keyId: string; privateKey: KeyObject }

const sha256 = (b: Uint8Array) => createHash('sha256').update(b).digest('hex');
const json = (v: unknown) => new TextEncoder().encode(JSON.stringify(v, null, 1) + '\n');

/** Validates a pack. Returns problems; empty means it can be built. */
export function validate(src: PackSource): string[] {
  const problems: string[] = [];
  const topicIds = new Set(src.chapter.topics.map((t) => t.id));
  for (const l of src.lessons) {
    if (l.chapterId !== src.chapter.id) problems.push(`${l.id}: chapterId ${l.chapterId} is not ${src.chapter.id}`);
    if (!topicIds.has(l.topicId)) problems.push(`${l.id}: topic ${l.topicId} is not in the syllabus`);
    for (const b of l.blocks)
      if (b.type === 'simulation' && b.source === 'phet' && !src.media[`media/phet/${b.simId}.html`])
        problems.push(`${l.id}/${b.id}: media/phet/${b.simId}.html is missing`);
  }
  problems.push(...checkQuestionRefs(src.lessons, src.questions).map((m) => `missing question ${m}`));
  return problems;
}

/** Builds the zip: manifest.json (hashes of every file) + manifest.sig (Ed25519 over the manifest bytes). */
export function buildPack(src: PackSource, key: SigningKey, now = new Date()): { bytes: Uint8Array; manifest: PackManifest } {
  const problems = validate(src);
  if (problems.length) throw new Error(`pack ${src.id} is not valid:\n  ${problems.join('\n  ')}`);
  const files: Record<string, Uint8Array> = {
    'chapter.json': json(src.chapter),
    'questions.json': json(src.questions),
    ...Object.fromEntries(src.lessons.map((l) => [`lessons/${l.topicId.split('.').pop()}.json`, json(l)])),
    ...src.media,
  };
  const manifest = PackManifest.parse({
    schemaVersion: SCHEMA_VERSION,
    id: src.id,
    version: src.version,
    title: src.chapter.title,
    subject: src.chapter.subject,
    year: src.chapter.year,
    chapterId: src.chapter.id,
    createdAt: now.toISOString(),
    keyId: key.keyId,
    files: Object.entries(files).map(([path, b]) => ({ path, sha256: sha256(b), bytes: b.length })),
  });
  const manifestBytes = json(manifest);
  const sig = sign(null, manifestBytes, key.privateKey);
  // HTML/JS media is already large text; level 6 is a good size/speed trade-off on a board.
  const bytes = zipSync({ 'manifest.json': manifestBytes, 'manifest.sig': new Uint8Array(sig), ...files }, { level: 6 });
  return { bytes, manifest };
}

/** The raw 32-byte Ed25519 public key as hex, the form the board embeds. */
export function publicKeyHex(k: KeyObject): string {
  const der = createPublicKey(k).export({ format: 'der', type: 'spki' });
  return Buffer.from(der.subarray(der.length - 32)).toString('hex');
}

/** Loads the signing key from a PEM file, creating a dev key the first time. */
export function loadOrCreateKey(dir: string, keyId: string): SigningKey {
  const file = join(dir, `${keyId}.private.pem`);
  if (!existsSync(file)) {
    mkdirSync(dir, { recursive: true });
    const { privateKey } = generateKeyPairSync('ed25519');
    writeFileSync(file, privateKey.export({ format: 'pem', type: 'pkcs8' }), { mode: 0o600 });
  }
  const privateKey = createPrivateKey(readFileSync(file));
  writeFileSync(join(dir, `${keyId}.public.json`), JSON.stringify({ keyId, ed25519: publicKeyHex(privateKey) }, null, 2) + '\n');
  return { keyId, privateKey };
}

/** Reads content/packs/<dir> with the chapter from content/syllabus. */
export function readSource(contentRoot: string, dir: string): PackSource {
  const root = join(contentRoot, 'packs', dir);
  const meta = JSON.parse(readFileSync(join(root, 'pack.json'), 'utf8')) as { id: string; chapterId: string; version: string };
  let chapter: Chapter | undefined;
  for (const f of readdirSync(join(contentRoot, 'syllabus')).filter((f) => f !== 'index.json')) {
    const found = (JSON.parse(readFileSync(join(contentRoot, 'syllabus', f), 'utf8')) as unknown[]).map((c) => Chapter.parse(c)).find((c) => c.id === meta.chapterId);
    if (found) chapter = found;
  }
  if (!chapter) throw new Error(`${dir}: chapter ${meta.chapterId} is not in content/syllabus`);
  // A pack may bring its chapter's topics (topics.json) before they are merged into the syllabus.
  const topicsFile = join(root, 'topics.json');
  if (existsSync(topicsFile)) chapter = Chapter.parse({ ...chapter, topics: JSON.parse(readFileSync(topicsFile, 'utf8')) });
  const lessons = readdirSync(join(root, 'lessons')).sort().map((f) => Lesson.parse(JSON.parse(readFileSync(join(root, 'lessons', f), 'utf8'))));
  const questions = (JSON.parse(readFileSync(join(root, 'questions.json'), 'utf8')) as unknown[]).map((q) => Question.parse(q));
  const media: Record<string, Uint8Array> = {};
  const walk = (d: string) => {
    if (!existsSync(d)) return;
    for (const f of readdirSync(d)) {
      const p = join(d, f);
      if (statSync(p).isDirectory()) walk(p);
      else media[relative(root, p).split('\\').join('/')] = new Uint8Array(readFileSync(p));
    }
  };
  walk(join(root, 'media'));
  return { id: meta.id, version: meta.version, chapter, lessons, questions, media };
}
