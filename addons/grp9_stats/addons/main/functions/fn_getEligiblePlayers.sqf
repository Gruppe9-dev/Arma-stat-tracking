if (!isServer) exitWith {[]};

private _headlessClients = if (isNil "headlessClients") then {[]} else {headlessClients};

allPlayers select {
    private _uid = getPlayerUID _x;
    private _type = typeOf _x;
    !isNull _x &&
    {isPlayer _x} &&
    {!(_x in _headlessClients)} &&
    {(_uid select [0, 2]) isNotEqualTo "HC"} &&
    {_type isNotEqualTo "HeadlessClient_F"} &&
    {_uid isNotEqualTo ""}
}
