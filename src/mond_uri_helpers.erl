-module(mond_uri_helpers).
-export([parse_uri/1, parse_query/1, percent_encode/1]).

parse_uri(String) ->
    case uri_string:parse(String) of
        {error, _, _} -> {error, unit};
        UriMap ->
            Port =
                case maps:find(port, UriMap) of
                    {ok, undefined} -> none;
                    {ok, Value} -> {some, Value};
                    error -> none
                end,
            {ok, {uri,
                maps_get_optional_lowercase(UriMap, scheme),
                maps_get_optional(UriMap, userinfo),
                maps_get_optional(UriMap, host),
                Port,
                maps_get_or(UriMap, path, <<>>),
                maps_get_optional(UriMap, query),
                maps_get_optional(UriMap, fragment)
            }}
    end.

parse_query(Query) ->
    case uri_string:dissect_query(Query) of
        {error, _, _} -> {error, unit};
        Pairs ->
            {ok, lists:map(fun
                ({K, true}) -> {pair, K, <<"">>};
                ({K, V}) -> {pair, K, V}
            end, Pairs)}
    end.

percent_encode(Bin) ->
    percent_encode(Bin, <<>>).

percent_encode(<<>>, Acc) ->
    Acc;
percent_encode(<<Byte, Rest/binary>>, Acc) ->
    case percent_ok(Byte) of
        true ->
            percent_encode(Rest, <<Acc/binary, Byte>>);
        false ->
            <<Hi:4, Lo:4>> = <<Byte>>,
            percent_encode(
                Rest,
                <<Acc/binary, $%, (dec2hex(Hi)), (dec2hex(Lo))>>
            )
    end.

percent_ok($!) -> true;
percent_ok($$) -> true;
percent_ok($') -> true;
percent_ok($() -> true;
percent_ok($)) -> true;
percent_ok($*) -> true;
percent_ok($+) -> true;
percent_ok($-) -> true;
percent_ok($.) -> true;
percent_ok($_) -> true;
percent_ok($~) -> true;
percent_ok(C) when $0 =< C, C =< $9 -> true;
percent_ok(C) when $A =< C, C =< $Z -> true;
percent_ok(C) when $a =< C, C =< $z -> true;
percent_ok(_) -> false.

dec2hex(X) when X >= 0, X =< 9 -> X + $0;
dec2hex(X) when X >= 10, X =< 15 -> X + $A - 10.

maps_get_optional_lowercase(Map, Key) ->
    case maps:find(Key, Map) of
        {ok, Value} -> {some, string:lowercase(Value)};
        error -> none
    end.

maps_get_optional(Map, Key) ->
    case maps:find(Key, Map) of
        {ok, Value} -> {some, Value};
        error -> none
    end.

maps_get_or(Map, Key, Default) ->
    case maps:find(Key, Map) of
        {ok, Value} -> Value;
        error -> Default
    end.
