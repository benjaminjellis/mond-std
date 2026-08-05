-module(mond_atom_helpers).
-export([to_string/1]).

to_string(Atom) when is_atom(Atom) ->
    atom_to_binary(Atom, utf8).
