params ["_value"];

private _quote = toString [34];
private _backslash = toString [92];

private _escapeString = {
    params ["_text"];

    private _escaped = _quote;
    {
        _escaped = _escaped + (switch (_x) do {
            case 8: {
                _backslash + "b"
            };
            case 9: {
                _backslash + "t"
            };
            case 10: {
                _backslash + "n"
            };
            case 12: {
                _backslash + "f"
            };
            case 13: {
                _backslash + "r"
            };
            case 34: {
                _backslash + _quote
            };
            case 92: {
                _backslash + _backslash
            };
            default {
                if (_x < 32) then {
                    private _hex = "0123456789abcdef";
                    private _high = floor (_x / 16);
                    private _low = _x mod 16;
                    format ["%1u00%2%3", _backslash, _hex select [_high, 1], _hex select [_low, 1]]
                } else {
                    toString [_x]
                };
            };
        });
    } forEach toArray _text;

    _escaped + _quote
};

switch (typeName _value) do {
    case "STRING": {
        [_value] call _escapeString
    };
    case "BOOL": {
        ["false", "true"] select _value
    };
    case "SCALAR": {
        str _value
    };
    case "ARRAY": {
        private _items = _value apply {[_x] call grp9_stats_fnc_jsonStringify};
        "[" + (_items joinString ",") + "]"
    };
    case "HASHMAP": {
        private _pairs = [];

        {
            private _key = if (_x isEqualType "") then {_x} else {str _x};
            _pairs pushBack (([_key] call _escapeString) + ":" + ([_y] call grp9_stats_fnc_jsonStringify));
        } forEach _value;

        "{" + (_pairs joinString ",") + "}"
    };
    default {
        "null"
    };
}
