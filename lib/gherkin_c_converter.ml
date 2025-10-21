(* Converter from gherkin C structures to OCaml Gherkin_ast types
 *
 * This module handles all conversion from C structures (accessed via Ctypes)
 * to OCaml Gherkin_ast types.
 *)

open Ctypes
module C = Gherkin_c_bindings
module Ast = Cucumber__Gherkin_ast

(* Helper: Convert wchar_t* to OCaml string *)
let wchar_to_string (wstr : int32 ptr) : string =
  if is_null wstr then ""
  else
    let buf = Buffer.create 16 in
    let rec loop i =
      let c = Int32.to_int (!@ (wstr +@ i)) in
      if c = 0 then Buffer.contents buf
      else begin
        if c < 128 then Buffer.add_char buf (Char.chr c);
        loop (i + 1)
      end
    in
    loop 0

(* Helper: Convert C location to OCaml position *)
let convert_location (loc : C.location structure) : Ast.position =
  { line = Unsigned.ULong.to_int (getf loc C.location_line);
    col = Unsigned.ULong.to_int (getf loc C.location_column) }

(* Convert Tag - extract just the name as a string *)
let convert_tag (tag_ptr : C.tag structure ptr) : string =
  let t = !@ tag_ptr in
  wchar_to_string (getf t C.tag_name)

(* Convert Tags collection to string list *)
let convert_tags (tags_ptr : C.tags structure ptr) : string list =
  if is_null tags_ptr then []
  else
    let ts = !@ tags_ptr in
    let count = getf ts C.tags_count in
    let arr = getf ts C.tags_array in
    List.init count (fun i -> convert_tag (arr +@ i))

(* Convert TableCell - extract just the value *)
let convert_table_cell (cell_ptr : C.table_cell structure ptr) : string =
  let cell = !@ cell_ptr in
  wchar_to_string (getf cell C.table_cell_value)

(* Convert TableRow to string list *)
let convert_table_row (row_ptr : C.table_row structure ptr) : string list =
  let row = !@ row_ptr in
  let cells_ptr = getf row C.table_row_cells in
  if is_null cells_ptr then []
  else
    let cs = !@ cells_ptr in
    let count = getf cs C.table_cells_count in
    let arr = getf cs C.table_cells_array in
    List.init count (fun i -> convert_table_cell (arr +@ i))

(* Convert DataTable to table *)
let convert_data_table (dt_ptr : C.data_table structure ptr) : Ast.table =
  let dt = !@ dt_ptr in
  let rows_ptr = getf dt C.data_table_rows in
  let rows =
    if is_null rows_ptr then []
    else
      let rs = !@ rows_ptr in
      let count = getf rs C.table_rows_count in
      let arr = getf rs C.table_rows_array in
      List.init count (fun i -> convert_table_row (arr +@ i))
  in
  let pos = convert_location (getf dt C.data_table_location) in
  { rows; span = None; position = Some pos }

(* Convert DocString *)
let convert_doc_string (ds_ptr : C.doc_string structure ptr) : Ast.docstring =
  let ds = !@ ds_ptr in
  { content = wchar_to_string (getf ds C.doc_string_content);
    span = None }

(* Determine step type from keyword *)
let step_type_of_keyword (keyword : string) : Ast.step_type =
  let kw = String.trim (String.lowercase_ascii keyword) in
  if String.starts_with ~prefix:"given" kw then Ast.Given
  else if String.starts_with ~prefix:"when" kw then Ast.When
  else Ast.Then

