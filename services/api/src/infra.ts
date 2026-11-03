import { createHash, createPrivateKey, generateKeyPairSync, randomBytes, sign, KeyObject } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { BadRequestException, PipeTransform } from '@nestjs/common';
import { GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { ZodTypeAny, z } from 'zod';

export const sha256 = (b: string | Uint8Array) => createHash('sha256').update(b).digest('hex');
export const token = (n = 32) => randomBytes(n).toString('base64url');

/** An Ed25519 key from a PEM file; in dev a key is generated into ./keys on first use. */
export function loadKey(file: string | undefined, devName: string): KeyObject {
  const path = file || join(process.cwd(), 'keys', `${devName}.private.pem`);
  if (!existsSync(path)) {
    if (file) throw new Error(`key file ${file} not found`);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, generateKeyPairSync('ed25519').privateKey.export({ format: 'pem', type: 'pkcs8' }), { mode: 0o600 });
  }
  return createPrivateKey(readFileSync(path));
}

/** A signed licence the board checks offline: base64url(json) + "." + base64url(Ed25519 sig). */
export function signLicence(key: KeyObject, body: Record<string, unknown>): string {
  const b = Buffer.from(JSON.stringify(body));
  return `${b.toString('base64url')}.${sign(null, b, key).toString('base64url')}`;
}

/** Where packs and media live: S3 (ap-south-1) in production, a local folder in dev and tests. */
export interface Storage {
  put(key: string, body: Uint8Array, contentType?: string): Promise<void>;
  get(key: string): Promise<Uint8Array>;
  /** A URL the board downloads from (pre-signed for S3; an API route for local). */
  url(key: string, apiBase: string): Promise<string>;
}

export class LocalStorage implements Storage {
  constructor(private root: string) {}
  async put(key: string, body: Uint8Array) {
    const p = join(this.root, key);
    mkdirSync(dirname(p), { recursive: true });
    writeFileSync(p, body);
  }
  async get(key: string) {
    if (key.includes('..')) throw new Error('bad key');
    return new Uint8Array(readFileSync(join(this.root, key)));
  }
  async url(key: string, apiBase: string) {
    return `${apiBase}/v1/board/files/${encodeURIComponent(key)}`;
  }
}

export class S3Storage implements Storage {
  private s3 = new S3Client({ region: process.env.AWS_REGION ?? 'ap-south-1' });
  constructor(private bucket: string) {}
  async put(key: string, body: Uint8Array, contentType = 'application/octet-stream') {
    await this.s3.send(new PutObjectCommand({ Bucket: this.bucket, Key: key, Body: body, ContentType: contentType }));
  }
  async get(key: string) {
    const r = await this.s3.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
    return new Uint8Array(await r.Body!.transformToByteArray());
  }
  async url(key: string) {
    return getSignedUrl(this.s3, new GetObjectCommand({ Bucket: this.bucket, Key: key }), { expiresIn: 3600 });
  }
}

export const STORAGE = Symbol('STORAGE');
export const KEYS = Symbol('KEYS');
export interface Keys { pack: { keyId: string; privateKey: KeyObject }; licence: KeyObject }

/** Validates a body with a Zod schema; unknown fields are rejected by .strict() schemas. */
export class Zod<T extends ZodTypeAny> implements PipeTransform<unknown, z.infer<T>> {
  constructor(private schema: T) {}
  transform(v: unknown) {
    const r = this.schema.safeParse(v);
    if (!r.success) throw new BadRequestException({ code: 'invalid', issues: r.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`) });
    return r.data;
  }
}
