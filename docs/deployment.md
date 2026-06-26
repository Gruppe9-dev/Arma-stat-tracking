# Deployment

## Backend

1. Copy `.env.example` to `.env`.
2. Change `POSTGRES_PASSWORD` and `GRP9_MACHINE_TOKEN`.
3. Start the stack:

```powershell
docker compose up -d --build
```

The API is bound to localhost only:

```text
127.0.0.1:${API_PORT:-3000}
```

## Backup

Example manual PostgreSQL dump:

```powershell
docker compose exec postgres pg_dump -U grp9_stats grp9_stats > backups/grp9_stats.sql
```

## Arma Server

Deploy both mods to the Arma server root:

```text
@grp9_stats
@grp9_stats_server
```

Launch with:

```text
-mod=@CBA_A3;@ace;@grp9_stats
-serverMod=@grp9_stats_server
```

Copy `servermod/grp9_stats_server/grp9_stats_server.example.toml` to the deployed server-only mod as `grp9_stats_server.toml` and insert the real local token.

## Build Packages

Client/server addon:

```powershell
Push-Location addons\grp9_stats
hemtt build
Pop-Location
```

Windows x64 serverMod package including the native extension:

```powershell
.\scripts\Build-ServerModPackage.ps1
```

The script copies the Rust release DLL to:

```text
servermod\grp9_stats_server\.hemttout\build\grp9_stats_ext_x64.dll
```

That name is important for Arma 3 x64 when SQF calls:

```sqf
"grp9_stats_ext" callExtension ...
```

## Manual MVP Operation Triggers

The MVP starts with manual operation triggers. Run these in the server execution context, for example through the server debug console:

```sqf
[] call grp9_stats_fnc_startOperation;
```

At operation end:

```sqf
[] call grp9_stats_fnc_finishOperation;
```

If you run this from a client-side Zeus/debug context, execute it on the server instead:

```sqf
[] remoteExecCall ["grp9_stats_fnc_startOperation", 2];
[] remoteExecCall ["grp9_stats_fnc_finishOperation", 2];
```

The remote execution variant only works when the mission's `CfgRemoteExec` allows these functions. For first tests, prefer server-side execution.

These manual calls are intentionally thin wrappers. Later, mission-framework start/end hooks can call the same functions without changing the backend contract.
