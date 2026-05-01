let format_stat (text, count) =
  if count > 0 then
    let count_text = string_of_int count ^ " " ^ text in
    (* Color "passed" in green *)
    if text = "passed" then Some (Color.green count_text) else Some count_text
  else None

let format_stats stats = List.filter_map format_stat stats

let scenario_report outcome_lists =
  let scenarios = List.length outcome_lists in
  let failed =
    List.length
      (List.filter
         (fun os ->
           Outcome.count_outcome Outcome.Fail os > 0
           || Outcome.count_outcome Outcome.Pending os > 0)
         outcome_lists)
  in
  let undefined =
    List.length
      (List.filter
         (fun os -> Outcome.count_outcome Outcome.Undefined os > 0)
         outcome_lists)
  in
  let passed = scenarios - failed - undefined in
  let stats =
    [ ("passed", passed); ("undefined", undefined); ("failed", failed) ]
  in
  let stats_str = String.concat ", " (format_stats stats) in
  Format.sprintf "@[%d@ scenarios@ @[(%s)@]@]@." scenarios stats_str

let step_report outcomes =
  let steps = List.length outcomes in
  let stats =
    [
      ("passed", Outcome.count_passed outcomes);
      ("pending", Outcome.count_pending outcomes);
      ("skipped", Outcome.count_skipped outcomes);
      ("undefined", Outcome.count_undefined outcomes);
      ("failed", Outcome.count_failed outcomes);
    ]
  in
  let stats_str = String.concat ", " (format_stats stats) in
  if steps > 0 then Format.sprintf "@[%d steps@ @[(%s)@]@]" steps stats_str
  else Format.sprintf "@[%d steps@]" steps

let print feature_file outcome_lists =
  let outcomes = List.flatten outcome_lists in
  (* Print colored summary header *)
  Format.printf "\n@[%s@]@." (Color.purple "[Summary]");
  Format.printf "@[Feature File: %s@]@." feature_file;
  Format.printf "@[%s@]" (scenario_report outcome_lists);
  Format.printf "@[%s@]@." (step_report outcomes)
