-module(mond_process_helpers).

-export([
    spawn/1,
    spawn_unlinked/1,
    new_subject/0,
    named_subject/1,
    new_name/1,
    register_process/2,
    unregister_process/1,
    send/2,
    perform_receive/2,
    receive_timeout/2,
    perform_receive_forever/1,
    selector_receive/2,
    selector_receive_forever/1,
    select_map/3,
    deselect/2,
    select_record/4,
    select_other/2,
    map_selector/2,
    merge_selector/2,
    select_trapped_exits/2,
    select_specific_monitor/3,
    deselect_specific_monitor/2,
    select_monitors/2,
    flush_messages/0,
    sleep_forever/0,
    link/1,
    demonitor_process/1,
    send_after/3,
    cancel_timer/1,
    trap_exits/1,
    cast_exit_reason/1,
    cast_down_message/1,
    process_named/1,
    new_selector/0
]).

new_selector() ->
    {selector, #{}}.

spawn(F) ->
    proc_lib:spawn_link(fun() -> F(unit) end).

spawn_unlinked(F) ->
    proc_lib:spawn(fun() -> F(unit) end).

new_subject() ->
    {subject, {subjectpayload, self(), make_ref()}}.

named_subject(Name) ->
    {namedsubject, Name}.

new_name(Name) when is_binary(Name) ->
    {name, Name, make_ref()}.

register_process(Pid, {name, _Name, _Tag}) when not is_pid(Pid) ->
    {error, invalidpid};
register_process(Pid, Name = {name, _Name, _Tag}) ->
    case is_process_alive(Pid) of
        false ->
            {error, processnotalive};
        true ->
            NameKey = name_key(Name),
            try global:register_name(NameKey, Pid) of
                yes ->
                    {ok, unit};
                no ->
                    {error, namealreadyregistered}
            catch
                Class:Reason ->
                    erlang_error(Class, Reason)
            end
    end;
register_process(_, _) ->
    {error, invalidname}.

unregister_process(Name = {name, _Name, _Tag}) ->
    NameKey = name_key(Name),
    try global:whereis_name(NameKey) of
        _Pid when is_pid(_Pid) ->
            global:unregister_name(NameKey),
            {ok, unit};
        undefined ->
            {error, namenotregistered}
    catch
        Class:Reason ->
            erlang_error(Class, Reason)
    end;
unregister_process(_) ->
    {error, invalidname}.

send(Subject, Msg) ->
    case subject_target(Subject) of
        {ok, {Pid, Tag}} ->
            try
                Pid ! {Tag, Msg},
                {ok, unit}
            catch
                Class:Reason ->
                    erlang_error(Class, Reason)
            end;
        {error, Reason} ->
            {error, Reason}
    end.

perform_receive(Subject, TimeoutMs) when is_integer(TimeoutMs), TimeoutMs >= 0 ->
    case ensure_owner(Subject) of
        ok ->
            Tag = subject_tag(Subject),
            receive
                {Tag, Msg} -> {ok, Msg}
            after TimeoutMs ->
                {error, timeout}
            end;
        {error, Reason} ->
            {error, Reason}
    end;
perform_receive(_, _) ->
    {error, invalidtimeout}.

receive_timeout(Subject, TimeoutMs) ->
    perform_receive(Subject, TimeoutMs).

perform_receive_forever(Subject) ->
    case ensure_owner(Subject) of
        ok ->
            Tag = subject_tag(Subject),
            receive
                {Tag, Msg} -> {ok, Msg}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

selector_receive(Selector, TimeoutMs) when is_integer(TimeoutMs), TimeoutMs >= 0 ->
    Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
    selector_receive_until(Selector, Deadline, []);
selector_receive(_, _) ->
    {error, invalidtimeout}.

selector_receive_forever(Selector) ->
    selector_receive_forever_loop(Selector, []).

select_map({selector, Handlers}, Subject, Transform) ->
    Key = subject_selector_key(Subject),
    Handler = fun({_Tag, Payload}) -> Transform(Payload) end,
    {selector, maps:put(Key, Handler, Handlers)}.

deselect({selector, Handlers}, Subject) ->
    Key = subject_selector_key(Subject),
    {selector, maps:remove(Key, Handlers)}.

select_record({selector, Handlers}, Tag, Arity, Transform) ->
    Key = {tuple, Tag, Arity + 1},
    Handler = fun(Msg) -> Transform(Msg) end,
    {selector, maps:put(Key, Handler, Handlers)}.

select_other({selector, Handlers}, Handler) ->
    {selector, maps:put(anything, Handler, Handlers)}.

map_selector({selector, Handlers}, Mapper) ->
    Mapped = maps:map(
        fun(_Key, Handler) ->
            fun(Msg) -> Mapper(Handler(Msg)) end
        end,
        Handlers
    ),
    {selector, Mapped}.

merge_selector({selector, A}, {selector, B}) ->
    {selector, maps:merge(A, B)}.

select_trapped_exits({selector, Handlers}, Handler) ->
    Key = {tuple, 'EXIT', 3},
    Wrapped = fun({'EXIT', Pid, Reason}) ->
        Handler({exitmessage, Pid, cast_exit_reason(Reason)})
    end,
    {selector, maps:put(Key, Wrapped, Handlers)}.

select_specific_monitor({selector, Handlers}, Monitor, Handler) ->
    Key = {monitor, Monitor},
    Wrapped = fun(Msg) -> Handler(cast_down_message(Msg)) end,
    {selector, maps:put(Key, Wrapped, Handlers)}.

deselect_specific_monitor({selector, Handlers}, Monitor) ->
    Key = {monitor, Monitor},
    {selector, maps:remove(Key, Handlers)}.

select_monitors({selector, Handlers}, Handler) ->
    Key = {tuple, 'DOWN', 5},
    Wrapped = fun(Msg) -> Handler(cast_down_message(Msg)) end,
    {selector, maps:put(Key, Wrapped, Handlers)}.

flush_messages() ->
    receive
        _ -> flush_messages()
    after 0 ->
        unit
    end.

sleep_forever() ->
    receive
    after infinity ->
        ok
    end,
    unit.

link(Pid) when is_pid(Pid) ->
    case is_process_alive(Pid) of
        true ->
            erlang:link(Pid),
            true;
        false ->
            false
    end;
link(_) ->
    false.

demonitor_process(Monitor) ->
    erlang:demonitor(Monitor),
    unit.

send_after(Subject, DelayMs, Msg) when is_integer(DelayMs), DelayMs >= 0 ->
    case subject_target(Subject) of
        {ok, {Pid, Tag}} ->
            try
                {ok, erlang:send_after(DelayMs, Pid, {Tag, Msg})}
            catch
                Class:Reason ->
                    erlang_error(Class, Reason)
            end;
        {error, Reason} ->
            {error, Reason}
    end;
send_after(_, _, _) ->
    {error, invaliddelay}.

cancel_timer(Timer) ->
    case erlang:cancel_timer(Timer) of
        false -> timernotfound;
        Remaining when is_integer(Remaining) -> {cancelled, Remaining}
    end.

trap_exits(Bool) when is_boolean(Bool) ->
    process_flag(trap_exit, Bool),
    unit.

subject_target({subject, {subjectpayload, Owner, Tag}}) ->
    {ok, {Owner, Tag}};
subject_target({namedsubject, Name = {name, _Name, Tag}}) ->
    case process_named(Name) of
        {ok, Pid} ->
            {ok, {Pid, Tag}};
        {error, Reason} ->
            {error, Reason}
    end;
subject_target(_) ->
    {error, invalidsubject}.

subject_tag({subject, {subjectpayload, _Owner, Tag}}) ->
    Tag;
subject_tag({namedsubject, {name, _Name, Tag}}) ->
    Tag.

ensure_owner({subject, {subjectpayload, Owner, _Tag}}) ->
    case Owner =:= self() of
        true -> ok;
        false -> {error, notsubjectowner}
    end;
ensure_owner({namedsubject, _Name}) ->
    ok;
ensure_owner(_) ->
    {error, invalidsubject}.

selector_receive_until(Selector, DeadlineMs, Skipped) ->
    RemainingMs = DeadlineMs - erlang:monotonic_time(millisecond),
    if
        RemainingMs =< 0 ->
            replay_skipped(Skipped),
            {error, timeout};
        true ->
            receive
                Msg ->
                    case dispatch_selector(Selector, Msg) of
                        {ok, Payload} ->
                            replay_skipped(Skipped),
                            {ok, Payload};
                        nomatch ->
                            selector_receive_until(Selector, DeadlineMs, [Msg | Skipped])
                    end
            after RemainingMs ->
                replay_skipped(Skipped),
                {error, timeout}
            end
    end.

selector_receive_forever_loop(Selector, Skipped) ->
    receive
        Msg ->
            case dispatch_selector(Selector, Msg) of
                {ok, Payload} ->
                    replay_skipped(Skipped),
                    Payload;
                nomatch ->
                    selector_receive_forever_loop(Selector, [Msg | Skipped])
            end
    end.

dispatch_selector({selector, Handlers}, Msg) ->
    case monitor_dispatch_key(Msg) of
        none ->
            dispatch_selector_key(Handlers, selector_message_key(Msg), Msg);
        MonitorKey ->
            case maps:find(MonitorKey, Handlers) of
                {ok, Handler} ->
                    {ok, Handler(Msg)};
                error ->
                    dispatch_selector_key(Handlers, selector_message_key(Msg), Msg)
            end
    end.

dispatch_selector_key(Handlers, no_tuple, Msg) ->
    case maps:find(anything, Handlers) of
        {ok, Handler} -> {ok, Handler(Msg)};
        error -> nomatch
    end;
dispatch_selector_key(Handlers, Key, Msg) ->
    case maps:find(Key, Handlers) of
        {ok, Handler} ->
            {ok, Handler(Msg)};
        error ->
            case maps:find(anything, Handlers) of
                {ok, CatchAll} -> {ok, CatchAll(Msg)};
                error -> nomatch
            end
    end.

monitor_dispatch_key({'DOWN', Monitor, _Kind, _Obj, _Reason}) ->
    {monitor, Monitor};
monitor_dispatch_key(_) ->
    none.

selector_message_key(Msg) when is_tuple(Msg), tuple_size(Msg) >= 1 ->
    {tuple, element(1, Msg), tuple_size(Msg)};
selector_message_key(_) ->
    no_tuple.

subject_selector_key({subject, {subjectpayload, _Owner, Tag}}) ->
    {tuple, Tag, 2};
subject_selector_key({namedsubject, {name, _Name, Tag}}) ->
    {tuple, Tag, 2}.

replay_skipped(Skipped) ->
    lists:foreach(fun(Msg) -> self() ! Msg end, lists:reverse(Skipped)),
    ok.

cast_exit_reason(normal) ->
    normal;
cast_exit_reason(killed) ->
    killed;
cast_exit_reason(kill) ->
    killed;
cast_exit_reason(Reason) ->
    {abnormal, Reason}.

cast_down_message({'DOWN', Monitor, process, Pid, Reason}) ->
    {processdown, {processdownpayload, Monitor, Pid, cast_exit_reason(Reason)}};
cast_down_message({'DOWN', Monitor, port, Port, Reason}) ->
    {portdown, {portdownpayload, Monitor, Port, cast_exit_reason(Reason)}}.

name_key({name, Name, Tag}) ->
    {mond_name, Name, Tag}.

process_named({name, Name, Tag}) ->
    try global:whereis_name({mond_name, Name, Tag}) of
        Pid when is_pid(Pid) ->
            {ok, Pid};
        undefined ->
            {error, namenotregistered}
    catch
        Class:Reason ->
            erlang_error(Class, Reason)
    end;
process_named(_) ->
    {error, invalidname}.

erlang_error(Class, Reason) ->
    {error, {erlangerror, {erlangerrorpayload, error_class_to_binary(Class), Reason}}}.

error_class_to_binary(Class) when is_atom(Class) ->
    erlang:atom_to_binary(Class, utf8);
error_class_to_binary(Class) ->
    iolist_to_binary(io_lib:format("~p", [Class])).
