type 'a step = {
  regex : Re.re;
  stepdef :
    'a option -> Re.Group.t option -> Step.arg option -> 'a option * Outcome.t;
}

type 'a t = {
  before_hooks : (string -> unit) list;
  after_hooks : (string -> unit) list;
  stepdefs : 'a step list;
  dialect : Dialect.t;
}

let empty =
  { after_hooks = []; before_hooks = []; stepdefs = []; dialect = Dialect.En }

let _Before f cucc =
  let reg_before_hooks = cucc.before_hooks in
  { cucc with before_hooks = f :: reg_before_hooks }

let _After f cucc =
  let reg_after_hooks = cucc.after_hooks in
  { cucc with after_hooks = f :: reg_after_hooks }

let _Given re f cucc =
  let reg_steps = cucc.stepdefs in
  { cucc with stepdefs = { regex = re; stepdef = f } :: reg_steps }

let _When = _Given
let _Then = _Given
let set_dialect dialect cucc = { cucc with dialect }
let find str step = Re.execp step.regex str

let actuate user_step step state =
  let groups = Step.find_groups step user_step.regex in
  user_step.stepdef state groups (Step.argument step)

let run cucc state step =
  match List.filter (find (Step.text step)) cucc.stepdefs with
  | [ user_step ] -> actuate user_step step state
  | [] ->
      print_endline ("Could not find step: " ^ Step.text step);
      (None, Outcome.Undefined)
  | _ ->
      print_endline ("Ambigious match: " ^ Step.text step);
      (None, Outcome.Undefined)

