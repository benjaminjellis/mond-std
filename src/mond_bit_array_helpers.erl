-module(mond_bit_array_helpers).

-export([
    identity/1,
    pad_to_bytes/1,
    slice/3,
    bit_array_to_string/1,
    concat/1,
    base64_encode/2,
    base64_decode/1,
    base64_url_encode/2,
    base64_url_decode/1,
    base16_encode/1,
    base16_decode/1,
    inspect/1,
    compare/2,
    bit_array_to_int_and_size/1,
    starts_with/2
]).

identity(Value) ->
    Value.

pad_to_bytes(Bits) when is_bitstring(Bits) ->
    case bit_size(Bits) rem 8 of
        0 ->
            Bits;
        Rem ->
            Padding = 8 - Rem,
            <<Bits/bitstring, 0:Padding>>
    end.

slice(Bits, Position, Length)
    when is_bitstring(Bits), is_integer(Position), is_integer(Length) ->
    try
        TotalSize = bit_size(Bits),
        Start = if
            Position < 0 -> TotalSize + Position;
            true -> Position
        end,
        End = if
            Length < 0 -> TotalSize + Length;
            true -> Start + Length
        end,
        if
            Start < 0 ->
                {error, unit};
            End < Start ->
                {error, unit};
            End > TotalSize ->
                {error, unit};
            true ->
                Take = End - Start,
                <<_:Start/bitstring, Out:Take/bitstring, _/bitstring>> = Bits,
                {ok, Out}
        end
    catch
        _:_ ->
            {error, unit}
    end;
slice(_, _, _) ->
    {error, unit}.

bit_array_to_string(Bits) when is_binary(Bits) ->
    try unicode:characters_to_binary(Bits, utf8, utf8) of
        Utf8 when is_binary(Utf8) ->
            {ok, Utf8}
    catch
        _:_ ->
            {error, unit}
    end;
bit_array_to_string(_) ->
    {error, unit}.

concat(BitArrays) when is_list(BitArrays) ->
    lists:foldl(
        fun(Bits, Acc) ->
            <<Acc/bitstring, Bits/bitstring>>
        end,
        <<>>,
        BitArrays
    ).

base64_encode(Input, Padding)
    when is_bitstring(Input), is_boolean(Padding) ->
    Encoded = base64:encode(pad_to_bytes(Input)),
    case Padding of
        true -> Encoded;
        false -> trim_base64_padding(Encoded)
    end.

base64_decode(Encoded) when is_binary(Encoded) ->
    try
        {ok, base64:decode(pad_base64(Encoded))}
    catch
        _:_ ->
            {error, unit}
    end;
base64_decode(_) ->
    {error, unit}.

base64_url_encode(Input, Padding) ->
    Encoded = base64_encode(Input, Padding),
    UrlA = binary:replace(Encoded, <<"+">>, <<"-">>, [global]),
    binary:replace(UrlA, <<"/">>, <<"_">>, [global]).

base64_url_decode(Encoded) when is_binary(Encoded) ->
    StdA = binary:replace(Encoded, <<"-">>, <<"+">>, [global]),
    StdB = binary:replace(StdA, <<"_">>, <<"/">>, [global]),
    base64_decode(StdB);
base64_url_decode(_) ->
    {error, unit}.

