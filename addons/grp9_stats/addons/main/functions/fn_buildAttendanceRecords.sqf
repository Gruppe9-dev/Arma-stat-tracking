if (!isServer) exitWith {[]};

private _attendance = missionNamespace getVariable ["grp9_stats_attendance", createHashMap];
private _players = call grp9_stats_fnc_getEligiblePlayers;
private _currentByUid = createHashMap;

{
    _currentByUid set [getPlayerUID _x, _x];
} forEach _players;

private _records = [];

{
    private _uid = _x;
    private _record = _y;
    private _unit = _currentByUid getOrDefault [_uid, objNull];
    private _presentAtEnd = !isNull _unit;
    private _latestSnapshot = if (_presentAtEnd) then {
        [_unit] call grp9_stats_fnc_buildPlayerSnapshot
    } else {
        _record getOrDefault ["last_snapshot", createHashMap]
    };

    private _attendedSeconds = serverTime - (_record getOrDefault ["first_seen_server_time", serverTime]);
    if (_attendedSeconds < 0) then {
        _attendedSeconds = 0;
    };

    private _attendanceRecord = createHashMapFromArray [
        ["player_uid", _uid],
        ["name_at_start", (_record getOrDefault ["name_at_start", ""])],
        ["name_at_end", (_latestSnapshot getOrDefault ["name", ""])],
        ["side_at_start", (_record getOrDefault ["side_at_start", ""])],
        ["side_at_end", (_latestSnapshot getOrDefault ["side", ""])],
        ["group_at_start", (_record getOrDefault ["group_at_start", ""])],
        ["group_at_end", (_latestSnapshot getOrDefault ["group", ""])],
        ["role_at_start", (_record getOrDefault ["role_at_start", ""])],
        ["role_at_end", (_latestSnapshot getOrDefault ["role", ""])],
        ["joined_after_start", (_record getOrDefault ["joined_after_start", false])],
        ["disconnect_count", (_record getOrDefault ["disconnect_count", 0])],
        ["reconnect_count", (_record getOrDefault ["reconnect_count", 0])],
        ["attended_seconds", floor _attendedSeconds],
        ["missed_seconds", 0],
        ["attendance_ratio", 1]
    ];

    _records pushBack _attendanceRecord;
} forEach _attendance;

_records
