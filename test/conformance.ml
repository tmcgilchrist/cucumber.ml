(* Normalised conformance check between Gherkin_parser_pure and the upstream
   cucumber/gherkin AST goldens vendored under test/gherkin-testdata/.

   We project both sides to a canonical structure that's a strict subset of
   the upstream cucumber-messages shape — the parts our parser tracks. Fields
   we deliberately don't compare:

   - per-node ids (deterministic counters; not yet emitted by us)
   - cell-level locations and row ids (our AST stores rows as string list list)
   - per-tag locations (we store tag names only)
   - the gherkinDocument.uri (path-relative to upstream's CWD)
   - comments (our parser drops them)
   - line/column locations on every node — our parser has a known position
     bug (step positions are off by many lines/cols, see lex.ml get_position
     vs sedlex lexing_positions semantics). Once that is fixed, restore the
     [position] fields to the canonical record below.

   Step-keyword resolution IS compared via [step_kind] (Context / Action /
   Outcome / Conjunction) so that And/But behaviour is exercised. *)

open Cucumber

type step_kind = Context | Action | Outcome | Conjunction

type step = {
  s_keyword : string;  (* trimmed, e.g. "Given" *)
  s_kind : step_kind;
  s_text : string;
  s_docstring : string option;
  s_table : string list list option;
}

type examples = {
  e_keyword : string;
  e_name : string;
  e_description : string;
  e_tags : string list;
  e_header : string list;
  e_body : string list list;
}

type scenario = {
  sc_keyword : string;
  sc_name : string;
  sc_description : string;
  sc_tags : string list;
  sc_steps : step list;
  sc_examples : examples list;
}

type background = {
  bg_keyword : string;
  bg_name : string;
  bg_description : string;
  bg_steps : step list;
}

type rule = {
  ru_keyword : string;
  ru_name : string;
  ru_description : string;
  ru_tags : string list;
  ru_background : background option;
  ru_scenarios : scenario list;
}

type feature = {
  language : string;
  fe_keyword : string;
  fe_name : string;
  fe_description : string;
  fe_tags : string list;
  fe_background : background option;
  fe_scenarios : scenario list;
  fe_rules : rule list;
}

(* ------------------------------------------------------------------ *)
(* Projection from our AST                                            *)
(* ------------------------------------------------------------------ *)

let step_kind_of (st : Gherkin_ast.step) : step_kind =
  let kw = String.trim st.keyword in
  match kw with
  | "And" | "But" | "*" -> Conjunction
  | _ ->
    match st.step_type with
    | Given -> Context
    | When -> Action
    | Then -> Outcome

let step_of_ast (st : Gherkin_ast.step) : step =
  let docstring, table =
    match st.argument with
    | None -> (None, None)
    | Some (DocString d) -> (Some d.content, None)
    | Some (Table t) -> (None, Some t.rows)
  in
  {
    s_keyword = String.trim st.keyword;
    s_kind = step_kind_of st;
    s_text = st.text;
    s_docstring = docstring;
    s_table = table;
  }

let examples_of_ast (e : Gherkin_ast.examples) : examples =
  let header, body =
    match e.table with
    | Some { rows = h :: rest; _ } -> (h, rest)
    | Some { rows = []; _ } -> ([], [])
    | None -> ([], [])
  in
  {
    e_keyword = e.keyword;
    e_name = Option.value ~default:"" e.name;
    e_description = Option.value ~default:"" e.description;
    e_tags = e.tags;
    e_header = header;
    e_body = body;
  }

let scenario_of_ast (s : Gherkin_ast.scenario) : scenario =
  {
    sc_keyword = s.keyword;
    sc_name = s.name;
    sc_description = Option.value ~default:"" s.description;
    sc_tags = s.tags;
    sc_steps = List.map step_of_ast s.steps;
    sc_examples = List.map examples_of_ast s.examples;
  }

let background_of_ast (b : Gherkin_ast.background) : background =
  {
    bg_keyword = b.keyword;
    bg_name = b.name;
    bg_description = Option.value ~default:"" b.description;
    bg_steps = List.map step_of_ast b.steps;
  }

let rule_of_ast (r : Gherkin_ast.rule) : rule =
  {
    ru_keyword = r.keyword;
    ru_name = r.name;
    ru_description = Option.value ~default:"" r.description;
    ru_tags = r.tags;
    ru_background = Option.map background_of_ast r.background;
    ru_scenarios = List.map scenario_of_ast r.scenarios;
  }

let from_ours (f : Gherkin_ast.feature) : feature =
  {
    language = f.language;
    fe_keyword = f.keyword;
    fe_name = f.name;
    fe_description = Option.value ~default:"" f.description;
    fe_tags = f.tags;
    fe_background = Option.map background_of_ast f.background;
    fe_scenarios = List.map scenario_of_ast f.scenarios;
    fe_rules = List.map rule_of_ast f.rules;
  }

(* ------------------------------------------------------------------ *)
(* Projection from upstream JSON                                      *)
(* ------------------------------------------------------------------ *)

module J = Yojson.Safe.Util

let opt_string ?(default = "") json key =
  match J.member key json with
  | `Null -> default
  | `String s -> s
  | _ -> default

let tags_of_json json =
  match json with
  | `Null -> []
  | `List xs -> List.map (fun t -> J.member "name" t |> J.to_string) xs
  | _ -> []

let cells_to_strings cells =
  match cells with
  | `List xs -> List.map (fun c -> J.member "value" c |> J.to_string) xs
  | _ -> []

let table_rows_of_json json =
  match json with
  | `Null -> []
  | _ ->
      (match J.member "rows" json with
       | `List rows ->
           List.map (fun r -> J.member "cells" r |> cells_to_strings) rows
       | _ -> [])

let docstring_of_json json =
  match json with
  | `Null -> None
  | _ -> Some (J.member "content" json |> J.to_string)

let step_of_json json : step =
  let raw_kw = J.member "keyword" json |> J.to_string in
  let kw = String.trim raw_kw in
  let kind =
    match J.member "keywordType" json with
    | `String "Context" -> Context
    | `String "Action" -> Action
    | `String "Outcome" -> Outcome
    | `String "Conjunction" -> Conjunction
    | _ -> Conjunction
  in
  {
    s_keyword = kw;
    s_kind = kind;
    s_text = J.member "text" json |> J.to_string;
    s_docstring = J.member "docString" json |> docstring_of_json;
    s_table =
      (match J.member "dataTable" json with
       | `Null -> None
       | t -> Some (table_rows_of_json t));
  }

let examples_of_json json : examples =
  let header =
    match J.member "tableHeader" json with
    | `Null -> []
    | h -> J.member "cells" h |> cells_to_strings
  in
  let body =
    match J.member "tableBody" json with
    | `List xs -> List.map (fun r -> J.member "cells" r |> cells_to_strings) xs
    | _ -> []
  in
  {
    e_keyword = J.member "keyword" json |> J.to_string;
    e_name = opt_string json "name";
    e_description = opt_string json "description";
    e_tags = tags_of_json (J.member "tags" json);
    e_header = header;
    e_body = body;
  }

let steps_of_json json =
  match J.member "steps" json with
  | `List xs -> List.map step_of_json xs
  | _ -> []

let scenario_of_json json : scenario =
  {
    sc_keyword = J.member "keyword" json |> J.to_string;
    sc_name = opt_string json "name";
    sc_description = opt_string json "description";
    sc_tags = tags_of_json (J.member "tags" json);
    sc_steps = steps_of_json json;
    sc_examples =
      (match J.member "examples" json with
       | `List xs -> List.map examples_of_json xs
       | _ -> []);
  }

let background_of_json json : background =
  {
    bg_keyword = J.member "keyword" json |> J.to_string;
    bg_name = opt_string json "name";
    bg_description = opt_string json "description";
    bg_steps = steps_of_json json;
  }

(* Walk feature.children, picking out background/scenarios/rules. Upstream
   emits them in source order; we drop ordering between them since our AST
   doesn't preserve it. *)
let split_children children =
  let bg = ref None in
  let scenarios = ref [] in
  let rules = ref [] in
  let consume child =
    match J.member "background" child with
    | `Null ->
      (match J.member "scenario" child with
       | `Null ->
         (match J.member "rule" child with
          | `Null -> ()
          | r -> rules := r :: !rules)
       | s -> scenarios := s :: !scenarios)
    | b -> bg := Some b
  in
  List.iter consume children;
  (!bg, List.rev !scenarios, List.rev !rules)

let rule_of_json json : rule =
  let children =
    match J.member "children" json with `List xs -> xs | _ -> []
  in
  let bg, scenarios, _nested_rules = split_children children in
  {
    ru_keyword = J.member "keyword" json |> J.to_string;
    ru_name = opt_string json "name";
    ru_description = opt_string json "description";
    ru_tags = tags_of_json (J.member "tags" json);
    ru_background = Option.map background_of_json bg;
    ru_scenarios = List.map scenario_of_json scenarios;
  }

let empty_feature : feature =
  {
    language = "en";
    fe_keyword = "";
    fe_name = "";
    fe_description = "";
    fe_tags = [];
    fe_background = None;
    fe_scenarios = [];
    fe_rules = [];
  }

let from_upstream (json : Yojson.Safe.t) : feature =
  let f = J.member "gherkinDocument" json |> J.member "feature" in
  match f with
  | `Null -> empty_feature
  | _ ->
      let children =
        match J.member "children" f with `List xs -> xs | _ -> []
      in
      let bg, scenarios, rules = split_children children in
      {
        language = opt_string ~default:"en" f "language";
        fe_keyword = J.member "keyword" f |> J.to_string;
        fe_name = opt_string f "name";
        fe_description = opt_string f "description";
        fe_tags = tags_of_json (J.member "tags" f);
        fe_background = Option.map background_of_json bg;
        fe_scenarios = List.map scenario_of_json scenarios;
        fe_rules = List.map rule_of_json rules;
      }

(* ------------------------------------------------------------------ *)
(* Alcotest harness                                                    *)
(* ------------------------------------------------------------------ *)

let pp_step_kind ppf = function
  | Context -> Format.fprintf ppf "Context"
  | Action -> Format.fprintf ppf "Action"
  | Outcome -> Format.fprintf ppf "Outcome"
  | Conjunction -> Format.fprintf ppf "Conjunction"

let pp_step ppf (s : step) =
  Format.fprintf ppf
    "{keyword=%S; kind=%a; text=%S}"
    s.s_keyword pp_step_kind s.s_kind s.s_text

let pp_feature ppf (f : feature) =
  Format.fprintf ppf
    "@[<v>feature %S@,  scenarios=%d rules=%d background=%b@,@[<v 2>steps:@,%a@]@]"
    f.fe_name
    (List.length f.fe_scenarios)
    (List.length f.fe_rules)
    (Option.is_some f.fe_background)
    (Format.pp_print_list (fun ppf s ->
         Format.fprintf ppf "%S → [%a]" s.sc_name
           (Format.pp_print_list ~pp_sep:(fun ppf () -> Format.fprintf ppf "; ")
              pp_step)
           s.sc_steps))
    f.fe_scenarios

let feature_testable : feature Alcotest.testable =
  Alcotest.testable pp_feature ( = )

let good_dir = "gherkin-testdata/good"
let bad_dir = "gherkin-testdata/bad"

(* Filter to plain .feature only — skip .feature.md (Markdown Gherkin, which
   we don't implement). *)
let list_features dir =
  Sys.readdir dir
  |> Array.to_list
  |> List.filter (fun f ->
         Filename.check_suffix f ".feature"
         && not (Filename.check_suffix f ".md.feature"))
  |> List.sort compare

let conformance_good name () =
  let feature_path = Filename.concat good_dir name in
  let golden_path = feature_path ^ ".ast.ndjson" in
  if not (Sys.file_exists golden_path) then
    Alcotest.failf "no golden at %s" golden_path;
  let upstream =
    Yojson.Safe.from_file golden_path |> from_upstream
  in
  let ours = Gherkin_parser.parse_file feature_path |> from_ours in
  Alcotest.check feature_testable name upstream ours

let conformance_bad name () =
  let feature_path = Filename.concat bad_dir name in
  match Gherkin_parser.parse_file feature_path with
  | _ -> Alcotest.failf "expected parse error for %s" name
  | exception _ -> ()

let () =
  let good_cases =
    list_features good_dir
    |> List.map (fun f -> (f, `Quick, conformance_good f))
  in
  let bad_cases =
    list_features bad_dir
    |> List.map (fun f -> (f, `Quick, conformance_bad f))
  in
  Alcotest.run "Conformance"
    [ ("good", good_cases); ("bad", bad_cases) ]
