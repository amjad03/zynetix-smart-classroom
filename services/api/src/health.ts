import { Controller, Get, Inject } from '@nestjs/common';
import { DB, Db } from './db/db';

@Controller('health')
export class HealthController {
  constructor(@Inject(DB) private db: Db) {}
  @Get()
  async health() {
    await this.db.q('SELECT 1');
    return { ok: true };
  }
}
