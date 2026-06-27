if (!isServer) exitWith {
    diag_log "[grp9_stats] finishOperation ignored because it was not executed on the server.";
    false
};

if !(missionNamespace getVariable ["grp9_stats_operationActive", false]) exitWith {
    diag_log "[grp9_stats] finishOperation ignored because no operation is active.";
    false
};

if (isNil "grp9_stats_server_fnc_callExtension") exitWith {
    diag_log "[grp9_stats] finishOperation failed because @grp9_stats_server is not loaded.";
    false
};

private _players = call grp9_stats_fnc_getEligiblePlayers;
private _playerSnapshots = _players apply {[_x] call grp9_stats_fnc_buildPlayerSnapshot};
private _attendanceRecords = call grp9_stats_fnc_buildAttendanceRecords;
private _scoreboardStats = call grp9_stats_fnc_buildScoreboardStats;
private _operationId = missionNamespace getVariable ["grp9_stats_operationId", ""];
private _localId = missionNamespace getVariable ["grp9_stats_operationLocalId", ""];
private _requestId = format ["main:finish:%1", _localId];

private _payload = createHashMapFromArray [
    ["request_id", _requestId],
    ["server_key", "main"],
    ["payload_version", 1],
    ["outcome", "completed"],
    ["players", _playerSnapshots],
    ["attendance_records", _attendanceRecords],
    ["scoreboard_stats", _scoreboardStats]
];

private _payloadJson = [_payload] call grp9_stats_fnc_jsonStringify;
private _callExtension = missionNamespace getVariable ["grp9_stats_server_fnc_callExtension", {}];
private _result = ["operation_finish", [_operationId, _payloadJson]] call _callExtension;
private _resultBody = if (_result isEqualType []) then {_result param [0, ""]} else {_result};
private _finished = false;

if (_resultBody isEqualType "") then {
    private _parsed = fromJSON _resultBody;
    if (_parsed isEqualType createHashMap) then {
        _finished = (_parsed getOrDefault ["status", ""]) isEqualTo "finished";
    };
};

if (_finished) then {
    missionNamespace setVariable ["grp9_stats_operationActive", false];
    missionNamespace setVariable ["grp9_stats_operationId", ""];
    missionNamespace setVariable ["grp9_stats_operationLocalId", ""];
} else {
    diag_log format [
        "[grp9_stats] Manual operation finish did not close local state because backend did not confirm finish. operation_id=%1 local_id=%2 result=%3",
        _operationId,
        _localId,
        _result
    ];
};

diag_log format [
    "[grp9_stats] Manual operation finish submitted. operation_id=%1 local_id=%2 players=%3 result=%4",
    _operationId,
    _localId,
    count _players,
    _result
];

_result
