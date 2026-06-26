# Gruppe 9 Stats Tracking

Contract-first monorepo for Gruppe 9 Arma 3 operation stats tracking.

## MVP Scope

- Attendance tracking
- Scoreboard start/finish deltas
- Local-only Fastify ingest API
- PostgreSQL persistence
- CSV/API exports
- HEMTT-built `@grp9_stats` and `@grp9_stats_server` packages
- Native extension bridge skeleton for Windows x64 and Linux x64

Not in the MVP: dashboard, medic stats, crash reconstruction, public API access, loadouts, positions, vehicles, or full ACE medical state.

## Repository Layout

```text
backend/                       Fastify API
database/migrations/           PostgreSQL migrations
addons/grp9_stats/             HEMTT project for @grp9_stats
servermod/grp9_stats_server/   HEMTT project for @grp9_stats_server
extension/grp9_stats_ext/      Native extension skeleton
docs/                          Architecture and API contract
```

## Local Backend Start

```powershell
Copy-Item .env.example .env
notepad .env
docker compose up -d --build
```

The backend binds to `127.0.0.1:${API_PORT}` only. The Arma server should use the same local machine.

## Health Check

```powershell
Invoke-RestMethod http://127.0.0.1:3000/health
```

## Arma Launch Shape

```text
-mod=@CBA_A3;@ace;@grp9_stats
-serverMod=@grp9_stats_server
```

## Build Arma Packages

```powershell
Push-Location addons\grp9_stats
hemtt build
Pop-Location

.\scripts\Build-ServerModPackage.ps1
```

## Manual MVP Triggers

Server debug console:

```sqf
[] call grp9_stats_fnc_startOperation;
[] call grp9_stats_fnc_finishOperation;
```

Client/Zeus debug context, if allowed by mission `CfgRemoteExec`:

```sqf
[] remoteExecCall ["grp9_stats_fnc_startOperation", 2];
[] remoteExecCall ["grp9_stats_fnc_finishOperation", 2];
```
