-module(mond_bytes_tree_helpers).
-export([identity/1, concat/1, to_bit_array/1]).

identity(Value) ->
    Value.

concat(Trees) ->
    iolist_to_binary(Trees).

to_bit_array(Tree) ->
    iolist_to_binary(Tree).
