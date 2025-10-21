(* Expose classic builder API at top level (using OCaml parser by default) *)
include Lib

(* Expose functor for custom parser implementations *)
module Make = Lib.Make

(* Supporting modules *)
module Location = Location
module Docstring = Docstring
module Table = Table
module Step = Step
module Outcome = Outcome
module Tag = Tag
module Pickle = Pickle
module Report = Report
module Dialect = Dialect
module Gherkin_ast = Gherkin_ast
module Gherkin_keywords = Gherkin_keywords

(* Parser interface and implementations *)
module Gherkin_parser_intf = Gherkin_parser_intf
module Gherkin_parser_pure = Gherkin_parser_pure
module Gherkin_parser = Gherkin_parser_pure

module Lex = Lex
module Parser = Parser
module Step_registry = Step_registry
module Effects = Effects
