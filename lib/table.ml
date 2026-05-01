type cell = { location : Location.t; value : string }
type row = { cells : cell list }
type t = { rows : row list }

(* Create a String map module *)
module StringMap = Map.Make (String)

let make rows_data =
  let rows =
    List.map
      (fun row_data ->
        let cells =
          List.map
            (fun value -> { location = Location.from_command_line (); value })
            row_data
        in
        { cells })
      rows_data
  in
  { rows }

let string_of_cell cell =
  let loc_str = Location.string_of_location cell.location in
  loc_str ^ "\n" ^ cell.value

let string_of_row row =
  let aux accum cell = accum ^ string_of_cell cell ^ "\t" in
  List.fold_left aux "" row.cells ^ "\n"

let string_of_table table =
  let str =
    List.fold_left (fun accum row -> accum ^ string_of_row row) "" table.rows
  in
  "\nTable\n" ^ str

let zip_header header_row row =
  let header = List.map (fun head -> head.value) header_row.cells in
  let row = List.map (fun cell -> cell.value) row.cells in
  try List.combine header row with Invalid_argument _ -> []

let update_col_map map (k, v) =
  let existing = StringMap.find_opt k map in
  match existing with
  | Some x -> StringMap.add k (v :: x) map
  | None -> StringMap.add k [ v ] map

let to_map_with_header dt =
  let empty_map = StringMap.empty in
  match dt.rows with
  | header :: rest ->
      let key_value_zip =
        List.flatten (List.map (zip_header header) (List.rev rest))
      in
      List.fold_left update_col_map empty_map key_value_zip
  | [] -> empty_map

let transform dt f =
  let cells =
    List.map (fun row -> List.map (fun cell -> cell.value) row.cells) dt.rows
  in
  List.map f cells

let transform_with_header dt f =
  match dt.rows with
  | header :: rows ->
      let cells =
        List.map (fun row -> List.map (fun cell -> cell.value) row.cells) rows
      in
      let header_cells = List.map (fun hc -> hc.value) header.cells in
      List.map (f header_cells) cells
  | [] -> []

let zip_col cells =
  match cells with
  | head :: rest -> (head.value, List.map (fun x -> x.value) rest)
  | [] -> ("", [ "" ])

let transform_with_col_header dt f =
  let zipped_cols = List.map (fun row -> zip_col row.cells) dt.rows in
  List.map (fun (head, rest) -> f head rest) zipped_cols

let to_map_with_col_header dt =
  let map = StringMap.empty in
  let zipped_cols = List.map (fun row -> zip_col row.cells) dt.rows in
  List.fold_left
    (fun accum (head, rest) ->
      let existing = StringMap.find_opt head accum in
      match existing with
      | Some x -> StringMap.add head x accum
      | None -> StringMap.add head rest accum)
    map zipped_cols
