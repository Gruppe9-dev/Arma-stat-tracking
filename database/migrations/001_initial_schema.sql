create table if not exists servers (
  server_key text primary key,
  display_name text not null,
  active boolean not null default true
);

create table if not exists machine_tokens (
  token_id text primary key,
  server_key text not null references servers(server_key),
  token_hash text not null unique,
  scopes text[] not null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz null
);

create table if not exists operations (
  id uuid primary key,
  server_key text not null references servers(server_key),
  mission_uid text not null,
  mission_name text not null,
  world_name text not null,
  status text not null check (status in ('started', 'finished', 'failed', 'abandoned')),
  outcome text null,
  started_at timestamptz not null,
  ended_at timestamptz null,
  raw_start_payload jsonb not null,
  raw_finish_payload jsonb null
);

create index if not exists operations_server_started_idx
  on operations(server_key, started_at desc);

create table if not exists ingest_requests (
  request_id text primary key,
  operation_id uuid null references operations(id),
  endpoint text not null,
  payload_hash text not null,
  response_body jsonb not null,
  status_code integer not null,
  received_at timestamptz not null default now()
);

create index if not exists ingest_requests_operation_idx
  on ingest_requests(operation_id);

create table if not exists players (
  player_uid text primary key,
  last_name text null,
  first_seen_at timestamptz not null,
  last_seen_at timestamptz not null,
  raw_last_player jsonb not null
);

create table if not exists operation_players (
  operation_id uuid not null references operations(id) on delete cascade,
  player_uid text not null references players(player_uid),
  name_at_start text null,
  name_at_end text null,
  side_at_start text null,
  side_at_end text null,
  group_at_start text null,
  group_at_end text null,
  role_at_start text null,
  role_at_end text null,
  joined_after_start boolean not null default false,
  disconnect_count integer not null default 0,
  reconnect_count integer not null default 0,
  attended_seconds integer not null default 0,
  missed_seconds integer not null default 0,
  attendance_ratio numeric(6,5) not null default 0,
  primary key (operation_id, player_uid)
);

create index if not exists operation_players_player_idx
  on operation_players(player_uid);

create table if not exists operation_player_stats (
  operation_id uuid not null references operations(id) on delete cascade,
  player_uid text not null references players(player_uid),
  infantry_kills integer not null default 0,
  soft_vehicle_kills integer not null default 0,
  armor_kills integer not null default 0,
  air_kills integer not null default 0,
  deaths integer not null default 0,
  score integer not null default 0,
  raw_scoreboard_baseline jsonb null,
  raw_scoreboard_latest jsonb null,
  primary key (operation_id, player_uid)
);

create index if not exists operation_player_stats_player_idx
  on operation_player_stats(player_uid);
