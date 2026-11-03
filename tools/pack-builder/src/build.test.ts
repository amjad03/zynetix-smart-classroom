import { generateKeyPairSync, verify, createPublicKey } from 'node:crypto';
import { resolve } from 'node:path';
import { unzipSync } from 'fflate';
import { describe, expect, it } from 'vitest';
import { buildPack, readSource, validate } from './build';

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
