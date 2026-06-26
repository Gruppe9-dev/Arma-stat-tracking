# grp9_stats_ext

Native Arma `callExtension` bridge for the server-only stats mod.

Current state: ABI skeleton with config loading and direct HTTP submission for:

- `health`
- `operation_start`
- `operation_finish`

The next implementation step is adding local NDJSON retry queue support.

Expected build targets:

- Windows x64: `grp9_stats_ext_x64.dll`
- Linux x64: `grp9_stats_ext_x64.so`
