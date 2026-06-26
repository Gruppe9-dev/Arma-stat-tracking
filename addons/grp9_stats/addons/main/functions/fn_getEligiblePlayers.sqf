if (!isServer) exitWith {[]};

allPlayers select {
    private _uid = getPlayerUID _x;
    !isNull _x &&
    {isPlayer _x} &&
    {!(_x in headlessClients)} &&
    {_uid isNotEqualTo ""}
}
