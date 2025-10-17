(* Lexer debugging tool for Gherkin feature files
 *
 * This utility reads a Gherkin feature file and outputs the token stream
 * produced by the lexer. Useful for debugging lexer behavior and understanding
 * how feature files are tokenized.
 *
 * Usage:
 *   dune exec test/bin/lex_debug.exe -- path/to/feature.file
 *
 * Example:
 *   dune exec test/bin/lex_debug.exe -- test/features/camels.feature
 *
 * Output format:
 *   Each line shows one token with its type and value:
 *   - FEATURE_LINE <name>
 *   - SCENARIO_LINE (<keyword>, <name>)
 *   - STEP_LINE (<keyword>, <type>, <text>)
 *   - TAG_LINE [<tag1>; <tag2>; ...]
 *   - BLANK_LINE
 *   - COMMENT_LINE
 *   - etc.
 *)

let () =
  if Array.length Sys.argv < 2 then (
    Printf.eprintf "Usage: %s <feature-file>\n" Sys.argv.(0);
    exit 1);

  let filename = Sys.argv.(1) in
  let ic = open_in filename in
  (* Set keywords to English *)
  Cucumber.Lex.set_keywords Cucumber.Gherkin_keywords.english;
  let lexbuf = Sedlexing.Utf8.from_channel ic in

  let rec loop () =
    let token = Cucumber.Lex.read_token lexbuf in
    (match token with
    | Cucumber.Parser.EOF -> print_endline "EOF"
    | Cucumber.Parser.BLANK_LINE -> print_endline "BLANK_LINE"
    | Cucumber.Parser.COMMENT_LINE -> print_endline "COMMENT_LINE"
    | Cucumber.Parser.TAG_LINE tags ->
        Printf.printf "TAG_LINE [%s]\n" (String.concat "; " tags)
    | Cucumber.Parser.FEATURE_LINE s -> Printf.printf "FEATURE_LINE %s\n" s
    | Cucumber.Parser.SCENARIO_LINE (kw, name) ->
        Printf.printf "SCENARIO_LINE (%s, %s)\n" kw name
    | Cucumber.Parser.STEP_LINE (kw, marker, text) ->
        Printf.printf "STEP_LINE (%s, %s, %s)\n" kw marker text
    | Cucumber.Parser.DESCRIPTION_LINE s ->
        Printf.printf "DESCRIPTION_LINE %s\n" s
    | _ -> print_endline "OTHER");
    if token <> Cucumber.Parser.EOF then loop ()
  in
  loop ();
  close_in ic