base16_encode(Input) when is_bitstring(Input) ->
    Padded = pad_to_bytes(Input),
    <<
        <<(hex_digit(Byte bsr 4)), (hex_digit(Byte band 16#0F))>>
        || <<Byte>> <= Padded
    >>.

base16_decode(Input) when is_binary(Input) ->
    decode_hex(Input, <<>>);
base16_decode(_) ->
    {error, unit}.

decode_hex(<<>>, Acc) ->
    {ok, Acc};
decode_hex(<<_OnlyNibble>>, _Acc) ->
    {error, unit};
decode_hex(<<Hi, Lo, Rest/binary>>, Acc) ->
    case {hex_value(Hi), hex_value(Lo)} of
        {{ok, H}, {ok, L}} ->
            decode_hex(Rest, <<Acc/binary, ((H bsl 4) bor L)>>);
        _ ->
            {error, unit}
    end.

hex_digit(N) when N >= 0, N =< 9 ->
    $0 + N;
hex_digit(N) ->
    $a + (N - 10).

hex_value(C) when C >= $0, C =< $9 ->
    {ok, C - $0};
hex_value(C) when C >= $a, C =< $f ->
    {ok, C - $a + 10};
hex_value(C) when C >= $A, C =< $F ->
    {ok, C - $A + 10};
hex_value(_) ->
    error.

inspect(Input) when is_bitstring(Input) ->
    TotalBits = bit_size(Input),
    FullBytes = TotalBits div 8,
    RemBits = TotalBits rem 8,
    Prefix = <<"<<">>,
    Suffix = <<">>">>,
    BytePart = inspect_bytes(Input, FullBytes),
    case RemBits of
        0 ->
            <<Prefix/binary, BytePart/binary, Suffix/binary>>;
        _ ->
            <<BytePrefix:FullBytes/binary, Tail:RemBits>> = Input,
            TailInt = bits_to_int(Tail),
            TailBin = integer_to_binary(TailInt),
            RemBin = integer_to_binary(RemBits),
            case BytePart of
                <<>> ->
                    <<Prefix/binary, TailBin/binary, ":size(", RemBin/binary, ")", Suffix/binary>>;
                _ ->
                    <<Prefix/binary, BytePart/binary, ", ", TailBin/binary, ":size(", RemBin/binary, ")", Suffix/binary>>
            end
    end.

inspect_bytes(_Bits, 0) ->
    <<>>;
inspect_bytes(Bits, Count) ->
    <<Bytes:Count/binary, _/bitstring>> = Bits,
    inspect_byte_list(binary_to_list(Bytes), <<>>).

inspect_byte_list([], Acc) ->
    Acc;
inspect_byte_list([Byte], Acc) ->
    append_piece(Acc, integer_to_binary(Byte));
inspect_byte_list([Byte | Rest], Acc) ->
    Next = append_piece(Acc, integer_to_binary(Byte)),
    inspect_byte_list(Rest, <<Next/binary, ", ">>).

append_piece(<<>>, Piece) ->
    Piece;
append_piece(Acc, Piece) ->
    <<Acc/binary, Piece/binary>>.

compare(A, B) when is_bitstring(A), is_bitstring(B) ->
    compare_loop(A, B).

compare_loop(<<First, FirstRest/bitstring>>, <<Second, SecondRest/bitstring>>) ->
    if
        First > Second -> gt;
        First < Second -> lt;
        true -> compare_loop(FirstRest, SecondRest)
    end;
compare_loop(<<>>, <<>>) ->
    eq;
compare_loop(_, <<>>) ->
    gt;
compare_loop(<<>>, _) ->
    lt;
compare_loop(First, Second) ->
    {AInt, ASize} = bit_array_to_int_and_size(First),
    {BInt, BSize} = bit_array_to_int_and_size(Second),
    if
        AInt > BInt -> gt;
        AInt < BInt -> lt;
        ASize > BSize -> gt;
        ASize < BSize -> lt;
        true -> eq
    end.

bit_array_to_int_and_size(Bits) when is_bitstring(Bits) ->
    {bits_to_int(Bits), bit_size(Bits)}.

bits_to_int(Bits) ->
    bits_to_int(Bits, 0).

bits_to_int(<<>>, Acc) ->
    Acc;
bits_to_int(<<Bit:1, Rest/bitstring>>, Acc) ->
    bits_to_int(Rest, (Acc bsl 1) bor Bit).

starts_with(Bits, Prefix) when is_bitstring(Bits), is_bitstring(Prefix) ->
    PrefixSize = bit_size(Prefix),
    BitsSize = bit_size(Bits),
    if
        PrefixSize > BitsSize ->
            false;
        true ->
            <<Pref:PrefixSize/bitstring, _/bitstring>> = Bits,
            Pref =:= Prefix
    end.

trim_base64_padding(Encoded) ->
    trim_base64_padding(Encoded, byte_size(Encoded)).

trim_base64_padding(_Encoded, 0) ->
    <<>>;
trim_base64_padding(Encoded, Size) ->
    case binary:last(Encoded) of
        $= ->
            trim_base64_padding(binary:part(Encoded, 0, Size - 1), Size - 1);
        _ ->
            Encoded
    end.

pad_base64(Encoded) ->
    case byte_size(Encoded) rem 4 of
        0 -> Encoded;
        N -> <<Encoded/binary, (padding_equals(4 - N))/binary>>
    end.

padding_equals(0) ->
    <<>>;
padding_equals(N) ->
    <<$=, (padding_equals(N - 1))/binary>>.
