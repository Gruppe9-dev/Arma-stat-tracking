import type { FastifyInstance } from "fastify";
import type { Pool } from "pg";

function csvEscape(value: unknown): string {
  if (value === null || value === undefined) {
    return "";
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  const text = String(value);
  if (/[",\r\n]/.test(text)) {
    return `"${text.replace(/"/g, '""')}"`;
  }

  return text;
}

function toCsv(rows: Array<Record<string, unknown>>): string {
  if (rows.length === 0) {
    return "";
  }

  const headers = Object.keys(rows[0]);
  const lines = [headers.join(",")];
  for (const row of rows) {
    lines.push(headers.map((header) => csvEscape(row[header])).join(","));
  }

  return `${lines.join("\n")}\n`;
}

export async function registerQueryRoutes(app: FastifyInstance, pool: Pool): Promise<void> {
  app.get("/v1/operations", async () => {
    const result = await pool.query(
      `select id, server_key, mission_uid, mission_name, world_name, status, outcome, started_at, ended_at
       from operations
       order by started_at desc
       limit 200`
    );
    return { operations: result.rows };
  });

  app.get("/v1/operations/:operationId", async (request, reply) => {
    const { operationId } = request.params as { operationId: string };
    const result = await pool.query(
      `select id, server_key, mission_uid, mission_name, world_name, status, outcome, started_at, ended_at,
              raw_start_payload, raw_finish_payload
       from operations
       where id = $1`,
      [operationId]
    );

    if (!result.rowCount) {
      return reply.code(404).send({ error: "operation_not_found" });
    }

    return { operation: result.rows[0] };
  });

  app.get("/v1/operations/:operationId/players", async (request) => {
    const { operationId } = request.params as { operationId: string };
    const result = await pool.query(
      `select op.*, ops.infantry_kills, ops.soft_vehicle_kills, ops.armor_kills,
              ops.air_kills, ops.deaths, ops.score
       from operation_players op
       left join operation_player_stats ops
         on ops.operation_id = op.operation_id and ops.player_uid = op.player_uid
       where op.operation_id = $1
       order by op.name_at_end nulls last, op.player_uid`,
      [operationId]
    );

    return { players: result.rows };
  });

  app.get("/v1/players/:playerUid", async (request, reply) => {
    const { playerUid } = request.params as { playerUid: string };
    const player = await pool.query("select * from players where player_uid = $1", [playerUid]);
    if (!player.rowCount) {
      return reply.code(404).send({ error: "player_not_found" });
    }

    const operations = await pool.query(
      `select o.id as operation_id, o.mission_name, o.world_name, o.started_at, o.ended_at,
              op.attended_seconds, op.attendance_ratio,
              ops.infantry_kills, ops.soft_vehicle_kills, ops.armor_kills,
              ops.air_kills, ops.deaths, ops.score
       from operation_players op
       join operations o on o.id = op.operation_id
       left join operation_player_stats ops
         on ops.operation_id = op.operation_id and ops.player_uid = op.player_uid
       where op.player_uid = $1 and o.status = 'finished'
       order by o.started_at desc`,
      [playerUid]
    );

    return { player: player.rows[0], operations: operations.rows };
  });

  app.get("/v1/exports/operations.csv", async (_request, reply) => {
    const result = await pool.query(
      `select id, server_key, mission_uid, mission_name, world_name, outcome, started_at, ended_at
       from operations
       where status = 'finished'
       order by started_at desc`
    );

    return reply
      .header("content-type", "text/csv; charset=utf-8")
      .send(toCsv(result.rows));
  });

  app.get("/v1/exports/player-stats.csv", async (_request, reply) => {
    const result = await pool.query(
      `select o.id as operation_id, o.mission_name, o.world_name, o.started_at, o.ended_at,
              op.player_uid, coalesce(op.name_at_end, p.last_name) as player_name,
              op.attended_seconds, op.attendance_ratio,
              ops.infantry_kills, ops.soft_vehicle_kills, ops.armor_kills,
              ops.air_kills, ops.deaths, ops.score
       from operation_players op
       join operations o on o.id = op.operation_id
       join players p on p.player_uid = op.player_uid
       left join operation_player_stats ops
         on ops.operation_id = op.operation_id and ops.player_uid = op.player_uid
       where o.status = 'finished'
       order by o.started_at desc, player_name nulls last, op.player_uid`
    );

    return reply
      .header("content-type", "text/csv; charset=utf-8")
      .send(toCsv(result.rows));
  });
}
