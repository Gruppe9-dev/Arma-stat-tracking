import type { FastifyReply, FastifyRequest } from "fastify";
import type { Pool } from "pg";
import { hashToken } from "./db.js";

declare module "fastify" {
  interface FastifyRequest {
    machineAuth?: {
      serverKey: string;
      tokenId: string;
      scopes: string[];
    };
  }
}

export function createMachineAuth(pool: Pool, requiredScope: string) {
  return async function machineAuth(request: FastifyRequest, reply: FastifyReply): Promise<void> {
    const serverKey = request.headers["x-grp9-server-key"];
    const authorization = request.headers.authorization;

    if (typeof serverKey !== "string" || !serverKey) {
      await reply.code(401).send({ error: "missing_server_key" });
      return;
    }

    if (!authorization?.startsWith("Bearer ")) {
      await reply.code(401).send({ error: "missing_bearer_token" });
      return;
    }

    const token = authorization.slice("Bearer ".length).trim();
    const tokenHash = hashToken(token);
    const result = await pool.query(
      `select token_id, server_key, scopes
       from machine_tokens
       where token_hash = $1
         and server_key = $2
         and revoked_at is null`,
      [tokenHash, serverKey]
    );

    if (!result.rowCount) {
      await reply.code(403).send({ error: "invalid_machine_token" });
      return;
    }

    const row = result.rows[0] as { token_id: string; server_key: string; scopes: string[] };
    if (!row.scopes.includes(requiredScope)) {
      await reply.code(403).send({ error: "missing_scope", scope: requiredScope });
      return;
    }

    request.machineAuth = {
      serverKey: row.server_key,
      tokenId: row.token_id,
      scopes: row.scopes
    };
  };
}
