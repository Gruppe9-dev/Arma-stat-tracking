if (!isServer) exitWith {[]};

private _baseline = missionNamespace getVariable ["grp9_stats_scoreboardBaseline", createHashMap];
private _players = call grp9_stats_fnc_getEligiblePlayers;
private _stats = [];

{
    private _uid = getPlayerUID _x;
    private _latest = getPlayerScores _x;
    private _start = _baseline getOrDefault [_uid, []];

    private _delta = [];
    {
        private _index = _forEachIndex;
        private _startValue = if (_index < count _start) then {_start select _index} else {0};
        _delta pushBack (_x - _startValue);
    } forEach _latest;

    private _stat = createHashMapFromArray [
        ["player_uid", _uid],
        ["infantry_kills", _delta param [0, 0]],
        ["soft_vehicle_kills", _delta param [1, 0]],
        ["armor_kills", _delta param [2, 0]],
        ["air_kills", _delta param [3, 0]],
        ["deaths", _delta param [4, 0]],
        ["score", _delta param [5, 0]],
        ["raw_scoreboard_baseline", _start],
        ["raw_scoreboard_latest", _latest]
    ];

    _stats pushBack _stat;
} forEach _players;

_stats
