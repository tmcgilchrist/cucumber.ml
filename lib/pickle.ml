(** Pickle module - converts Gherkin AST to executable test pickles.

    This module is functorized over a parser implementation, allowing different
    parser backends to be used while keeping the pickle compilation logic identical. *)

module Make (Parser : Gherkin_parser_intf.PARSER) = struct
  type t = {
    lang : string;
    name : string;
    locations : Location.t list;
    tags : Tag.t list;
    steps : Step.t list;
    feature_keyword : string;
    feature_name : string;
  }

  (* Helper: rev_filter reverses while filtering *)
  let rev_filter f lst = List.rev (List.filter f lst)
  let execute_hooks hooks p = List.iter (fun f -> f p.name) (List.rev hooks)
  let steps p = p.steps
  let name p = p.name
  let feature_keyword p = p.feature_keyword
  let feature_name p = p.feature_name

(* Convert Gherkin AST to Pickle format *)
let convert_position (pos : Gherkin_ast.position option) : Location.t =
  match pos with
  | Some p ->
      Location.make
        (Int32.of_int p.Gherkin_ast.line)
        (Int32.of_int p.Gherkin_ast.col)
  | None -> Location.from_command_line ()

let convert_tag (tag_name : string) (pos : Gherkin_ast.position option) : Tag.t
    =
  Tag.make (convert_position pos) tag_name

let convert_step (step : Gherkin_ast.step) : Step.t =
  let arg =
    match step.argument with
    | Some (Gherkin_ast.DocString ds) ->
        Some (Step.DocString (Docstring.make ds.content))
    | Some (Gherkin_ast.Table tbl) -> Some (Step.Table (Table.make tbl.rows))
    | None -> None
  in
  Step.make step.keyword [ convert_position step.position ] step.text arg

(* Convert a scenario to a pickle *)
let scenario_to_pickle (feature : Gherkin_ast.feature)
    (scenario : Gherkin_ast.scenario) : t =
  {
    lang = feature.language;
    name = scenario.name;
    locations = [ convert_position scenario.position ];
    tags = List.map (fun tag -> convert_tag tag scenario.position) scenario.tags;
    steps = List.map convert_step scenario.steps;
    feature_keyword = feature.keyword;
    feature_name = feature.name;
  }

(* Convert a scenario outline with examples to multiple pickles *)
let scenario_outline_to_pickles (feature : Gherkin_ast.feature)
    (scenario : Gherkin_ast.scenario) : t list =
  if List.length scenario.examples = 0 then
    (* No examples, treat as regular scenario *)
    [ scenario_to_pickle feature scenario ]
  else
    (* Create a pickle for each example row (except header) *)
    List.concat_map
      (fun (example : Gherkin_ast.examples) ->
        match example.table with
        | None -> []
        | Some table when List.length table.rows < 2 -> []
        | Some table ->
            let headers = List.hd table.rows in
            let data_rows = List.tl table.rows in
            List.map
              (fun row ->
                (* Substitute placeholders in step text *)
                let steps =
                  List.map
                    (fun step ->
                      let text =
                        List.fold_left2
                          (fun text header value ->
                            let placeholder = "<" ^ header ^ ">" in
                            Str.global_replace
                              (Str.regexp_string placeholder)
                              value text)
                          step.Gherkin_ast.text headers row
                      in
                      { step with Gherkin_ast.text })
                    scenario.steps
                in
                {
                  lang = feature.language;
                  name = scenario.name;
                  locations = [ convert_position scenario.position ];
                  tags =
                    List.map
                      (fun tag -> convert_tag tag scenario.position)
                      scenario.tags;
                  steps = List.map convert_step steps;
                  feature_keyword = feature.keyword;
                  feature_name = feature.name;
                })
              data_rows)
      scenario.examples

(* Convert feature to pickles *)
let feature_to_pickles (feature : Gherkin_ast.feature) : t list =
  (* Background steps are prepended to each scenario *)
  let background_steps =
    match feature.background with Some bg -> bg.steps | None -> []
  in

  (* Convert scenarios, prepending background *)
  let scenario_pickles =
    List.concat_map
      (fun (scenario : Gherkin_ast.scenario) ->
        let scenario_with_bg =
          { scenario with steps = background_steps @ scenario.steps }
        in
        if List.length scenario.examples > 0 then
          scenario_outline_to_pickles feature scenario_with_bg
        else [ scenario_to_pickle feature scenario_with_bg ])
      feature.scenarios
  in

  (* Convert scenarios in rules *)
  let rule_pickles =
    List.concat_map
      (fun (rule : Gherkin_ast.rule) ->
        let rule_background_steps =
          match rule.background with Some bg -> bg.steps | None -> []
        in
        let all_bg_steps = background_steps @ rule_background_steps in
        List.concat_map
          (fun (scenario : Gherkin_ast.scenario) ->
            let scenario_with_bg =
              {
                scenario with
                steps = all_bg_steps @ scenario.steps;
                tags = rule.tags @ scenario.tags;
              }
            in
            if List.length scenario.examples > 0 then
              scenario_outline_to_pickles feature scenario_with_bg
            else [ scenario_to_pickle feature scenario_with_bg ])
          rule.scenarios)
      feature.rules
  in

  scenario_pickles @ rule_pickles

  let load_feature_file _dialect fname =
    if Sys.file_exists fname then (
      try
        (* Parse the feature file using the configured parser *)
        let feature = Parser.parse_file fname in
        (* Convert to pickles *)
        feature_to_pickles feature
      with
      | Parser.Parse_error (msg, pos) ->
          (match pos with
          | Some p ->
              Printf.printf "Parse error at line %d, col %d: %s\n"
                p.Gherkin_ast.line p.col msg
          | None -> Printf.printf "Parse error: %s\n" msg);
          []
      | e ->
          Printf.printf "Error parsing %s: %s\n" fname (Printexc.to_string e);
          [])
    else (
      print_endline ("Feature File " ^ fname ^ " does not exist");
      [])

let tags_exists tags tag = List.exists (Tag.compare tag) tags
let pickles_exists tags pickle = List.exists (tags_exists pickle.tags) tags

let filter_not_pickles disallowed pickles =
  let allow_empty_tag_list p =
    match p.tags with [] -> true | _ -> not (pickles_exists disallowed p)
  in
  rev_filter allow_empty_tag_list pickles

  let filter_pickles tags pickles =
    match tags with
    | [], [] -> pickles
    | allowed, [] -> rev_filter (pickles_exists allowed) pickles
    | [], disallowed -> filter_not_pickles disallowed pickles
    | allowed, disallowed ->
        let filtered_pickles = rev_filter (pickles_exists allowed) pickles in
        rev_filter (fun p -> not (pickles_exists disallowed p)) filtered_pickles
end

(* Default instantiation with pure OCaml parser for backward compatibility *)
include Make (Gherkin_parser_pure)
