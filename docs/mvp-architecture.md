# Gruppe 9 Stats Tracking MVP Architecture

## Understanding Summary

- Build a separate stats tracking repository at `F:\#Communitys\Arma Server\Arma stat tracking` for later standalone GitHub publishing.
- The MVP tracks operation attendance and Arma scoreboard statistics.
- The MVP does not include a web dashboard, ACE medic stats, crash reconstruction, or public API access.
- The backend is a TypeScript Fastify API running in Docker Compose with PostgreSQL.
- The Arma integration uses two HEMTT-built mods: `@grp9_stats` and `@grp9_stats_server`.
- The server-only mod sends data through a native extension to the backend API.
- The backend API is localhost-only in the MVP, but still requires Bearer machine-token authentication.

## Goals

- Capture operation start and finish.
- Identify players by Steam UID.
- Track attendance, reconnects, and disconnects during a mission.
- Capture scoreboard baseline and finish snapshots.
- Store raw ingest payloads and normalized relational rows.
- Provide API and CSV export endpoints for later analysis.
- Keep runtime overhead low by avoiding per-event API, database, or file writes.

## Non-Goals

- No web dashboard in the MVP.
- No ACE medic stats in the MVP.
- No loadout, position, vehicle, or full ACE medical-state persistence.
- No crash reconstruction for operations that do not reach a clean finish.
- No public API, reverse proxy, or HTTPS requirement in the MVP.
- No secrets in client-loaded mods or mission files.

## Repository Layout

```text
backend/
  TypeScript + Fastify API
  validation, auth, ingest, exports

database/
  migrations
  schema documentation
  seed/admin scripts

addons/
  grp9_stats/
    HEMTT project for @grp9_stats
    client/server addon
    no secrets

servermod/
  grp9_stats_server/
    HEMTT project for @grp9_stats_server
    server-only addon
    callExtension SQF wrapper
    config example
    no real token in Git

extension/
  grp9_stats_ext/
    native extension source
    Windows x64 and Linux x64 builds
    HTTP client
    local retry queue implementation

docs/
  architecture
  API contract
  payload schemas
  deployment guide
  decision log

docker-compose.yml
.env.example
README.md
```

## Mod Boundary

### `@grp9_stats`

Loaded through `-mod` and safe for clients to load.

Responsibilities:

- Public SQF functions.
- Operation lifecycle collection.
- Attendance tracking in RAM.
- Scoreboard baseline and finish snapshots.
- Payload construction.
- Future client-side collectors, such as ACE medic events.

Must not contain:

- API tokens.
- Backend credentials.
- Server-only configuration with secrets.
- Native extension secrets.

### `@grp9_stats_server`

Loaded through `-serverMod` on the dedicated server only.

Responsibilities:

- `callExtension` wrapper.
- Native extension binary packaging.
- Backend API URL and `server_key` configuration.
- Bearer machine token in local, uncommitted config.
- Local retry queue.
- Safe logs that never print secrets.

Launch shape:

```text
-mod=@CBA_A3;@ace;@grp9_stats
-serverMod=@grp9_stats_server
```

## Runtime Data Flow

```text
Mission starts
-> @grp9_stats initializes operation state on the server
-> captures player snapshot and scoreboard baseline
-> calls @grp9_stats_server wrapper
-> native extension sends POST /v1/operations/start
-> backend stores raw start payload and operation row

During mission
-> @grp9_stats keeps attendance ledger in RAM
-> reconnects and disconnects are tracked by Steam UID
-> no DB/API write per player event
-> optional internal reconcile happens only in RAM

Mission ends
-> @grp9_stats captures final player snapshot and scoreboard
-> calculates attendance and scoreboard deltas
-> calls @grp9_stats_server wrapper
-> native extension queues and sends POST /v1/operations/:id/finish
-> backend stores raw finish payload and normalized player/stat rows
```

Only successfully started and successfully finished operations count for stats.

## Storage Strategy

Runtime state lives in Arma server RAM during the mission.

The server-only native extension owns local durable transport state:

```text
@grp9_stats_server/
  grp9_stats_server.toml
  storage/
    queue.ndjson
```

The local queue stores operation start/finish submissions when the backend is unavailable. It must not store API tokens inside queue records.

PostgreSQL is the durable source for completed operation data, raw payloads, normalized stats, and exports.

## Backend Deployment

The backend runs through Docker Compose:

```text
Docker Compose
  backend API container
  PostgreSQL container
  persistent PostgreSQL volume
```

Backend startup behavior:

```text
docker compose up -d
-> backend waits for database connectivity
-> backend runs pending migrations
-> API starts after migrations complete
```

Backups and token rotation are manual/admin-script concerns in the MVP.

## API Contract

MVP endpoints:

```http
GET  /health

POST /v1/operations/start
POST /v1/operations/:operation_id/finish

GET  /v1/operations
GET  /v1/operations/:operation_id
GET  /v1/operations/:operation_id/players
GET  /v1/players/:player_uid
GET  /v1/exports/operations.csv
GET  /v1/exports/player-stats.csv
```

Ingest requests require:

```http
Authorization: Bearer <machine_token>
X-GRP9-Server-Key: main
Content-Type: application/json
```

Every ingest payload includes:

```json
{
  "request_id": "main:start:2026-06-26T18-00-00Z:altis:mission-name",
  "server_key": "main",
  "payload_version": 1
}
```

Backend ingest rules:

