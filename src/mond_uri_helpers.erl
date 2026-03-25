-module(mond_uri_helpers).
-export([parse_uri/1]).

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
