(* Gherkin lexer using sedlex for Unicode support *)

open Parser

exception SyntaxError of string

(* Keyword recognition based on current language *)
let current_keywords = ref Gherkin_keywords.english
let set_keywords kws = current_keywords := kws

(* Token types for internal use *)
type temp_step_token =
  | GIVEN_KEYWORD of string
  | WHEN_KEYWORD of string
  | THEN_KEYWORD of string
  | AND_KEYWORD of string
  | BUT_KEYWORD of string

type temp_structural_token =
  | FEATURE_KEYWORD
  | BACKGROUND_KEYWORD
  | RULE_KEYWORD
  | SCENARIO_KEYWORD
  | SCENARIO_OUTLINE_KEYWORD
  | EXAMPLES_KEYWORD

(* Check if word is a step keyword (Given/When/Then/And/But) *)
let check_step_keyword word =
  let kws = !current_keywords in
  if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.given then
    Some (GIVEN_KEYWORD word)
  else if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.when_ then
    Some (WHEN_KEYWORD word)
  else if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.then_ then
    Some (THEN_KEYWORD word)
  else if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.and_ then
    Some (AND_KEYWORD word)
  else if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.but then
    Some (BUT_KEYWORD word)
  else None

(* Check if word is a structural keyword (Feature/Scenario/etc - requires colon) *)
let check_structural_keyword word =
  let kws = !current_keywords in
  if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.feature then
    Some FEATURE_KEYWORD
  else if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.background
  then Some BACKGROUND_KEYWORD
  else if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.rule then
    Some RULE_KEYWORD
  else if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.scenario
  then Some SCENARIO_KEYWORD
  else if
    Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.scenario_outline
  then Some SCENARIO_OUTLINE_KEYWORD
  else if Gherkin_keywords.matches_keyword word kws.Gherkin_keywords.examples
  then Some EXAMPLES_KEYWORD
  else None

(* Read characters until end of line, returning the content *)
let read_line_content lexbuf =
  let buf = Buffer.create 80 in
  let rec loop () =
    match%sedlex lexbuf with
    | '\r' | '\n' | "\r\n" ->
        Sedlexing.new_line lexbuf;
        Buffer.contents buf
    | eof -> Buffer.contents buf
    | any ->
        Buffer.add_string buf (Sedlexing.Utf8.lexeme lexbuf);
        loop ()
    | _ -> Buffer.contents buf
  in
  loop ()

(* Parse tags from a line starting with @ *)
let parse_tag_line content =
  let tags = String.split_on_char ' ' content in
  let tags = List.filter (fun s -> s <> "") tags in
  List.map
    (fun tag ->
      if String.length tag > 0 && tag.[0] = '@' then
        String.sub tag 1 (String.length tag - 1)
      else tag)
    tags

