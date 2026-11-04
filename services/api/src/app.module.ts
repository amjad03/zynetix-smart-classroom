import { join } from 'node:path';
import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AuthController, DeviceGuard, StaffGuard } from './auth';
import { BoardController } from './board.controller';
import { CmsController } from './cms.controller';
import { DB, Db } from './db/db';
import { HealthController } from './health';
import { OutcomesController } from './outcomes.controller';
import { KEYS, LocalStorage, S3Storage, STORAGE, loadKey } from './infra';

@Module({
  controllers: [AuthController, BoardController, AdminController, CmsController, OutcomesController, HealthController],
  providers: [
    { provide: DB, useFactory: () => Db.fromEnv() },
    { provide: STORAGE, useFactory: () => (process.env.S3_BUCKET ? new S3Storage(process.env.S3_BUCKET) : new LocalStorage(process.env.LOCAL_STORAGE ?? join(process.cwd(), 'storage'))) },
    {
      provide: KEYS,
      useFactory: () => ({
        pack: { keyId: process.env.PACK_KEY_ID ?? 'dev-2026', privateKey: loadKey(process.env.PACK_SIGNING_KEY_FILE, 'pack') },
        licence: loadKey(process.env.LICENCE_KEY_FILE, 'licence'),
      }),
    },
    StaffGuard,
    DeviceGuard,
  ],
})
export class AppModule {}
