(** Parser implementation using the gherkin-c library and ctypes.

    This module implements the {!Cucumber.Gherkin_parser_intf.PARSER} interface
    and can be passed to {!Cucumber.Make} to create a Cucumber instance that
    uses the C-based parser instead of the pure OCaml parser.
*)
module Parser : Cucumber.Gherkin_parser_intf.PARSER
