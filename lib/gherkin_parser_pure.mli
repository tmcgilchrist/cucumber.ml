(** Pure OCaml implementation of the Gherkin parser.

    This module implements the {!module-type:Gherkin_parser_intf.PARSER} signature
    using a pure OCaml parser built with:
    - {b Menhir}: LR parser generator for OCaml
    - {b sedlex}: Unicode-aware lexer generator
    - {b Re}: Regular expression library for keyword matching

    This is the default parser implementation used by Cucumber.ml. It has several advantages:
    - No C dependencies (easier installation and portability)
    - Better error messages with precise position information
    - Full Unicode support via sedlex
    - Easy to maintain and extend
    - Works on all platforms OCaml supports

    The parser follows the official Gherkin specification and supports:
    - Multiple natural languages (English, French, German, etc.)
    - All Gherkin constructs (Feature, Scenario, Background, Rule, etc.)
    - Data tables and docstrings
    - Tags and examples
    - Position tracking for error reporting *)

include Gherkin_parser_intf.PARSER
