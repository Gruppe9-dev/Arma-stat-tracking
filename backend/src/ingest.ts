import { createHash, randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import type { Pool, PoolClient } from "pg";
import { createMachineAuth } from "./auth.js";
import { withTransaction } from "./db.js";
import {
  operationFinishPayloadSchema,
  operationStartPayloadSchema,
  type OperationFinishPayload,
  type OperationStartPayload
} from "./schemas.js";
import { stableStringify } from "./stableJson.js";

type StoredIngestResponse = {
  statusCode: number;
  body: unknown;
};

function payloadHash(payload: unknown): string {
  return createHash("sha256").update(stableStringify(payload), "utf8").digest("hex");
}

function numberOrZero(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function jsonParam(value: unknown): string {
  return JSON.stringify(value ?? null);
}

async function getStoredRequest(client: PoolClient, requestId: string, hash: string): Promise<StoredIngestResponse | null> {
  const existing = await client.query(
    `select payload_hash, response_body, status_code
     from ingest_requests
     where request_id = $1
     for update`,
    [requestId]
  );

  if (!existing.rowCount) {
    return null;
  }

  const row = existing.rows[0] as { payload_hash: string; response_body: unknown; status_code: number };
  if (row.payload_hash !== hash) {
    return { statusCode: 409, body: { error: "request_id_payload_conflict" } };
  }

  return { statusCode: row.status_code, body: row.response_body };
}

async function storeIngestResponse(
  client: PoolClient,
  requestId: string,
  operationId: string | null,
  endpoint: string,
  hash: string,
  response: StoredIngestResponse
): Promise<void> {
  await client.query(
    `insert into ingest_requests (request_id, operation_id, endpoint, payload_hash, response_body, status_code)
     values ($1, $2, $3, $4, $5, $6)`,
    [requestId, operationId, endpoint, hash, jsonParam(response.body), response.statusCode]
  );
}

async function upsertPlayers(client: PoolClient, players: Array<Record<string, unknown>>): Promise<void> {
  for (const player of players) {
    await client.query(
      `insert into players (player_uid, last_name, first_seen_at, last_seen_at, raw_last_player)
       values ($1, $2, now(), now(), $3)
       on conflict (player_uid) do update
         set last_name = excluded.last_name,
             last_seen_at = now(),
             raw_last_player = excluded.raw_last_player`,
      [player.player_uid, stringOrNull(player.name), jsonParam(player)]
    );
  }
}

async function handleStart(client: PoolClient, payload: OperationStartPayload): Promise<StoredIngestResponse> {
  const operationId = randomUUID();
  await client.query(
    `insert into operations (
       id, server_key, mission_uid, mission_name, world_name,
       status, outcome, started_at, raw_start_payload
     ) values ($1, $2, $3, $4, $5, 'started', null, coalesce($6::timestamptz, now()), $7)`,
    [
      operationId,
      payload.server_key,
      payload.mission.mission_uid,
      payload.mission.mission_name,
      payload.mission.world_name,
      payload.started_at ?? null,
      jsonParam(payload)
    ]
  );

  await upsertPlayers(client, payload.players);

  return {
    statusCode: 201,
    body: {
      operation_id: operationId,
      status: "started"
    }
  };
}

async function handleFinish(
  client: PoolClient,
  operationId: string,
  payload: OperationFinishPayload
): Promise<StoredIngestResponse> {
  const operation = await client.query(
    `select id, server_key, status
     from operations
     where id = $1
     for update`,
    [operationId]
  );

  if (!operation.rowCount) {
    return { statusCode: 404, body: { error: "operation_not_found" } };
  }

  const operationRow = operation.rows[0] as { server_key: string; status: string };
  if (operationRow.server_key !== payload.server_key) {
    return { statusCode: 409, body: { error: "operation_server_key_mismatch" } };
  }

  await upsertPlayers(client, payload.players);

  await client.query(
    `update operations
     set status = 'finished',
         outcome = $2,
         ended_at = coalesce($3::timestamptz, now()),
         raw_finish_payload = $4
     where id = $1`,
    [operationId, payload.outcome, payload.ended_at ?? null, jsonParam(payload)]
  );

  for (const record of payload.attendance_records) {
    await client.query(
      `insert into operation_players (
         operation_id, player_uid, name_at_start, name_at_end,
         side_at_start, side_at_end, group_at_start, group_at_end,
         role_at_start, role_at_end, joined_after_start,
         disconnect_count, reconnect_count, attended_seconds,
         missed_seconds, attendance_ratio
       ) values (
         $1, $2, $3, $4, $5, $6, $7, $8,
         $9, $10, $11, $12, $13, $14, $15, $16
       )
       on conflict (operation_id, player_uid) do update set
         name_at_start = excluded.name_at_start,
         name_at_end = excluded.name_at_end,
         side_at_start = excluded.side_at_start,
         side_at_end = excluded.side_at_end,
         group_at_start = excluded.group_at_start,
         group_at_end = excluded.group_at_end,
         role_at_start = excluded.role_at_start,
         role_at_end = excluded.role_at_end,
         joined_after_start = excluded.joined_after_start,
         disconnect_count = excluded.disconnect_count,
         reconnect_count = excluded.reconnect_count,
         attended_seconds = excluded.attended_seconds,
         missed_seconds = excluded.missed_seconds,
         attendance_ratio = excluded.attendance_ratio`,
      [
        operationId,
        record.player_uid,
        stringOrNull(record.name_at_start),
        stringOrNull(record.name_at_end),
        stringOrNull(record.side_at_start),
        stringOrNull(record.side_at_end),
        stringOrNull(record.group_at_start),
        stringOrNull(record.group_at_end),
        stringOrNull(record.role_at_start),
        stringOrNull(record.role_at_end),
        Boolean(record.joined_after_start),
        numberOrZero(record.disconnect_count),
        numberOrZero(record.reconnect_count),
        numberOrZero(record.attended_seconds),
        numberOrZero(record.missed_seconds),
        numberOrZero(record.attendance_ratio)
      ]
    );
  }

  for (const stat of payload.scoreboard_stats) {
    await client.query(
      `insert into operation_player_stats (
         operation_id, player_uid, infantry_kills, soft_vehicle_kills,
         armor_kills, air_kills, deaths, score,
         raw_scoreboard_baseline, raw_scoreboard_latest
       ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       on conflict (operation_id, player_uid) do update set
         infantry_kills = excluded.infantry_kills,
         soft_vehicle_kills = excluded.soft_vehicle_kills,
         armor_kills = excluded.armor_kills,
         air_kills = excluded.air_kills,
         deaths = excluded.deaths,
         score = excluded.score,
         raw_scoreboard_baseline = excluded.raw_scoreboard_baseline,
         raw_scoreboard_latest = excluded.raw_scoreboard_latest`,
      [
        operationId,
        stat.player_uid,
        numberOrZero(stat.infantry_kills),
        numberOrZero(stat.soft_vehicle_kills),
        numberOrZero(stat.armor_kills),
        numberOrZero(stat.air_kills),
        numberOrZero(stat.deaths),
        numberOrZero(stat.score),
        jsonParam(stat.raw_scoreboard_baseline ?? null),
        jsonParam(stat.raw_scoreboard_latest ?? null)
      ]
    );
  }

  return {
    statusCode: 200,
    body: {
      operation_id: operationId,
      status: "finished"
    }
  };
}

export async function registerIngestRoutes(app: FastifyInstance, pool: Pool): Promise<void> {
  app.post(
    "/v1/operations/start",
    { preHandler: createMachineAuth(pool, "stats:operation:start") },
    async (request, reply) => {
      const payload = operationStartPayloadSchema.parse(request.body);
      if (payload.server_key !== request.machineAuth?.serverKey) {
        return reply.code(403).send({ error: "server_key_mismatch" });
      }

      const hash = payloadHash(payload);
      const response = await withTransaction(pool, async (client) => {
        const stored = await getStoredRequest(client, payload.request_id, hash);
        if (stored) {
          return stored;
        }

        const created = await handleStart(client, payload);
        await storeIngestResponse(
          client,
          payload.request_id,
          (created.body as { operation_id: string }).operation_id,
          "operations.start",
          hash,
          created
        );
        return created;
      });

      return reply.code(response.statusCode).send(response.body);
    }
  );

  app.post(
    "/v1/operations/:operationId/finish",
    { preHandler: createMachineAuth(pool, "stats:operation:finish") },
    async (request, reply) => {
      const params = request.params as { operationId: string };
      const payload = operationFinishPayloadSchema.parse(request.body);
      if (payload.server_key !== request.machineAuth?.serverKey) {
        return reply.code(403).send({ error: "server_key_mismatch" });
      }

      const hash = payloadHash(payload);
      const response = await withTransaction(pool, async (client) => {
        const stored = await getStoredRequest(client, payload.request_id, hash);
        if (stored) {
          return stored;
        }

        const finished = await handleFinish(client, params.operationId, payload);
        await storeIngestResponse(client, payload.request_id, params.operationId, "operations.finish", hash, finished);
        return finished;
      });

      return reply.code(response.statusCode).send(response.body);
    }
  );
}
