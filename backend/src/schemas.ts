import { z } from "zod";

const primitiveRecord = z.record(z.unknown());

export const playerSnapshotSchema = z.object({
  player_uid: z.string().min(1),
  name: z.string().optional()
}).catchall(z.unknown());

export const attendanceRecordSchema = z.object({
  player_uid: z.string().min(1)
}).catchall(z.unknown());

export const scoreboardStatSchema = z.object({
  player_uid: z.string().min(1)
}).catchall(z.unknown());

export const operationStartPayloadSchema = z.object({
  request_id: z.string().min(8),
  server_key: z.string().min(1),
  payload_version: z.number().int().positive(),
  started_at: z.string().datetime().optional(),
  mission: z.object({
    mission_uid: z.string().min(1),
    mission_name: z.string().min(1),
    world_name: z.string().min(1)
  }),
  source: primitiveRecord.optional(),
  players: z.array(playerSnapshotSchema).default([])
}).passthrough();

export const operationFinishPayloadSchema = z.object({
  request_id: z.string().min(8),
  server_key: z.string().min(1),
  payload_version: z.number().int().positive(),
  ended_at: z.string().datetime().optional(),
  outcome: z.string().default("completed"),
  players: z.array(playerSnapshotSchema).default([]),
  attendance_records: z.array(attendanceRecordSchema).default([]),
  scoreboard_stats: z.array(scoreboardStatSchema).default([])
}).passthrough();

export type OperationStartPayload = z.infer<typeof operationStartPayloadSchema>;
export type OperationFinishPayload = z.infer<typeof operationFinishPayloadSchema>;
