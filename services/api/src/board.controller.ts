import { Body, Controller, ForbiddenException, Get, Inject, NotFoundException, Param, Post, Req, Res, UseGuards } from '@nestjs/common';
import type { Request, Response } from 'express';
import { SessionLog } from '@zynetix/lesson-schema';
import { z } from 'zod';
import { CurrentDevice, Device, DeviceGuard } from './auth';
import { DB, Db } from './db/db';
import { KEYS, Keys, STORAGE, Storage, Zod, sha256, signLicence, token } from './infra';

const Activate = z.object({ code: z.string().min(6).max(12), name: z.string().min(1).max(60), pin: z.string().regex(/^\d{4,6}$/) }).strict();
const Sync = z.object({ installed: z.record(z.string()).default({}), outbox: z.array(z.unknown()).max(500).default([]) }).strict();

const GRACE_DAYS = 30;
const apiBase = (req: Request) => process.env.PUBLIC_API_URL ?? `${req.protocol}://${req.get('host')}`;

export function cmpVersion(a: string, b: string) {
  const x = a.split('.').map(Number), y = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i];
  return 0;
}

@Controller('v1')
export class BoardController {
  constructor(@Inject(DB) private db: Db, @Inject(STORAGE) private storage: Storage, @Inject(KEYS) private keys: Keys) {}

  /** A board is registered with a one-time code from Admin → Boards; the person setting it up chooses the PIN. */
  @Post('devices/activate')
  async activate(@Body(new Zod(Activate)) b: z.infer<typeof Activate>) {
    const code = await this.db.one('SELECT * FROM activation_code WHERE code = $1 AND used_by IS NULL AND expires_at > now()', [b.code.toUpperCase()]);
    if (!code) throw new NotFoundException({ code: 'bad_activation_code' });
    const lic = await this.db.one('SELECT max_devices FROM licence WHERE college_id = $1', [code.college_id]);
    const n = await this.db.one<{ n: string }>('SELECT count(*) AS n FROM device WHERE college_id = $1', [code.college_id]);
    if (!lic || Number(n!.n) >= lic.max_devices) throw new ForbiddenException({ code: 'licence_device_limit' });
    const id = `brd_${token(9)}`, deviceToken = token(), salt = token(8);
    await this.db.tx(async (c) => {
      await c.query('INSERT INTO device(id, college_id, section_id, name, token_hash, pin_hash, pin_salt) VALUES ($1,$2,$3,$4,$5,$6,$7)', [
        id, code.college_id, code.section_id, b.name, sha256(deviceToken), sha256(`${salt}:${b.pin}`), salt,
      ]);
      await c.query('UPDATE activation_code SET used_by = $1 WHERE code = $2', [id, code.code]);
    });
    return { deviceId: id, deviceToken, config: await this.config({ id, collegeId: code.college_id, sectionId: code.section_id }) };
  }

  /**
   * Everything a board needs, in one idempotent call: logs up, packs/timetable/schedule/config down.
   * Logs are keyed by their UUID, so a retried sync never double-counts.
   */
  @Post('board/sync')
  @UseGuards(DeviceGuard)
  async sync(@CurrentDevice() d: Device, @Body(new Zod(Sync)) b: z.infer<typeof Sync>, @Req() req: Request) {
    const accepted: string[] = [], rejected: { id: unknown; issues: string[] }[] = [];
    for (const raw of b.outbox) {
      const r = SessionLog.safeParse(raw);
      if (!r.success) {
        rejected.push({ id: (raw as any)?.id, issues: r.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`) });
        continue;
      }
      const l = r.data;
      await this.db.q(
        `INSERT INTO session_log(id, device_id, section_id, mode, chapter_id, topic_id, lesson_id, pack_version, started_at, ended_at, completed, blocks_shown, answers, present)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) ON CONFLICT (id) DO NOTHING`,
        // The section is the device's, whatever the board claims.
        [l.id, d.id, d.sectionId, l.mode, l.chapterId, l.topicId, l.lessonId, l.packVersion, l.startedAt, l.endedAt, l.completed, JSON.stringify(l.blocksShown), JSON.stringify(l.answers), l.present ?? null],
      );
      accepted.push(l.id);
    }
    const config = await this.config(d);
    const licence = config.licence as { validUntil: string };
    const lapsed = new Date(licence.validUntil).getTime() + GRACE_DAYS * 864e5 < Date.now();
    const packs = lapsed ? [] : await this.packUpdates(d, b.installed, apiBase(req));
    const schedule = await this.db.q(
      `SELECT to_char(date,'YYYY-MM-DD') AS date, start_time AS start, end_time AS end, topic_id AS "topicId" FROM self_learning_booking
       WHERE section_id = $1 AND date BETWEEN current_date AND current_date + 7 ORDER BY date, start_time`, [d.sectionId]);
    const timetable = await this.db.q('SELECT day, period, start_time AS start, end_time AS end, subject FROM timetable_slot WHERE section_id = $1 ORDER BY day, period', [d.sectionId]);
    return { accepted, rejected, packs, schedule, timetable, config, licenceLapsed: lapsed };
  }

  /** Local-storage downloads (dev). In production the board gets pre-signed S3 URLs instead. */
  @Get('board/files/:key')
  async file(@Param('key') key: string, @Res() res: Response) {
    if (!key.startsWith('packs/')) throw new NotFoundException();
    try {
      res.type('application/zip').send(Buffer.from(await this.storage.get(key)));
    } catch {
      throw new NotFoundException();
    }
  }

  private async packUpdates(d: Device, installed: Record<string, string>, base: string) {
    const rows = await this.db.q(
      `SELECT DISTINCT ON (v.pack_id) v.pack_id AS id, v.version, v.sha256, v.bytes, v.storage_key
       FROM pack_version v JOIN pack p ON p.id = v.pack_id JOIN chapter c ON c.id = p.chapter_id JOIN section s ON s.id = $1
       WHERE c.subject = ANY(s.subjects) AND s.board = ANY(c.boards)
       ORDER BY v.pack_id, string_to_array(v.version, '.')::int[] DESC`, [d.sectionId]);
    const out = [];
    for (const r of rows) {
      if (installed[r.id] && cmpVersion(installed[r.id], r.version) >= 0) continue;
      out.push({ id: r.id, version: r.version, sha256: r.sha256, bytes: r.bytes, url: await this.storage.url(r.storage_key, base) });
    }
    return out;
  }

  private async config(d: Pick<Device, 'id' | 'collegeId' | 'sectionId'>) {
    const r = await this.db.one(
      `SELECT s.id, s.label, s.year, s.board, s.subjects, s.roll_count, s.period_minutes, c.name AS college, d.pin_hash, d.pin_salt, to_char(l.valid_until,'YYYY-MM-DD') AS valid_until
       FROM section s JOIN college c ON c.id = s.college_id JOIN device d ON d.id = $2 LEFT JOIN licence l ON l.college_id = c.id WHERE s.id = $1`, [d.sectionId, d.id]);
    const body = { deviceId: d.id, collegeId: d.collegeId, sectionId: d.sectionId, validUntil: r.valid_until ?? '1970-01-01', graceDays: GRACE_DAYS };
    return {
      sectionId: r.id, sectionLabel: r.label, year: r.year, board: r.board, subjects: r.subjects, rollCount: r.roll_count, periodMinutes: r.period_minutes, collegeName: r.college,
      pinHash: r.pin_hash, pinSalt: r.pin_salt, licence: body, licenceToken: signLicence(this.keys.licence, body),
    };
  }
}
