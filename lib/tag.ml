type t = { location : Location.t; name : string }

let make location name = { location; name }

let create_from_command_line name =
  { location = Location.from_command_line (); name }

let string_of_tag tag =
  let loc_str = Location.string_of_location tag.location in
  "\ntag name : " ^ tag.name ^ "\n" ^ loc_str

let compare t1 t2 = t1.name = t2.name

(* Helper: check if string starts with prefix *)
let starts_with prefix str =
  let prefix_len = String.length prefix in
  String.length str >= prefix_len && String.sub str 0 prefix_len = prefix

(* Helper: strip leading/trailing characters matching predicate *)
let strip_char char str =
  let len = String.length str in
  let rec find_start i =
    if i >= len then len else if str.[i] = char then find_start (i + 1) else i
  in
  let rec find_end i =
    if i < 0 then -1 else if str.[i] = char then find_end (i - 1) else i
  in
  let start_idx = find_start 0 in
  let end_idx = find_end (len - 1) in
  if start_idx > end_idx then ""
  else String.sub str start_idx (end_idx - start_idx + 1)

let strip_not_from_tag_name str_lst = List.map (strip_char '~') str_lst

let filter_disallowed_tags str_lst =
  strip_not_from_tag_name (List.filter (starts_with "~") str_lst)

let filter_allowed_tags str_lst =
  List.filter (fun str -> not (starts_with "~" str)) str_lst

let match_spaces = Re.Perl.compile_pat "[\t ]+"

(* Strip leading @ from tag name if present *)
let strip_at_sign str =
  if String.length str > 0 && str.[0] = '@' then
    String.sub str 1 (String.length str - 1)
  else str

let list_of_string str_lst =
  let tags_str_lst = Re.split match_spaces str_lst in
  let disallowed_tags_str = filter_disallowed_tags tags_str_lst in
  let allowed_tags_str = filter_allowed_tags tags_str_lst in
  (* Strip @ from tag names to match how they're stored in the AST *)
  let allowed_tags =
    List.map
      (fun s -> create_from_command_line (strip_at_sign s))
      allowed_tags_str
  in
  let disallowed_tags =
    List.map
      (fun s -> create_from_command_line (strip_at_sign s))
      disallowed_tags_str
  in
  (allowed_tags, disallowed_tags)
