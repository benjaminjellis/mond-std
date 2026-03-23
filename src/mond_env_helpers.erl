-module(mond_env_helpers).

-export([current_os/0]).

current_os() ->
    case os:type() of
        {unix, linux} ->
            linux;
        {unix, darwin} ->
            mac;
        {win32, _} ->
            windows;
        _ ->
            other
    end.
