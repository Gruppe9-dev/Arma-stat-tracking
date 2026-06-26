#include "\z\grp9_stats\addons\main\script_component.hpp"

if (!isServer) exitWith {};

missionNamespace setVariable ["grp9_stats_operationActive", false];
missionNamespace setVariable ["grp9_stats_operationId", ""];
missionNamespace setVariable ["grp9_stats_operationLocalId", ""];
missionNamespace setVariable ["grp9_stats_operationStartedAtTick", 0];
missionNamespace setVariable ["grp9_stats_attendance", createHashMap];
missionNamespace setVariable ["grp9_stats_scoreboardBaseline", createHashMap];

diag_log "[grp9_stats] Server stats state initialized.";
