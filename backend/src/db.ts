import { createHash } from "node:crypto";
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { Pool, type PoolClient } from "pg";
import type { AppConfig } from "./config.js";

export function createPool(config: AppConfig): Pool {
  return new Pool({ connectionString: config.databaseUrl });
}

export async function runMigrations(pool: Pool, migrationsDir: string): Promise<void> {
  await pool.query(`
    create table if not exists schema_migrations (
      filename text primary key,
      applied_at timestamptz not null default now()
    )
  `);

  const files = (await readdir(migrationsDir))
    .filter((file) => file.endsWith(".sql"))
    .sort();

  for (const file of files) {
    const existing = await pool.query("select 1 from schema_migrations where filename = $1", [file]);
    if (existing.rowCount) {
      continue;
    }

    const sql = await readFile(path.join(migrationsDir, file), "utf8");
    const client = await pool.connect();
    try {
      await client.query("begin");
      await client.query(sql);
      await client.query("insert into schema_migrations (filename) values ($1)", [file]);
      await client.query("commit");
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
    }
  }
}

export function hashToken(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

export async function seedLocalMachineToken(pool: Pool, config: AppConfig): Promise<void> {
  if (!config.seedServerKey || !config.seedMachineToken) {
    return;
  }

  const tokenHash = hashToken(config.seedMachineToken);
  await pool.query(
    `insert into servers (server_key, display_name, active)
     values ($1, $2, true)
     on conflict (server_key) do update
       set display_name = excluded.display_name,
           active = true`,
    [config.seedServerKey, config.seedServerName ?? config.seedServerKey]
  );

  await pool.query(
    `insert into machine_tokens (token_id, server_key, token_hash, scopes)
     values ($1, $2, $3, $4)
     on conflict (token_id) do update
       set token_hash = excluded.token_hash,
           scopes = excluded.scopes,
           revoked_at = null`,
    [
      `seed:${config.seedServerKey}`,
      config.seedServerKey,
      tokenHash,
      ["stats:operation:start", "stats:operation:finish", "stats:read"]
    ]
  );
}

export async function withTransaction<T>(pool: Pool, fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("begin");
    const result = await fn(client);
    await client.query("commit");
    return result;
  } catch (error) {
    await client.query("rollback");
    throw error;
  } finally {
    client.release();
  }
}
