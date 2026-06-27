params ["_value"];

if (isNil "_value") exitWith {"null"};

if (_value isEqualType "") exitWith {
    private _backslash = toString [92];
    private _quote = toString [34];
    private _escaped = "";

    {
        switch (_x) do {
            case 8: {
                _escaped = _escaped + _backslash + "b";
            };
            case 9: {
                _escaped = _escaped + _backslash + "t";
            };
            case 10: {
                _escaped = _escaped + _backslash + "n";
            };
            case 12: {
                _escaped = _escaped + _backslash + "f";
            };
            case 13: {
                _escaped = _escaped + _backslash + "r";
            };
            case 34: {
                _escaped = _escaped + _backslash + _quote;
            };
            case 92: {
                _escaped = _escaped + _backslash + _backslash;
            };
            default {
                if (_x < 32) then {
                    private _hex = "0123456789abcdef";
                    private _high = floor (_x / 16);
                    private _low = _x mod 16;
                    _escaped = _escaped + format ["%1u00%2%3", _backslash, _hex select [_high, 1], _hex select [_low, 1]];
                } else {
                    _escaped = _escaped + toString [_x];
                };
            };
        };
    } forEach toArray _value;

    _quote + _escaped + _quote
};

if (_value isEqualType true) exitWith {
    ["false", "true"] select _value
};

if (_value isEqualType 0) exitWith {
    str _value
};

if (_value isEqualType []) exitWith {
    private _items = _value apply {[_x] call grp9_stats_fnc_jsonStringify};
    "[" + (_items joinString ",") + "]"
};

if (_value isEqualType createHashMap) exitWith {
    private _pairs = [];

    {
        private _key = if (_x isEqualType "") then {_x} else {str _x};
        private _encodedKey = [_key] call grp9_stats_fnc_jsonStringify;
        private _encodedValue = [_y] call grp9_stats_fnc_jsonStringify;
        _pairs pushBack (_encodedKey + ":" + _encodedValue);
    } forEach _value;

    "{" + (_pairs joinString ",") + "}"
};

"null"
