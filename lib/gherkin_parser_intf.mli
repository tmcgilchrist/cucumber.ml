(** Parser interface for Gherkin feature files.

    This module defines the signature that all Gherkin parser implementations
    must satisfy. It provides an abstraction layer allowing users to choose
    between different parser backends (pure OCaml, C-based, custom implementations).

    The interface is designed to be:
    - Simple: Just three core operations
    - Consistent: All parsers produce the same AST type
    - Extensible: Third parties can implement custom parsers
    - Type-safe: Module system enforces correctness

    Example implementations:
    - {!Gherkin_parser_pure}: Pure OCaml parser using Menhir and sedlex (default)
    - {!Gherkin_parser_c}: C-based parser using gherkin library

    To use a custom parser with Cucumber:
    {[
      module My_parser : Gherkin_parser_intf.PARSER = struct
        exception Parse_error of string * Gherkin_ast.position option

        let parse_file fname = (* custom implementation *)
        let parse_string content = (* custom implementation *)
        let detect_language content = "en"
      end

      module My_cucumber = Cucumber.Make(My_parser)
    ]}
*)

open Gherkin_ast

(** The signature for a Gherkin parser *)
module type PARSER = sig
  (** Exception raised when parsing fails.

      Contains an error message and optional position information indicating
      where the parse error occurred in the source file. *)
  exception Parse_error of string * position option

  val parse_file : string -> feature
  (** [parse_file filename] parses a Gherkin feature file from the filesystem.

      @param filename Path to the .feature file to parse
      @return A complete {!type:Gherkin_ast.feature} AST
      @raise Parse_error if parsing fails
      @raise Sys_error if file cannot be read *)

  val parse_string : string -> feature
  (** [parse_string content] parses a Gherkin feature from an in-memory string.

      @param content The feature file content as a string
      @return A complete {!type:Gherkin_ast.feature} AST
      @raise Parse_error if parsing fails *)

  val detect_language : string -> string
  (** [detect_language content] detects the language directive from content.

      Searches for a [# language: XX] directive at the start of the content.
      The language code determines which keywords are recognized during parsing.

      @param content The feature file content to analyze
      @return Language code (e.g., "en", "fr", "de") or "en" as default

      Example:
      {[
        # language: fr
        Fonctionnalité: Test
          ...
      ]}

      Would return ["fr"]. *)
end
