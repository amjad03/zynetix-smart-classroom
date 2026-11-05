import { generateKeyPairSync, verify, createPublicKey } from 'node:crypto';
import { resolve } from 'node:path';
import { unzipSync, zipSync } from 'fflate';
import { describe, expect, it } from 'vitest';
import { buildAudioPack, buildPack, checkAudio, lineSha, readSource, validate, verifyAudioPack } from './build';
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
});
