params ["_command", ["_args", []]];

if (!isServer) exitWith {[false, "not_server"]};
if !(_command isEqualType "") exitWith {[false, "invalid_command"]};
if (_args isEqualType "") then {
    _args = [_args];
};
if !(_args isEqualType []) exitWith {[false, "invalid_args"]};

private _result = "grp9_stats_ext" callExtension [_command, _args];
if (_result isEqualType [] && {count _result > 0}) exitWith {
    _result select 0
};

_result
