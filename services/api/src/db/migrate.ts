import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Db } from './db';

/** Applies migrations/*.sql in order, once each. */
export async function migrate(db: Db) {
  await db.q('CREATE TABLE IF NOT EXISTS _migration (name text PRIMARY KEY, at timestamptz DEFAULT now())');
  const done = new Set((await db.q<{ name: string }>('SELECT name FROM _migration')).map((r) => r.name));
  const dir = join(__dirname, '../../migrations');
  for (const f of readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) {
    if (done.has(f)) continue;
    await db.tx(async (c) => {
      await c.query(readFileSync(join(dir, f), 'utf8'));
      await c.query('INSERT INTO _migration(name) VALUES ($1)', [f]);
    });
  }
}

if (require.main === module) {
  const db = Db.fromEnv();
  migrate(db).then(() => db.pool.end()).then(() => console.log('migrated'));
}
