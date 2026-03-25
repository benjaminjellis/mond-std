-module(mond_list_helpers).
-export([foldl/3, foldr/3, nth/2, prepend/2, pop_first/2, replace_first/3, upsert_first/3, flat_map/2, filter_map/2]).

%% Adapt Mond's curried fun(X) -> fun(Acc) -> ... end
%% to the 2-arity fun(X, Acc) -> ... end that lists:foldl/foldr expect.

foldl(Fun, Acc0, List) ->
    lists:foldl(fun(X, Acc) -> (Fun(X))(Acc) end, Acc0, List).

foldr(Fun, Acc0, List) ->
    lists:foldr(fun(X, Acc) -> (Fun(X))(Acc) end, Acc0, List).

nth(N, List) when is_integer(N), N >= 0 ->
    case catch lists:nth(N + 1, List) of
        {'EXIT', _} -> none;
        Value -> {some, Value}
    end;
nth(_, _) ->
    none.

prepend(Item, List) ->
    [Item | List].

pop_first(Predicate, List) ->
    pop_first_loop(Predicate, List, []).

pop_first_loop(_, [], AccRev) ->
    {pair, none, lists:reverse(AccRev)};
pop_first_loop(Predicate, [Item | Rest], AccRev) ->
    case Predicate(Item) of
        true ->
            {pair, {some, Item}, lists:append(lists:reverse(AccRev), Rest)};
        false ->
            pop_first_loop(Predicate, Rest, [Item | AccRev])
    end.

replace_first(Predicate, Replacement, List) ->
    replace_first_loop(Predicate, Replacement, List, []).

replace_first_loop(_, _, [], AccRev) ->
    lists:reverse(AccRev);
replace_first_loop(Predicate, Replacement, [Item | Rest], AccRev) ->
    case Predicate(Item) of
        true ->
            lists:append(lists:reverse(AccRev), [Replacement | Rest]);
        false ->
            replace_first_loop(Predicate, Replacement, Rest, [Item | AccRev])
    end.

upsert_first(Predicate, Replacement, List) ->
    upsert_first_loop(Predicate, Replacement, List, []).

upsert_first_loop(_, Replacement, [], AccRev) ->
    lists:reverse([Replacement | AccRev]);
upsert_first_loop(Predicate, Replacement, [Item | Rest], AccRev) ->
    case Predicate(Item) of
        true ->
            lists:append(lists:reverse(AccRev), [Replacement | Rest]);
        false ->
            upsert_first_loop(Predicate, Replacement, Rest, [Item | AccRev])
    end.

flat_map(Fun, List) ->
    lists:flatmap(Fun, List).

filter_map(Fun, List) ->
    lists:reverse(filter_map_loop(Fun, List, [])).

filter_map_loop(_, [], AccRev) ->
    AccRev;
filter_map_loop(Fun, [Item | Rest], AccRev) ->
    case Fun(Item) of
        {ok, Value} ->
            filter_map_loop(Fun, Rest, [Value | AccRev]);
        {error, _} ->
            filter_map_loop(Fun, Rest, AccRev)
    end.
