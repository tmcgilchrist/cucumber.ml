(** Gherkin keyword definitions for i18n support.

    The per-language keyword tables live in {!Gherkin_keywords_data},
    which is generated at build time from [vendor/gherkin-languages.json]
    by [bin/gen_keywords/gen.ml]. This module just wraps them with the
    matching helpers used by the lexer. *)

include Gherkin_keywords_data

let get_keywords lang =
  try Some (List.assoc lang keyword_table) with Not_found -> None

let matches_keyword word keywords =
  List.exists
    (fun kw ->
      word = kw
      || String.lowercase_ascii word = String.lowercase_ascii kw
      || word = kw ^ ":"
      || String.lowercase_ascii word = String.lowercase_ascii kw ^ ":")
    keywords

let is_feature word lang =
  match get_keywords lang with
  | Some kws -> matches_keyword word kws.feature
  | None -> matches_keyword word english.feature

let is_scenario word lang =
  match get_keywords lang with
  | Some kws -> matches_keyword word (kws.scenario @ kws.scenario_outline)
  | None ->
      matches_keyword word (english.scenario @ english.scenario_outline)

let is_step word lang =
  match get_keywords lang with
  | Some kws ->
      matches_keyword word
        (kws.given @ kws.when_ @ kws.then_ @ kws.and_ @ kws.but)
  | None ->
      matches_keyword word
        (english.given @ english.when_ @ english.then_ @ english.and_
       @ english.but)

let supported_languages () = List.map fst keyword_table
