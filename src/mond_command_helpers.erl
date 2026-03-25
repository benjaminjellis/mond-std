-module(mond_command_helpers).

-export([run/2]).

run(Command, _Args) when not is_binary(Command) ->
    {error, invalidcommand};
run(Command, _Args) when byte_size(Command) =:= 0 ->
    {error, invalidcommand};
run(_Command, Args) when not is_list(Args) ->
    {error, invalidarguments};
run(Command, Args) ->
    case validate_args(Args) of
        {ok, ErlArgs} ->
            case os:find_executable(unicode:characters_to_list(Command)) of
                false ->
                    {error, commandnotfound};
                Executable ->
                    try
                        Port = open_port(
                            {spawn_executable, Executable},
                            [binary, exit_status, use_stdio, hide, stderr_to_stdout, {args, ErlArgs}]
                        ),
                        collect_port_output(Port, [])
                    catch
                        Class:Reason ->
                            erlang_error(Class, Reason)
                    end
            end;
        {error, _} = Error ->
            Error
    end.

validate_args([]) ->
    {ok, []};
validate_args([Arg | Rest]) when is_binary(Arg) ->
    case validate_args(Rest) of
        {ok, ConvertedRest} ->
            {ok, [unicode:characters_to_list(Arg) | ConvertedRest]};
        Error ->
            Error
    end;
validate_args(_) ->
    {error, invalidarguments}.

collect_port_output(Port, Chunks) ->
    receive
        {Port, {data, Data}} ->
            collect_port_output(Port, [Data | Chunks]);
        {Port, {exit_status, Status}} ->
            render_output(Status, Chunks);
        {Port, closed} ->
            collect_port_output(Port, Chunks);
        {'EXIT', Port, Reason} ->
            {error, {unknown, reason_to_binary(Reason)}}
    end.

render_output(Status, Chunks) ->
    OutputBin = iolist_to_binary(lists:reverse(Chunks)),
    case unicode:characters_to_binary(OutputBin, utf8, utf8) of
        Utf8 when is_binary(Utf8) ->
            {ok, {commandresult, Status, Utf8}};
        _ ->
            {error, outputnotutf8}
    end.

erlang_error(Class, Reason) ->
    {error, {unknown, reason_to_binary({Class, Reason})}}.

reason_to_binary(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
