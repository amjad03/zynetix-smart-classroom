import { Pool, PoolClient } from 'pg';

/** One pg pool for the app. Queries are plain SQL; the schema is in migrations/. */
export class Db {
  constructor(readonly pool: Pool) {}

  static fromEnv(url = process.env.DATABASE_URL ?? 'postgres://zynetix:zynetix@localhost:5432/zynetix') {
    return new Db(new Pool({ connectionString: url, max: 10 }));
  }

  async q<T = any>(sql: string, params: unknown[] = []): Promise<T[]> {
    return (await this.pool.query(sql, params)).rows as T[];
  }

  async one<T = any>(sql: string, params: unknown[] = []): Promise<T | undefined> {
    return (await this.q<T>(sql, params))[0];
  }

  async tx<T>(fn: (c: PoolClient) => Promise<T>): Promise<T> {
    const c = await this.pool.connect();
    try {
      await c.query('BEGIN');
      const r = await fn(c);
      await c.query('COMMIT');
      return r;
    } catch (e) {
      await c.query('ROLLBACK');
      throw e;
    } finally {
      c.release();
    }
  }
}

export const DB = Symbol('DB');
