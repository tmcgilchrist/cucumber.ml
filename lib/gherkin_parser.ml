(** Gherkin parser with environment and state management *)

open Gherkin_ast

type env = {
  mutable language : string;
  mutable last_step_type : step_type option;
}

exception Parse_error of string * position option

let create_env () = { language = "en"; last_step_type = None }
let create_env_with_lang lang = { language = lang; last_step_type = None }
let get_language env = env.language
let set_language env lang = env.language <- lang

let get_keywords env =
  match Gherkin_keywords.get_keywords env.language with
  | Some kws -> kws
  | None -> Gherkin_keywords.english

let is_keyword env word kw_type =
  let kws = get_keywords env in
  match kw_type with
  | `Feature -> Gherkin_keywords.matches_keyword word kws.feature
  | `Background -> Gherkin_keywords.matches_keyword word kws.background
  | `Rule -> Gherkin_keywords.matches_keyword word kws.rule
  | `Scenario -> Gherkin_keywords.matches_keyword word kws.scenario
  | `ScenarioOutline ->
      Gherkin_keywords.matches_keyword word kws.scenario_outline
  | `Examples -> Gherkin_keywords.matches_keyword word kws.examples
  | `Given -> Gherkin_keywords.matches_keyword word kws.given
  | `When -> Gherkin_keywords.matches_keyword word kws.when_
  | `Then -> Gherkin_keywords.matches_keyword word kws.then_
  | `And -> Gherkin_keywords.matches_keyword word kws.and_
  | `But -> Gherkin_keywords.matches_keyword word kws.but

let resolve_step_type env word =
  let kws = get_keywords env in
  if Gherkin_keywords.matches_keyword word kws.given then Some Given
  else if Gherkin_keywords.matches_keyword word kws.when_ then Some When
  else if Gherkin_keywords.matches_keyword word kws.then_ then Some Then
  else if Gherkin_keywords.matches_keyword word (kws.and_ @ kws.but) then
    env.last_step_type
  else None

let set_last_step_type env st = env.last_step_type <- Some st
let clear_last_step_type env = env.last_step_type <- None

let detect_language content =
  (* Split content into lines and search for language directive *)
  let lines = String.split_on_char '\n' content in
  let rec find_language = function
    | [] -> "en"
    | line :: rest ->
        let trimmed = String.trim line in
        (* Check if this is a language directive *)
        if String.length trimmed > 11 && String.sub trimmed 0 10 = "# language"
        then
          (* Extract language code after "# language:" *)
          let after_keyword =
            String.trim (String.sub trimmed 10 (String.length trimmed - 10))
          in
          if String.length after_keyword > 0 && after_keyword.[0] = ':' then
            let lang_code =
              String.trim
                (String.sub after_keyword 1 (String.length after_keyword - 1))
            in
            (* Validate that the language is supported *)
            match Gherkin_keywords.get_keywords lang_code with
            | Some _ -> lang_code
            | None -> "en" (* Default to English if unsupported *)
          else "en"
          (* Skip regular comments and blank lines, continue searching *)
        else if trimmed = "" || (String.length trimmed > 0 && trimmed.[0] = '#')
        then find_language rest
        (* Stop searching if we hit non-comment content *)
          else "en"
  in
  find_language lines

let parse_string content =
  (* Detect language from content *)
  let lang = detect_language content in
  (* Get keywords for the detected language *)
  let keywords =
    match Gherkin_keywords.get_keywords lang with
    | Some kws -> kws
    | None -> Gherkin_keywords.english
  in
  (* Configure lexer with keywords *)
  Lex.set_keywords keywords;
  (* Parse the content *)
  let sedlex_buf = Sedlexing.Utf8.from_string content in
  (* Menhir needs a function that produces tokens with positions *)
  let token_func () =
    let tok = Lex.read_token sedlex_buf in
    (* Get position information from sedlex *)
    let line, col = Sedlexing.loc sedlex_buf in
    let pos =
      {
        Lexing.pos_fname = "";
        Lexing.pos_lnum = line;
        Lexing.pos_bol = 0;
        Lexing.pos_cnum = col;
      }
    in
    (tok, pos, pos)
  in
  try
    MenhirLib.Convert.Simplified.traditional2revised Parser.feature_file
      token_func
  with
  | Lex.SyntaxError msg ->
      let line, col = Sedlexing.loc sedlex_buf in
      let position = { line; col } in
      raise (Parse_error (msg, Some position))
  | Parser.Error ->
      let line, col = Sedlexing.loc sedlex_buf in
      let position = { line; col } in
      raise (Parse_error ("Parse error", Some position))

let parse_file filename =
  let ic = open_in filename in
  try
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    parse_string content
  with e ->
    close_in_noerr ic;
    raise e
