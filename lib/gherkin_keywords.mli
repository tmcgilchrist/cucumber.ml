(** Gherkin keyword definitions for i18n support *)

type keyword_set = {
  feature : string list;
  background : string list;
  rule : string list;
  scenario : string list;
  scenario_outline : string list;
  examples : string list;
  given : string list;
  when_ : string list;
  then_ : string list;
  and_ : string list;
  but : string list;
}

val get_keywords : string -> keyword_set option
(** Get keywords for a language code (e.g., "en", "fr", "de") *)

val english : keyword_set
(** Get English keywords (default) *)

val matches_keyword : string -> string list -> bool
(** Check if a word matches any keyword in a list *)

val is_feature : string -> string -> bool
(** Check if a word is a feature keyword in the given language *)

val is_scenario : string -> string -> bool
(** Check if a word is a scenario keyword in the given language *)

val is_step : string -> string -> bool
(** Check if a word is a step keyword in the given language *)

val supported_languages : unit -> string list
(** Get all supported language codes *)
