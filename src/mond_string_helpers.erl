-module(mond_string_helpers).
-export([contains/2, concat/2, split/2, string_ends_with/2, slice/3, to_graphemes/1]).

contains(Haystack, Needle) ->
    string:find(Haystack, Needle) =/= nomatch.

concat(A, B) -> <<A/binary, B/binary>>.

split(Str, Sep) -> string:split(Str, Sep, all).

string_ends_with(_, <<>>) -> true;
string_ends_with(String, Suffix) when byte_size(Suffix) > byte_size(String) -> false;
string_ends_with(String, Suffix) ->
    SuffixSize = byte_size(Suffix),
    Suffix == binary_part(String, byte_size(String) - SuffixSize, SuffixSize).

slice(String, Index, Length) ->
    case string:slice(String, Index, Length) of
        X when is_binary(X) -> X;
        X when is_list(X) -> unicode:characters_to_binary(X)
    end.

to_graphemes(Str) ->
    [grapheme_to_binary(G) || G <- string:to_graphemes(Str)].

grapheme_to_binary(G) when is_binary(G) ->
    G;
grapheme_to_binary(G) when is_integer(G) ->
    <<G/utf8>>;
grapheme_to_binary(G) when is_list(G) ->
    unicode:characters_to_binary(G).