- `request_id` is idempotent.
- Same `request_id` and same payload hash returns the stored response.
- Same `request_id` with a different payload hash returns `409 Conflict`.
- `server_key` must match the authenticated machine token.
- Finish is accepted only when the referenced operation exists.
- Only finished operations are included in counted stats and exports.

## Database Model

MVP tables:

```text
servers
  server_key
  display_name
  active

machine_tokens
  token_id
  server_key
  token_hash
  scopes
  created_at
  revoked_at

operations
  id
  server_key
  mission_uid
  mission_name
  world_name
  status
  outcome
  started_at
  ended_at
  raw_start_payload
  raw_finish_payload

ingest_requests
  request_id
  operation_id
  endpoint
  payload_hash
  response_body
  status_code
  received_at

players
  player_uid
  last_name
  first_seen_at
  last_seen_at
  raw_last_player

operation_players
  operation_id
  player_uid
  name_at_start
  name_at_end
  side_at_start
  side_at_end
  group_at_start
  group_at_end
  role_at_start
  role_at_end
  joined_after_start
  disconnect_count
  reconnect_count
  attended_seconds
  missed_seconds
  attendance_ratio

operation_player_stats
  operation_id
  player_uid
  infantry_kills
  soft_vehicle_kills
  armor_kills
  air_kills
  deaths
  score
  raw_scoreboard_baseline
  raw_scoreboard_latest
```

Principles:

- Steam UID is the stable player identity.
- Player names are display metadata and may change.
- Raw payloads are retained for audit and reprocessing.
- Exports read from normalized tables, not directly from raw JSON only.

## Security Model

MVP network exposure:

```text
Arma server / serverMod
-> http://127.0.0.1:<api-port>
-> Docker backend
-> Docker PostgreSQL
```

Security requirements:

- Backend API is localhost-only in the MVP.
- Ingest still requires a Bearer machine token.
- The token is stored only in server-only local config.
- The token is never committed to Git.
- The token is never packed into `@grp9_stats`.
- The token is never stored in mission files.
- Logs must never include raw tokens or Authorization headers.

Future hardening options:

- HTTPS behind reverse proxy.
- IP allowlisting or VPN-only access.
- HMAC request signatures.
- Token rotation workflow.
- Rate limits and body size limits.

## Error Handling

```text
Backend offline
-> extension writes Start/Finish to local queue
-> later retry

Duplicate request_id
-> backend returns stored response

Same request_id, different payload
-> backend returns 409 Conflict

Start successful, Finish never arrives
-> operation remains incomplete
-> operation does not count for stats

Finish without known operation_id
-> backend rejects the request

Invalid token or mismatched server_key
-> backend rejects with 401/403

Headless Client in snapshot
-> SQF filters it before payload creation

Arma server crash during mission
-> MVP does not reconstruct the operation
-> operation does not count
```

## Build and Release

Backend:

```text
docker compose build backend
docker compose up -d
```

Client/server addon:

```text
cd addons/grp9_stats
hemtt build
```

Server-only mod:

```text
cd servermod/grp9_stats_server
hemtt build
```

Native extension:

```text
cd extension/grp9_stats_ext
build Windows x64 artifact
build Linux x64 artifact
copy artifacts into @grp9_stats_server release
```

Potential GitHub release artifacts:

- `grp9_stats-client.zip`
- `grp9_stats-servermod-win64.zip`
- `grp9_stats-servermod-linux64.zip`
- backend Docker image or Compose project

## Non-Functional Requirements

Performance:

- Support up to roughly 80 players in the MVP.
- Support one active operation per server/profile.
- Avoid per-event HTTP, database, and file writes.
- Use operation-level start/finish payloads.
- Store compact scalar values, not object references.

Reliability:

- Backend downtime should not lose start/finish payloads.
- Local queue retries must be idempotent.
- Incomplete operations must not pollute stats.

Maintainability:

- Keep API contract and payload schemas as shared truth.
- Keep backend, mods, extension, and database separated by directory.
- Keep secrets outside Git and outside client-loaded artifacts.

## Decision Log

| Decision | Alternatives Considered | Rationale |
|---|---|---|
| Use separate repository `Arma stat tracking` | Keep in existing Arma server repo | Clean GitHub separation and ownership boundaries. |
| MVP tracks Attendance + Scoreboard | Attendance only, Attendance + Scoreboard + Medic | Scoreboard adds useful stats without introducing ACE medic complexity. |
| No dashboard in MVP | Admin dashboard, public community dashboard | API/export first keeps scope focused. |
| Backend uses TypeScript + Fastify | Python + FastAPI | Strong fit for validation, typed contracts, and reference architecture. |
| PostgreSQL in Docker Compose | External DB | Easier deployment on the same machine. |
| API is localhost-only | LAN/VPN/public reverse proxy | Smallest initial network exposure. |
| Use Bearer machine token even locally | Trust localhost only | Low effort and prepares later hardening. |
| Native extension handles HTTP | File sidecar, payload-only prototype | Direct end-to-end Arma-to-backend pipeline. |
| Support Windows x64 and Linux x64 extension builds | Windows only | Keeps releases useful across common dedicated server environments. |
| Build both mods with HEMTT | Manual packaging | Standardized Arma addon/serverMod builds. |
| Split `@grp9_stats` and `@grp9_stats_server` | Single mod package | Clear secret boundary between client-safe and server-only artifacts. |
| Prefix project artifacts with `grp9` | `g9` | User-selected abbreviation for Gruppe 9. |
| Only finished operations count | Attempt crash reconstruction | Simpler MVP and avoids misleading partial stats. |
