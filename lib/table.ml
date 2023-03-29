type cell = { location : Location.t; value : string }
type row = { cells : cell list }
type t = { rows : row list }

let string_of_cell cell =
  let loc_str = Location.string_of_location cell.location in
  loc_str ^ "\n" ^ cell.value

let string_of_row row =
  let aux accum cell = accum ^ string_of_cell cell ^ "\t" in
  Base.List.fold row.cells ~init:"" ~f:aux ^ "\n"

let string_of_table table =
  let str =
    Base.List.fold table.rows ~init:"" ~f:(fun accum row ->
        accum ^ string_of_row row)
  in
  "\nTable\n" ^ str

let zip_header header_row row =
  let header = Base.List.map header_row.cells ~f:(fun head -> head.value) in
  let row = Base.List.map row.cells ~f:(fun cell -> cell.value) in
  let zipped_row = Base.List.zip header row in
  match zipped_row with
  | Base.List.Or_unequal_lengths.Ok x -> x
  | Base.List.Or_unequal_lengths.Unequal_lengths -> []

let update_col_map map row =
  match row with
  | k, v ->
      Base.Map.update map k ~f:(fun vl ->
          match vl with Some x -> v :: x | _ -> [ v ])

let to_map_with_header dt =
  let empty_map = Base.Map.empty (module Base.String) in
  match dt.rows with
  | header :: rest ->
      let key_value_zip =
        List.flatten (Base.List.map (Base.List.rev rest) ~f:(zip_header header))
      in
      Base.List.fold key_value_zip ~init:empty_map ~f:update_col_map
  | [] -> empty_map

let transform dt f =
  let cells =
    Base.List.map dt.rows ~f:(fun row ->
        Base.List.map row.cells ~f:(fun cell -> cell.value))
  in
  Base.List.map cells ~f

let transform_with_header dt f =
  match dt.rows with
  | header :: rows ->
      let cells =
        Base.List.map rows ~f:(fun row ->
            Base.List.map row.cells ~f:(fun cell -> cell.value))
      in
      let header_cells = Base.List.map header.cells ~f:(fun hc -> hc.value) in
      Base.List.map cells ~f:(f header_cells)
  | [] -> []

let zip_col cells =
  match cells with
  | head :: rest -> (head.value, Base.List.map rest ~f:(fun x -> x.value))
  | [] -> ("", [ "" ])

let transform_with_col_header dt f =
  let zipped_cols = Base.List.map dt.rows ~f:(fun row -> zip_col row.cells) in
  Base.List.map zipped_cols ~f:(fun (head, rest) -> f head rest)

let to_map_with_col_header dt =
  let map = Base.Map.empty (module Base.String) in
  let zipped_cols = Base.List.map dt.rows ~f:(fun row -> zip_col row.cells) in
  Base.List.fold zipped_cols ~init:map ~f:(fun accum zip_col ->
      match zip_col with
      | head, rest ->
          Base.Map.update accum head ~f:(fun o ->
              match o with Some x -> x | None -> rest))