(* Line-based lexer - reads one line at a time and classifies it *)
let read_token lexbuf =
  (* Skip leading whitespace within line *)
  let _ =
    match%sedlex lexbuf with
    | Star (Chars " \t") -> ()
    | _ -> Sedlexing.rollback lexbuf
  in

  match%sedlex lexbuf with
  (* Empty lines - emit BLANK_LINE token *)
  | '\r' | '\n' | "\r\n" ->
      Sedlexing.new_line lexbuf;
      BLANK_LINE
  (* End of file *)
  | eof -> EOF
  (* Language directive: # language: <code> *)
  | ( '#',
      Star (Chars " \t"),
      "language",
      Star (Chars " \t"),
      ':',
      Star (Chars " \t") ) ->
      let content = read_line_content lexbuf in
      let lang_code =
        let trimmed = String.trim content in
        let rec extract_letters i acc =
          if i >= String.length trimmed then String.concat "" (List.rev acc)
          else
            match trimmed.[i] with
            | 'a' .. 'z' | 'A' .. 'Z' ->
                extract_letters (i + 1) (String.make 1 trimmed.[i] :: acc)
            | _ -> String.concat "" (List.rev acc)
        in
        extract_letters 0 []
      in
      LANGUAGE_DIRECTIVE lang_code
  (* Comments - emit COMMENT_LINE token *)
  | '#' ->
      let _ = read_line_content lexbuf in
      COMMENT_LINE
  (* Tag line: @tag1 @tag2 ... *)
  | '@' ->
      Sedlexing.rollback lexbuf;
      let content = read_line_content lexbuf in
      let tags = parse_tag_line content in
      TAG_LINE tags
  (* Docstring delimiters *)
  | "\"\"\"" ->
      let _ = read_line_content lexbuf in
      (* Skip rest of line *)
      DOCSTRING_DELIMITER
  | "```" ->
      let _ = read_line_content lexbuf in
      (* Skip rest of line *)
      DOCSTRING_ALT_DELIMITER
  (* Table row: | cell1 | cell2 | *)
  | '|' ->
      Sedlexing.rollback lexbuf;
      let content = read_line_content lexbuf in
      let cells = String.split_on_char '|' content in
      let cells = List.filter (fun s -> s <> "") cells in
      let cells = List.map String.trim cells in
      TABLE_ROW cells
  (* Words with optional trailing colon - check for keywords *)
  | ( ('a' .. 'z' | 'A' .. 'Z'),
      Star (alphabetic | '0' .. '9' | '-' | '_' | '\'' | 0x0080 .. 0x10FFFF) )
    -> (
      let word = Sedlexing.Utf8.lexeme lexbuf in
      (* Check if followed by colon and rest of line *)
      match%sedlex lexbuf with
      | ':', Star (Chars " \t") -> (
          let name = String.trim (read_line_content lexbuf) in
          (* Check structural keywords *)
          match check_structural_keyword word with
          | Some FEATURE_KEYWORD -> FEATURE_LINE name
          | Some BACKGROUND_KEYWORD -> BACKGROUND_LINE name
          | Some RULE_KEYWORD -> RULE_LINE name
          | Some SCENARIO_KEYWORD -> SCENARIO_LINE ("Scenario", name)
          | Some SCENARIO_OUTLINE_KEYWORD ->
              SCENARIO_LINE ("Scenario Outline", name)
          | Some EXAMPLES_KEYWORD -> EXAMPLES_LINE name
          | _ ->
              (* Not a structural keyword, treat as description line *)
              Sedlexing.rollback lexbuf;
              let rest = read_line_content lexbuf in
              DESCRIPTION_LINE (word ^ rest))
      | _ -> (
          (* No colon, check if it's a step keyword *)
          match check_step_keyword word with
          | Some (GIVEN_KEYWORD kw) ->
              let text = String.trim (read_line_content lexbuf) in
              STEP_LINE (kw, "Given", text)
          | Some (WHEN_KEYWORD kw) ->
              let text = String.trim (read_line_content lexbuf) in
              STEP_LINE (kw, "When", text)
          | Some (THEN_KEYWORD kw) ->
              let text = String.trim (read_line_content lexbuf) in
              STEP_LINE (kw, "Then", text)
          | Some (AND_KEYWORD kw) ->
              let text = String.trim (read_line_content lexbuf) in
              STEP_LINE (kw, "And", text)
          | Some (BUT_KEYWORD kw) ->
              let text = String.trim (read_line_content lexbuf) in
              STEP_LINE (kw, "But", text)
          | _ ->
              (* Regular text line - description *)
              let rest = read_line_content lexbuf in
              DESCRIPTION_LINE (word ^ rest)))
  (* Numbers or other text - treat as description line *)
  | any ->
      Sedlexing.rollback lexbuf;
      let content = read_line_content lexbuf in
      if String.trim content = "" then BLANK_LINE else DESCRIPTION_LINE content
  | _ -> raise (SyntaxError "Unexpected end of input")

(* Read docstring content between delimiters *)
let rec read_docstring delimiter lexbuf =
  match%sedlex lexbuf with
  | "\"\"\"" ->
      if delimiter = "\"\"\"" then ""
      else "\"\"\"" ^ read_docstring delimiter lexbuf
  | "```" ->
      if delimiter = "```" then "" else "```" ^ read_docstring delimiter lexbuf
  | '\r' | '\n' | "\r\n" ->
      Sedlexing.new_line lexbuf;
      "\n" ^ read_docstring delimiter lexbuf
  | eof -> raise (SyntaxError "Unterminated docstring")
  | any ->
      let c = Sedlexing.Utf8.lexeme lexbuf in
      c ^ read_docstring delimiter lexbuf
  | _ -> raise (SyntaxError "Unexpected end in docstring")