(** Run a step using the step registry instead of the builder-based stepdefs *)
let run_from_registry state step =
  let step_text = Step.text step in
  let step_keyword = Step.keyword step in

  (* Convert keyword to step type, handling And/But by using a default *)
  let step_type =
    try Step_registry.step_type_of_keyword step_keyword
    with Failure _ ->
      (* For And/But/*, default to Given for now.
         TODO: Track previous step type properly *)
      `Given
  in

  match Step_registry.find_step step_text step_type with
  | Step_registry.Match (handler, groups) ->
      let args = Step.argument step in
      handler state groups args
  | Step_registry.NoMatch ->
      print_endline ("Could not find step: " ^ step_text);
      (None, Outcome.Undefined)
  | Step_registry.Ambiguous locations ->
      let loc_strs =
        List.map
          (function
            | Some { Step_registry.file; line; column } ->
                Printf.sprintf "%s:%d:%d" file line column
            | None -> "unknown")
          locations
      in
      print_endline
        (Printf.sprintf "Ambiguous match for '%s'. Matches found at: %s"
           step_text
           (String.concat ", " loc_strs));
      (None, Outcome.Undefined)

let execute_step cucc state step =
  try
    let result = run cucc state step in
    Ok result
  with ex -> Error (Printexc.to_string ex)

let print_step_result step outcome error_msg =
  let keyword = Step.keyword step in
  let step_text = "  " ^ keyword ^ " " ^ Step.text step in
  match outcome with
  | Outcome.Pass ->
      Printf.printf "  %s %s\n" (Color.green "✓") step_text;
      flush stdout
  | Outcome.Fail ->
      Printf.printf "  %s %s\n" (Color.red "✗") step_text;
      (match error_msg with
      | Some msg -> Printf.printf "      %s\n" (Color.red msg)
      | None -> ());
      flush stdout
  | Outcome.Undefined ->
      Printf.printf "  ? %s\n" step_text;
      flush stdout
  | Outcome.Skip ->
      Printf.printf "  - %s\n" step_text;
      flush stdout
  | Outcome.Pending ->
      Printf.printf "  P %s\n" step_text;
      flush stdout

let execute_step_with_skip cucc (skipping, error, lastState, results) step =
  if skipping then (
    print_step_result step Outcome.Skip None;
    (true, error, None, Outcome.Skip :: results))
  else
    match execute_step cucc lastState step with
    | Ok (s, Outcome.Pass) ->
        print_step_result step Outcome.Pass None;
        (false, None, s, Outcome.Pass :: results)
    | Ok (s, o) ->
        print_step_result step o None;
        (true, None, s, o :: results)
    | Error e ->
        print_step_result step Outcome.Fail (Some e);
        (true, Some e, None, Outcome.Fail :: results)

let print_error error pickle =
  match error with
  | Some e ->
      print_endline ("Error in scenario " ^ Pickle.name pickle);
      print_endline e;
      print_newline ()
  | _ -> ()

let execute_pickle cucc pickle =
  (* Print scenario header *)
  Printf.printf "  Scenario: %s\n" (Pickle.name pickle);
  flush stdout;

  let steps = Pickle.steps pickle in
  Pickle.execute_hooks cucc.before_hooks pickle;
  let _, error, _, outcomeLst =
    List.fold_left (execute_step_with_skip cucc) (false, None, None, []) steps
  in
  print_error error pickle;
  Pickle.execute_hooks cucc.after_hooks pickle;
  List.rev outcomeLst

let execute_pickle_lst cucc tags exit_status feature_file =
  let pickle_lst =
    Pickle.load_feature_file
      (Dialect.string_of_dialect cucc.dialect)
      feature_file
  in
  match pickle_lst with
  | [] -> Outcome.exit_status []
  | _ ->
      let runnable_pickle_lst = Pickle.filter_pickles tags pickle_lst in
      (* Print feature header once before all scenarios *)
      (match runnable_pickle_lst with
      | first_pickle :: _ ->
          Printf.printf "\n%s: %s\n"
            (Pickle.feature_keyword first_pickle)
            (Pickle.feature_name first_pickle);
          flush stdout
      | [] -> ());
      let outcome_lst = List.map (execute_pickle cucc) runnable_pickle_lst in
      Report.print feature_file outcome_lst;
      if exit_status = 0 then Outcome.exit_status (List.flatten outcome_lst)
      else exit_status

open Cmdliner

(* Positional arguments *)
let files_arg =
  Arg.(
    value & pos_all string []
    & info [] ~docv:"FILE" ~doc:"Feature files or glob patterns to run")

(* Filtering options *)
let name_arg =
  Arg.(
    value
    & opt (some string) None
    & info [ "n"; "name" ] ~docv:"REGEX"
        ~doc:"Filter scenarios by name using regex")

let tags_arg =
  Arg.(
    value
    & opt (some string) None
    & info [ "t"; "tags" ] ~docv:"TAGEXPR"
        ~doc:
          "Filter scenarios using tag expressions. Use @tag to include and \
           ~@tag to exclude. Multiple tags can be separated by spaces.")

let input_arg =
  Arg.(
    value & opt string "*.feature"
    & info [ "i"; "input" ] ~docv:"GLOB"
        ~doc:"Glob pattern for feature files (default: *.feature)")

(* Execution options *)
let concurrency_arg =
  Arg.(
    value & opt int 1
    & info [ "c"; "concurrency" ] ~docv:"INT"
        ~doc:"Number of concurrent scenarios (default: 1)")

let fail_fast_arg =
  Arg.(
    value & flag
    & info [ "fail-fast" ] ~doc:"Stop running tests after first failure")

let retry_arg =
  Arg.(
    value & opt int 0
    & info [ "retry" ] ~docv:"INT"
        ~doc:"Number of retry attempts for failed scenarios")

let retry_after_arg =
  Arg.(
    value
    & opt (some string) None
    & info [ "retry-after" ] ~docv:"DURATION"
        ~doc:"Delay between retry attempts (e.g., '10s', '1m')")

let retry_tag_filter_arg =
  Arg.(
    value
    & opt (some string) None
    & info [ "retry-tag-filter" ] ~docv:"TAGEXPR"
        ~doc:"Filter which scenarios get retried using tag expressions")

(* Output/Verbosity options *)
let verbosity_arg =
  Arg.(
    value & flag_all
    & info [ "v"; "verbose" ]
        ~doc:"Increase verbosity (can be repeated: -v, -vv, -vvv)")

let color_arg =
  let color_enum =
    [ ("auto", `Auto); ("always", `Always); ("never", `Never) ]
  in
  Arg.(
    value
    & opt (enum color_enum) `Auto
    & info [ "color" ] ~docv:"WHEN"
        ~doc:
          "Console output color policy: auto, always, or never (default: auto)")

let manage_command_line cucc name_filter tags_str input_glob concurrency
    fail_fast retry retry_after retry_tag_filter verbosity color files =
  (* Stub: Print configuration for debugging *)
  if List.length verbosity > 0 then (
    Printf.printf "Configuration:\n";
    (match name_filter with
    | Some n -> Printf.printf "  Name filter: %s\n" n
    | None -> ());
    (match tags_str with
    | Some t -> Printf.printf "  Tags: %s\n" t
    | None -> ());
    Printf.printf "  Input glob: %s\n" input_glob;
    Printf.printf "  Concurrency: %d\n" concurrency;
    Printf.printf "  Fail fast: %b\n" fail_fast;
    Printf.printf "  Retry: %d\n" retry;
    (match retry_after with
    | Some d -> Printf.printf "  Retry after: %s\n" d
    | None -> ());
    (match retry_tag_filter with
    | Some f -> Printf.printf "  Retry tag filter: %s\n" f
    | None -> ());
    Printf.printf "  Verbosity level: %d\n" (List.length verbosity);
    Printf.printf "  Color: %s\n"
      (match color with
      | `Auto -> "auto"
      | `Always -> "always"
      | `Never -> "never");
    Printf.printf "  Files: %s\n\n" (String.concat ", " files));

  (* Stub implementations for new features *)
  (* TODO: Implement name filtering *)
  let () =
    match name_filter with
    | Some _regex ->
        if List.length verbosity > 0 then
          Printf.printf "Note: Name filtering not yet implemented\n"
    | None -> ()
  in

  (* TODO: Implement concurrency *)
  let () =
    if concurrency > 1 && List.length verbosity > 0 then
      Printf.printf
        "Note: Concurrency not yet implemented (running sequentially)\n"
  in

  (* TODO: Implement fail-fast *)
  let () =
    if fail_fast && List.length verbosity > 0 then
      Printf.printf "Note: Fail-fast not yet implemented\n"
  in

  (* TODO: Implement retry logic *)
  let () =
    if retry > 0 && List.length verbosity > 0 then
      Printf.printf "Note: Retry not yet implemented\n"
  in

  (* TODO: Implement color control *)
  let () =
    match color with
    | `Auto -> () (* Already the default *)
    | `Always | `Never ->
        if List.length verbosity > 0 then
          Printf.printf "Note: Color control not yet implemented\n"
  in

  (* Existing tag filtering implementation *)
  let tags =
    match tags_str with
    | Some str -> Tag.list_of_string str
    | None -> Tag.list_of_string ""
  in

  (* Use existing file execution logic *)
  let files_to_run =
    if List.length files > 0 then files
    else (
      (* TODO: Implement glob pattern matching for input_glob *)
      if List.length verbosity > 0 then
        Printf.printf
          "Note: Using files from arguments, glob matching not yet implemented\n";
      [])
  in

  if List.length files_to_run = 0 then Result.Error "No feature files specified"
  else
    let exit_status =
      List.fold_left (execute_pickle_lst cucc tags) 0 files_to_run
    in
    if exit_status = 0 then Result.Ok ()
    else
      Result.Error "Some scenarios failed. Please see output for more details"

let cmd cucc =
  let term =
    Term.(
      const (manage_command_line cucc)
      $ name_arg $ tags_arg $ input_arg $ concurrency_arg $ fail_fast_arg
      $ retry_arg $ retry_after_arg $ retry_tag_filter_arg $ verbosity_arg
      $ color_arg $ files_arg)
  in
  let info =
    Cmd.info "cucumber" ~version:"1.0.3"
      ~doc:"Cucumber BDD test runner for OCaml"
      ~man:
        [
          `S Manpage.s_description;
          `P
            "Cucumber.ml is a Behavior-Driven Development (BDD) test runner \
             for OCaml. It executes feature files written in the Gherkin \
             language.";
          `S "FILTERING OPTIONS";
          `P "Control which scenarios are executed:";
          `I
            ( "-n, --name=REGEX",
              "Filter scenarios by name using a regular expression" );
          `I
            ( "-t, --tags=TAGEXPR",
              "Filter scenarios using tag expressions (@tag to include, ~@tag \
               to exclude)" );
          `I
            ( "-i, --input=GLOB",
              "Glob pattern for feature files (default: *.feature)" );
          `S "EXECUTION OPTIONS";
          `P "Control how scenarios are executed:";
          `I
            ( "-c, --concurrency=INT",
              "Number of concurrent scenarios (default: 1)" );
          `I ("--fail-fast", "Stop running tests after first failure");
          `I ("--retry=INT", "Number of retry attempts for failed scenarios");
          `I
            ( "--retry-after=DURATION",
              "Delay between retry attempts (e.g., '10s', '1m')" );
          `I
            ( "--retry-tag-filter=TAGEXPR",
              "Filter which scenarios get retried using tag expressions" );
          `S "OUTPUT OPTIONS";
          `P "Control output formatting and verbosity:";
          `I
            ( "-v, --verbose",
              "Increase verbosity (can be repeated: -v, -vv, -vvv)" );
          `I
            ( "--color=WHEN",
              "Console output color policy: auto, always, or never (default: \
               auto)" );
          `S Manpage.s_bugs;
          `P "Report bugs at https://github.com/cucumber/cucumber.ml/issues";
        ]
  in
  Cmd.v info term

(** Executes current Cucumber context and exits the process. *)
let execute cucc = exit @@ Cmd.eval_result (cmd cucc)

(** Execute using the step registry instead of builder-based stepdefs.

    This is used when steps are registered via PPX attributes. The registry is
    populated at module initialization time.

    Example usage in your test file:
    {[
      let () = Cucumber.Lib.execute_from_registry ()
    ]} *)
let execute_from_registry ?(dialect = Dialect.En) () =
  (* Create a modified version of execute that uses run_from_registry *)
  let cucc = { empty with dialect } in

  (* We need to override the run function to use the registry.
     To do this, we'll modify execute_step to try registry first. *)
  let execute_step_registry state step =
    try
      let result = run_from_registry state step in
      Ok result
    with ex -> Error (Printexc.to_string ex)
  in

  let execute_step_with_skip_registry (skipping, error, lastState, results) step
      =
    if skipping then (
      print_step_result step Outcome.Skip None;
      (true, error, None, Outcome.Skip :: results))
    else
      match execute_step_registry lastState step with
      | Ok (s, Outcome.Pass) ->
          print_step_result step Outcome.Pass None;
          (false, None, s, Outcome.Pass :: results)
      | Ok (s, o) ->
          print_step_result step o None;
          (true, None, s, o :: results)
      | Error e ->
          print_step_result step Outcome.Fail (Some e);
          (true, Some e, None, Outcome.Fail :: results)
  in

  let execute_pickle_registry pickle =
    (* Print scenario header *)
    Printf.printf "  Scenario: %s\n" (Pickle.name pickle);
    flush stdout;

    let steps = Pickle.steps pickle in
    Pickle.execute_hooks cucc.before_hooks pickle;
    let _, error, _, outcomeLst =
      List.fold_left execute_step_with_skip_registry (false, None, None, [])
        steps
    in
    print_error error pickle;
    Pickle.execute_hooks cucc.after_hooks pickle;
    List.rev outcomeLst
  in

  let execute_pickle_lst_registry tags exit_status feature_file =
    let pickle_lst =
      Pickle.load_feature_file
        (Dialect.string_of_dialect cucc.dialect)
        feature_file
    in
    match pickle_lst with
    | [] -> Outcome.exit_status []
    | _ ->
        let runnable_pickle_lst = Pickle.filter_pickles tags pickle_lst in
        (* Print feature header once before all scenarios *)
        (match runnable_pickle_lst with
        | first_pickle :: _ ->
            Printf.printf "\n%s: %s\n"
              (Pickle.feature_keyword first_pickle)
              (Pickle.feature_name first_pickle);
            flush stdout
        | [] -> ());
        let outcome_lst =
          List.map execute_pickle_registry runnable_pickle_lst
        in
        Report.print feature_file outcome_lst;
        if exit_status = 0 then Outcome.exit_status (List.flatten outcome_lst)
        else exit_status
  in

  (* Create a command that uses registry-based execution *)
  let term =
    Term.(
      const
        (fun
          _name_filter
          tags_str
          _input_glob
          _concurrency
          _fail_fast
          _retry
          _retry_after
          _retry_tag_filter
          _verbosity
          _color
          files
        ->
          (* Simplified version of manage_command_line *)
          let tags =
            match tags_str with
            | Some str -> Tag.list_of_string str
            | None -> Tag.list_of_string ""
          in

          if List.length files = 0 then
            Result.Error "No feature files specified"
          else
            let exit_status =
              List.fold_left (execute_pickle_lst_registry tags) 0 files
            in
            if exit_status = 0 then Result.Ok ()
            else
              Result.Error
                "Some scenarios failed. Please see output for more details")
      $ name_arg $ tags_arg $ input_arg $ concurrency_arg $ fail_fast_arg
      $ retry_arg $ retry_after_arg $ retry_tag_filter_arg $ verbosity_arg
      $ color_arg $ files_arg)
  in
  let info =
    Cmd.info "cucumber" ~version:"1.0.3"
      ~doc:"Cucumber BDD test runner for OCaml (registry-based)"
  in
  exit @@ Cmd.eval_result (Cmd.v info term)

let fail = (None, Outcome.Fail)
let pass = (None, Outcome.Pass)
let pass_with_state state = (Some state, Outcome.Pass)
