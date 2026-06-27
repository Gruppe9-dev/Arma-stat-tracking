if (!isServer) exitWith {
    diag_log "[grp9_stats] startOperation ignored because it was not executed on the server.";
    false
};

if (missionNamespace getVariable ["grp9_stats_operationActive", false]) exitWith {
    diag_log "[grp9_stats] startOperation ignored because an operation is already active.";
    false
};

if (isNil "grp9_stats_server_fnc_callExtension") exitWith {
    diag_log "[grp9_stats] startOperation failed because @grp9_stats_server is not loaded.";
    false
};

private _players = call grp9_stats_fnc_getEligiblePlayers;
private _attendance = createHashMap;
private _scoreboardBaseline = createHashMap;
private _playerSnapshots = [];

{
    private _uid = getPlayerUID _x;
    private _snapshot = [_x] call grp9_stats_fnc_buildPlayerSnapshot;
    _playerSnapshots pushBack _snapshot;
    _scoreboardBaseline set [_uid, getPlayerScores _x];

    _attendance set [_uid, createHashMapFromArray [
        ["name_at_start", (_snapshot getOrDefault ["name", ""])],
        ["side_at_start", (_snapshot getOrDefault ["side", ""])],
        ["group_at_start", (_snapshot getOrDefault ["group", ""])],
        ["role_at_start", (_snapshot getOrDefault ["role", ""])],
        ["first_seen_server_time", serverTime],
        ["last_snapshot", _snapshot],
        ["joined_after_start", false],
        ["disconnect_count", 0],
        ["reconnect_count", 0]
    ]];
} forEach _players;

private _worldName = worldName;
private _missionName = missionName;
private _localId = format ["%1:%2:%3", _worldName, _missionName, floor serverTime];
private _requestId = format ["main:start:%1", _localId];

private _payload = createHashMapFromArray [
    ["request_id", _requestId],
    ["server_key", "main"],
    ["payload_version", 1],
    ["mission", createHashMapFromArray [
        ["mission_uid", _localId],
        ["mission_name", _missionName],
        ["world_name", _worldName]
    ]],
    ["source", createHashMapFromArray [
        ["addon", "grp9_stats"],
        ["servermod", "grp9_stats_server"],
        ["trigger", "manual_debug_console"]
    ]],
    ["players", _playerSnapshots]
];

private _payloadJson = [_payload] call grp9_stats_fnc_jsonStringify;
private _callExtension = missionNamespace getVariable ["grp9_stats_server_fnc_callExtension", {}];
private _result = ["operation_start", [_payloadJson]] call _callExtension;
private _resultBody = if (_result isEqualType []) then {_result param [0, ""]} else {_result};
private _backendOperationId = "";

if (_resultBody isEqualType "") then {
    private _parsed = fromJSON _resultBody;
    if (_parsed isEqualType createHashMap) then {
        _backendOperationId = _parsed getOrDefault ["operation_id", ""];
    };
};

if (_backendOperationId isEqualTo "") exitWith {
    diag_log format ["[grp9_stats] Manual operation start failed. local_id=%1 result=%2", _localId, _result];
    _result
};

missionNamespace setVariable ["grp9_stats_operationActive", true];
missionNamespace setVariable ["grp9_stats_operationId", _backendOperationId];
missionNamespace setVariable ["grp9_stats_operationLocalId", _localId];
missionNamespace setVariable ["grp9_stats_operationStartedAtTick", diag_tickTime];
missionNamespace setVariable ["grp9_stats_attendance", _attendance];
missionNamespace setVariable ["grp9_stats_scoreboardBaseline", _scoreboardBaseline];

diag_log format ["[grp9_stats] Manual operation start submitted. local_id=%1 players=%2 result=%3", _localId, count _players, _result];
_result
