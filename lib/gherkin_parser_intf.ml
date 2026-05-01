open Gherkin_ast

module type PARSER = sig
  exception Parse_error of string * position option

  val parse_file : string -> feature
  val parse_string : string -> feature
  val detect_language : string -> string
end
