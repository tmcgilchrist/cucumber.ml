(* Expose classic builder API at top level *)
include Lib

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
module Gherkin_parser = Gherkin_parser
module Lex = Lex
module Parser = Parser
module Step_registry = Step_registry
module Effects = Effects