(* Convert Step *)
let convert_step (step_ptr : C.step structure ptr) : Ast.step =
  let s = !@ step_ptr in
  let keyword = wchar_to_string (getf s C.step_keyword) in
  let arg_ptr = getf s C.step_argument_field in
  let argument =
    if is_null arg_ptr then None
    else
      let arg = !@ arg_ptr in
      let arg_type = getf arg C.step_argument_type in
      match arg_type with
      | C.Gherkin_DataTable ->
          let dt_ptr = coerce (ptr C.step_argument) (ptr C.data_table) arg_ptr in
          Some (Ast.Table (convert_data_table dt_ptr))
      | C.Gherkin_DocString ->
          let ds_ptr = coerce (ptr C.step_argument) (ptr C.doc_string) arg_ptr in
          Some (Ast.DocString (convert_doc_string ds_ptr))
      | _ -> None
  in
  let pos = convert_location (getf s C.step_location) in
  { keyword;
    step_type = step_type_of_keyword keyword;
    text = wchar_to_string (getf s C.step_text);
    argument;
    span = None;
    position = Some pos }

(* Convert Steps collection *)
let convert_steps (steps_ptr : C.steps structure ptr) : Ast.step list =
  if is_null steps_ptr then []
  else
    let ss = !@ steps_ptr in
    let count = getf ss C.steps_count in
    let arr = getf ss C.steps_array in
    List.init count (fun i -> convert_step (arr +@ i))

(* Convert Background *)
let convert_background (child_ptr : C.child_definition structure ptr) : Ast.background =
  let bg_ptr = coerce (ptr C.child_definition) (ptr C.background) child_ptr in
  let bg = !@ bg_ptr in
  let pos = convert_location (getf bg C.background_location) in
  { keyword = wchar_to_string (getf bg C.background_keyword);
    name = wchar_to_string (getf bg C.background_name);
    description =
      (let d = wchar_to_string (getf bg C.background_description) in
       if d = "" then None else Some d);
    steps = convert_steps (getf bg C.background_steps);
    span = None;
    position = Some pos }

(* Convert Scenario *)
let convert_scenario (child_ptr : C.child_definition structure ptr) : Ast.scenario =
  let sc_ptr = coerce (ptr C.child_definition) (ptr C.scenario) child_ptr in
  let sc = !@ sc_ptr in
  let pos = convert_location (getf sc C.scenario_location) in
  { keyword = wchar_to_string (getf sc C.scenario_keyword);
    name = wchar_to_string (getf sc C.scenario_name);
    description =
      (let d = wchar_to_string (getf sc C.scenario_description) in
       if d = "" then None else Some d);
    tags = convert_tags (getf sc C.scenario_tags);
    steps = convert_steps (getf sc C.scenario_steps);
    examples = [];
    span = None;
    position = Some pos }

(* Convert Feature *)
let convert_feature (feature_ptr : C.feature structure ptr) : Ast.feature =
  if is_null feature_ptr then
    failwith "convert_feature: null feature pointer"
  else
    let f = !@ feature_ptr in
    let children_ptr = getf f C.feature_children in

    let background, scenarios =
      if is_null children_ptr then (None, [])
      else
        let children = !@ children_ptr in
        let count = getf children C.child_definitions_count in
        let arr = getf children C.child_definitions_array in

        let bg_ref = ref None in
        let scenarios_ref = ref [] in

        for i = 0 to count - 1 do
          let child_ptr = !@ (arr +@ i) in
          let child_type = getf (!@ child_ptr) C.child_definition_type in
          match child_type with
          | C.Gherkin_Background ->
              bg_ref := Some (convert_background child_ptr)
          | C.Gherkin_Scenario ->
              scenarios_ref := convert_scenario child_ptr :: !scenarios_ref
          | _ -> ()
        done;

        (!bg_ref, List.rev !scenarios_ref)
    in

    let pos = convert_location (getf f C.feature_location) in
    { keyword = wchar_to_string (getf f C.feature_keyword);
      language = wchar_to_string (getf f C.feature_language);
      name = wchar_to_string (getf f C.feature_name);
      description =
        (let d = wchar_to_string (getf f C.feature_description) in
         if d = "" then None else Some d);
      tags = convert_tags (getf f C.feature_tags);
      background;
      scenarios;
      rules = [];
      span = None;
      position = Some pos }
