-module(mond_unknown_helpers).
-export([
    from/1,
    run/2,
    string/0,
    int/0,
    float/0,
    bool/0,
    bit_array/0,
    dynamic/0,
    list/1,
    field/2,
    one_of/2,
    identity/1
]).

from(Value) ->
    Value.

run(Data, Decoder) ->
    Decoder(Data).

identity(X) -> X.

string() ->
    fun(Data) when is_binary(Data) ->
        {ok, Data};
       (Data) ->
        {error, [decode_error(<<"String">>, Data)]}
    end.

int() ->
    fun(Data) when is_integer(Data) ->
        {ok, Data};
       (Data) ->
        {error, [decode_error(<<"Int">>, Data)]}
    end.

float() ->
    fun(Data) when is_float(Data) ->
        {ok, Data};
       (Data) ->
        {error, [decode_error(<<"Float">>, Data)]}
    end.

bool() ->
    fun(true) ->
        {ok, true};
       (false) ->
        {ok, false};
       (Data) ->
        {error, [decode_error(<<"Bool">>, Data)]}
    end.

bit_array() ->
    fun(Data) when is_bitstring(Data) ->
        {ok, Data};
       (Data) ->
        {error, [decode_error(<<"BitArray">>, Data)]}
    end.

dynamic() ->
    fun(Data) ->
        {ok, Data}
    end.

list(ItemDecoder) ->
    fun(Data) when is_list(Data) ->
        decode_list(Data, ItemDecoder, []);
       (Data) ->
        {error, [decode_error(<<"List">>, Data)]}
    end.

field(Key, ValueDecoder) ->
    fun(Data) ->
        case field_value(Data, Key) of
            {ok, Value} ->
                ValueDecoder(Value);
            missing ->
                {error, [{decodeerror, <<"Field">>, <<"Nothing">>}]};
            bad_type ->
                {error, [decode_error(<<"Map">>, Data)]}
        end
    end.

one_of(Primary, Others) ->
    fun(Data) ->
        case Primary(Data) of
            {ok, Value} ->
                {ok, Value};
            {error, Errors} ->
                try_decoders(Data, Others, Errors)
        end
    end.

try_decoders(_Data, [], Errors) ->
    {error, Errors};
try_decoders(Data, [Decoder | Rest], Errors) ->
    case Decoder(Data) of
        {ok, Value} ->
            {ok, Value};
        {error, NextErrors} ->
            try_decoders(Data, Rest, Errors ++ NextErrors)
    end.

field_value(Data, Key) when is_map(Data) ->
    case maps:find(Key, Data) of
        {ok, Value} -> {ok, Value};
        error -> missing
    end;
field_value(Data, Key) when is_tuple(Data), is_integer(Key), Key >= 0 ->
    Size = tuple_size(Data),
    case Key < Size of
        true -> {ok, element(Key + 1, Data)};
        false -> missing
    end;
field_value(Data, Key) when is_list(Data), is_integer(Key), Key >= 0 ->
    case nth(Key, Data) of
        {ok, Value} -> {ok, Value};
        error -> missing
    end;
field_value(_Data, _Key) ->
    bad_type.

nth(0, [Value | _]) ->
    {ok, Value};
nth(N, [_ | Rest]) when N > 0 ->
    nth(N - 1, Rest);
nth(_, []) ->
    error.

decode_list([], _ItemDecoder, Acc) ->
    {ok, lists:reverse(Acc)};
decode_list([Item | Rest], ItemDecoder, Acc) ->
    case ItemDecoder(Item) of
        {ok, Decoded} ->
            decode_list(Rest, ItemDecoder, [Decoded | Acc]);
        {error, Errors} ->
            {error, Errors}
    end.

decode_error(Expected, Data) ->
    {decodeerror, Expected, classify(Data)}.

classify(true) ->
    <<"Bool">>;
classify(false) ->
    <<"Bool">>;
classify(unit) ->
    <<"Unit">>;
classify(Data) when is_integer(Data) ->
    <<"Int">>;
classify(Data) when is_float(Data) ->
    <<"Float">>;
classify(Data) when is_binary(Data) ->
    <<"String">>;
classify(Data) when is_list(Data) ->
    <<"List">>;
classify(Data) when is_map(Data) ->
    <<"Map">>;
classify(Data) when is_tuple(Data) ->
    <<"Tuple">>;
classify(Data) when is_pid(Data) ->
    <<"Pid">>;
classify(Data) when is_function(Data) ->
    <<"Function">>;
classify(_Data) ->
    <<"Unknown">>.
