(** Gherkin parser with environment and state management *)

open Gherkin_ast

type env
(** Parser environment tracks language, keywords, and step context *)

exception Parse_error of string * position option
(** Parse error with position information *)

val create_env : unit -> env
(** Create a new parser environment with default language (English) *)

val create_env_with_lang : string -> env
(** Create a parser environment with specified language *)

val get_language : env -> string
(** Get current language *)

val set_language : env -> string -> unit
(** Set language for the environment *)

val get_keywords : env -> Gherkin_keywords.keyword_set
(** Get keywords for current language *)

val is_keyword :
  env ->
  string ->
  [ `Feature
  | `Background
  | `Rule
  | `Scenario
  | `ScenarioOutline
  | `Examples
  | `Given
  | `When
  | `Then
  | `And
  | `But ] ->
  bool
(** Check if a word is a keyword of a specific type *)

val resolve_step_type : env -> string -> step_type option
(** Get or infer step type based on keyword and context *)

val set_last_step_type : env -> step_type -> unit
(** Set the last step type (for And/But resolution) *)

val clear_last_step_type : env -> unit
(** Clear the last step type *)

val detect_language : string -> string
(** Detect language from content by searching for # language: directive. Returns
    the language code (e.g., "fr", "en") or "en" as default. *)

val parse_string : string -> feature
(** Parse a feature file from a string *)

val parse_file : string -> feature
(** Parse a feature file from a file path *)
