type t = Pass | Fail | Pending | Undefined | Skip

let string_of_outcome = function
  | Pass -> "."
  | Fail -> "F"
  | Pending -> "P"
  | Undefined -> "U"
  | Skip -> "-"

let count_outcome outcome outcome_lst =
  List.length (List.filter (fun o -> o = outcome) outcome_lst)

let count_failed outcomeLst = count_outcome Fail outcomeLst
let count_undefined outcomeLst = count_outcome Undefined outcomeLst
let count_skipped outcomeLst = count_outcome Skip outcomeLst
let count_pending outcomeLst = count_outcome Pending outcomeLst
let count_passed outcomeLst = count_outcome Pass outcomeLst

let print_outcomes outcomes =
  List.iter (fun o -> o |> string_of_outcome |> print_string) outcomes

(** returns exit status suitable for use with the exit function. *)
let exit_status outcome_list =
  if count_failed outcome_list > 0 || count_undefined outcome_list > 0 then 3
  else 0

let string_of_outcomes outcomes =
  String.concat "" (List.map string_of_outcome outcomes)
