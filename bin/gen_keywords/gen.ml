(* Generator for lib/gherkin_keywords_data.ml from
   vendor/gherkin-languages.json (the canonical cucumber/gherkin
   keyword table). Reads the JSON and prints OCaml to stdout. *)

let usage () =
  prerr_endline "usage: gen <gherkin-languages.json>";
  exit 2

(* Upstream JSON key -> OCaml record field. Order is significant:
   the generated record literal uses this order. *)
let fields =
  [ ("feature", "feature")
  ; ("background", "background")
  ; ("rule", "rule")
  ; ("scenario", "scenario")
  ; ("scenarioOutline", "scenario_outline")
  ; ("examples", "examples")
  ; ("given", "given")
  ; ("when", "when_")
  ; ("then", "then_")
  ; ("and", "and_")
  ; ("but", "but")
  ]

(* Upstream encodes step keywords with a trailing space (e.g. "Given ")
   to mark "this keyword expects a space, not a colon, after it".
   Our matcher works on already-tokenised words, so strip it. *)
let strip_trailing_space s =
  let n = String.length s in
  if n > 0 && s.[n - 1] = ' ' then String.sub s 0 (n - 1) else s

let extract_list obj key =
  match Yojson.Safe.Util.member key obj with
  | `List xs ->
      List.map
        (fun x -> strip_trailing_space (Yojson.Safe.Util.to_string x))
        xs
  | _ ->
      Printf.eprintf "missing or non-list field %S\n" key;
      exit 1

let escape_ocaml_string s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\r' -> Buffer.add_string b "\\r"
      | '\t' -> Buffer.add_string b "\\t"
      | c when Char.code c < 0x20 ->
          Buffer.add_string b (Printf.sprintf "\\%03d" (Char.code c))
      | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '"';
  Buffer.contents b

let format_list strings =
  "[ "
  ^ String.concat "; " (List.map escape_ocaml_string strings)
  ^ " ]"

let format_keyword_set obj =
  let buf = Buffer.create 256 in
  Buffer.add_string buf "{\n";
  List.iter
    (fun (json_key, ocaml_field) ->
      Printf.bprintf buf "    %s = %s;\n" ocaml_field
        (format_list (extract_list obj json_key)))
    fields;
  Buffer.add_string buf "  }";
  Buffer.contents buf

let () =
  if Array.length Sys.argv <> 2 then usage ();
  let json = Yojson.Safe.from_file Sys.argv.(1) in
  let langs = Yojson.Safe.Util.to_assoc json in
  (* Sort by language code for stable output across runs. *)
  let langs = List.sort (fun (a, _) (b, _) -> compare a b) langs in

  print_endline
    "(* AUTO-GENERATED from vendor/gherkin-languages.json — do not edit. *)";
  print_endline
    "(* Regenerated on every build by bin/gen_keywords/gen.ml. *)";
  print_endline "";
  print_endline "type keyword_set = {";
  List.iter
    (fun (_, f) -> Printf.printf "  %s : string list;\n" f)
    fields;
  print_endline "}";
  print_endline "";

  print_endline "let keyword_table : (string * keyword_set) list = [";
  List.iter
    (fun (code, obj) ->
      Printf.printf "  (%s, %s);\n"
        (escape_ocaml_string code)
        (format_keyword_set obj))
    langs;
  print_endline "]";
  print_endline "";
  print_endline "let english =";
  print_endline "  match List.assoc_opt \"en\" keyword_table with";
  print_endline "  | Some k -> k";
  print_endline
    "  | None -> failwith \"gherkin-languages.json missing 'en' entry\""
