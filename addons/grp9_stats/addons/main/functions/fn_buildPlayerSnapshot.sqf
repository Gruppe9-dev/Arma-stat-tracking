params ["_unit"];

private _group = group _unit;
private _role = roleDescription _unit;
if (_role isEqualTo "") then {
    _role = typeOf _unit;
};

createHashMapFromArray [
    ["player_uid", getPlayerUID _unit],
    ["name", name _unit],
    ["side", str side _unit],
    ["group", groupId _group],
    ["role", _role],
    ["owner", owner _unit]
]
