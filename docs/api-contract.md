# API Contract

The MVP API is local-only and still authenticated for ingest writes.

## Authentication

Ingest endpoints require:

```http
Authorization: Bearer <machine_token>
X-GRP9-Server-Key: main
Content-Type: application/json
```

The token must belong to the same `server_key` as the payload.

## Idempotency

Every ingest request includes `request_id`.

- Same `request_id` and same payload hash returns the stored response.
- Same `request_id` and different payload hash returns `409 Conflict`.

## Start Operation

```http
POST /v1/operations/start
```

```json
{
  "request_id": "main:start:2026-06-26T18-00-00Z:altis:co-op-night",
  "server_key": "main",
  "payload_version": 1,
  "started_at": "2026-06-26T18:00:00Z",
  "mission": {
    "mission_uid": "altis:co-op-night",
    "mission_name": "Co-op Night",
    "world_name": "Altis"
  },
  "source": {
    "addon": "grp9_stats",
    "servermod": "grp9_stats_server",
    "extension": "grp9_stats_ext"
  },
  "players": []
}
```

Response:

```json
{
  "operation_id": "00000000-0000-0000-0000-000000000000",
  "status": "started"
}
```

## Finish Operation

```http
POST /v1/operations/:operation_id/finish
```

```json
{
  "request_id": "main:finish:00000000-0000-0000-0000-000000000000",
  "server_key": "main",
  "payload_version": 1,
  "ended_at": "2026-06-26T20:00:00Z",
  "outcome": "completed",
  "players": [],
  "attendance_records": [],
  "scoreboard_stats": []
}
```

Only finished operations are included in stats exports.

## Manual Arma Trigger Functions

The first Arma MVP uses manual server-side trigger functions:

```sqf
[] call grp9_stats_fnc_startOperation;
[] call grp9_stats_fnc_finishOperation;
```

`startOperation` calls `operation_start` in `grp9_stats_ext`, which posts to `/v1/operations/start`.

`finishOperation` calls `operation_finish` in `grp9_stats_ext`, which posts to `/v1/operations/:operation_id/finish`.

Mission hooks can call these same functions later.
