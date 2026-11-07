import { generateKeyPairSync, verify, createPublicKey } from 'node:crypto';
import { resolve } from 'node:path';
import { unzipSync, zipSync } from 'fflate';
import { describe, expect, it } from 'vitest';
import { addToAudioIndex, buildAudioPack, buildPack, checkAudio, lineSha, readSource, validate, verifyAudioPack } from './build';
import { revealSteps } from '@zynetix/lesson-schema';

const content = resolve(__dirname, '../../../content');
const key = { keyId: 'test', privateKey: generateKeyPairSync('ed25519').privateKey };

describe.each(['puc1-physics-motion-in-a-straight-line', 'puc2-chemistry-solutions'])('seed pack %s', (dir) => {
  const src = readSource(content, dir);
  it('is valid and covers every topic with every block family', () => {
    expect(validate(src)).toEqual([]);
    expect(src.lessons).toHaveLength(src.chapter.topics.length);
    const types = new Set(src.lessons.flatMap((l) => l.blocks.map((b) => b.type)));
    for (const t of ['intro', 'concept', 'simulation', 'virtual_lab', 'example', 'class_quiz', 'pyq', 'trick', 'recap']) expect(types).toContain(t);
  });
  it('builds a pack whose signature and hashes verify', () => {
    const { bytes, manifest } = buildPack(src, key);
    const files = unzipSync(bytes);
    expect(verify(null, files['manifest.json'], createPublicKey(key.privateKey), Buffer.from(files['manifest.sig']))).toBe(true);
    expect(manifest.files.map((f) => f.path)).toContain('questions.json');
  });
});

it('carries the chapter formula sheet and the imported explainer and video blocks', () => {
  const src = readSource(content, 'puc2-physics-current-electricity');
  expect(validate(src)).toEqual([]);
  expect(src.formulas?.formulas.length).toBeGreaterThan(5);
  const { manifest } = buildPack(src, key);
  expect(manifest.files.map((f) => f.path)).toContain('formulas.json');
  expect(src.lessons.flatMap((l) => l.blocks).some((b) => b.type === 'explainer')).toBe(true);
  src.formulas!.chapterId = 'other';
  expect(validate(src).join()).toMatch(/formulas.json/);
});

it('rejects a lesson that points at a missing question', () => {
  const src = readSource(content, 'puc2-chemistry-solutions');
  src.questions = src.questions.filter((q) => q.id !== 'sol-q01');
  expect(validate(src).join()).toMatch(/sol-q01/);
});

describe('video-style narration', () => {
  const dir = 'puc1-physics-units-and-measurement';
  const lessonId = 'puc1-physics-01-units-and-measurement.t1.lesson';

  it('has one voice line per reveal step on every block of the sample lesson, in English and Kannada', () => {
    const src = readSource(content, dir);
    expect(validate(src)).toEqual([]);
    const l = src.lessons.find((x) => x.id === lessonId)!;
    for (const b of l.blocks) {
      expect(b.voice?.length, b.id).toBe(revealSteps(b, src.questions));
      for (const v of b.voice!) expect(v.say.kn, `${b.id}: ${v.say.en}`).toBeTruthy();
    }
    expect(l.blocks.map((b) => b.type)).toEqual(expect.arrayContaining(['3d_model', 'virtual_lab']));
  });

  it('rejects a block whose voice lines do not match its steps', () => {
    const src = readSource(content, dir);
    const b = src.lessons.find((x) => x.id === lessonId)!.blocks[0];
    b.voice = b.voice!.slice(1);
    expect(validate(src).join()).toMatch(/voice lines for 3 steps/);
  });

  it('builds a signed audio pack that verifies, and refuses a changed clip', () => {
    const src = readSource(content, dir);
    const l = src.lessons.find((x) => x.id === lessonId)!;
    const b = l.blocks[0];
    const clips = b.voice!.map((v, i) => ({
      clip: { lessonId, blockId: b.id, step: i + 1, clip: `${b.id}.${i + 1}`, file: `audio/t1/${b.id}.${i + 1}.opus`, ms: 1000 + i, sha: lineSha(v.say.en) },
      bytes: new TextEncoder().encode(`clip ${i}`),
    }));
    const { bytes, manifest } = buildAudioPack({ packId: src.id, chapterId: src.chapter.id, lang: 'en', version: '1.0.0', voice: { model: 'hexgrad/Kokoro-82M', voice: 'am_michael', licence: 'Apache-2.0' }, clips }, key);
    expect(manifest.id).toBe(`${src.id}-audio-en`);
    expect(verifyAudioPack(bytes, createPublicKey(key.privateKey)).clips).toHaveLength(3);
    const missing = checkAudio(src, manifest.clips);
    expect(missing.some((m) => m.includes('hook.1'))).toBe(false);
    expect(missing.length).toBeGreaterThan(40); // only the hook was rendered here
    const files = unzipSync(bytes);
    files['audio/t1/hook.1.opus'] = new TextEncoder().encode('changed');
    const other = generateKeyPairSync('ed25519').publicKey;
    expect(() => verifyAudioPack(zipSync(files), createPublicKey(key.privateKey))).toThrow(/corrupted/);
    expect(() => verifyAudioPack(bytes, other)).toThrow(/signature/);
  });
  it('adds verified audio packs to a signed CDN index, replacing an older version', () => {
    const clip = (v: string) => ({ clip: { lessonId: 'x.t1.lesson', blockId: 'hook', step: 1, clip: 'hook.1', file: 'audio/t1/hook.1.opus', ms: 1200, sha: lineSha('hi') }, bytes: new TextEncoder().encode(v) });
    const pack = (version: string) => buildAudioPack({ packId: 'x', chapterId: 'x', lang: 'en', version, voice: { model: 'hexgrad/Kokoro-82M', voice: 'am_michael', licence: 'Apache-2.0' }, clips: [clip(version)] }, key).bytes;
    const a = addToAudioIndex(undefined, pack('1.0.0'), 'x-audio-en-1.0.0.zpack', key);
    expect(verify(null, a.bytes, createPublicKey(key.privateKey), a.sig)).toBe(true);
    const b = addToAudioIndex(JSON.parse(new TextDecoder().decode(a.bytes)), pack('1.0.1'), 'x-audio-en-1.0.1.zpack', key);
    const idx = JSON.parse(new TextDecoder().decode(b.bytes));
    expect(idx.packs).toHaveLength(1);
    expect(idx.packs[0]).toMatchObject({ packId: 'x', lang: 'en', version: '1.0.1', url: 'x-audio-en-1.0.1.zpack', clips: 1, ms: 1200 });
    expect(b.replaced?.url).toBe('x-audio-en-1.0.0.zpack');
    const stranger = { keyId: 'test', privateKey: generateKeyPairSync('ed25519').privateKey };
    expect(() => addToAudioIndex(undefined, pack('1.0.0'), 'p.zpack', stranger)).toThrow(/signature/);
  });
});
