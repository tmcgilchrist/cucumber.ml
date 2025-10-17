type t = { location : Location.t; content : string }

let make content = { location = Location.from_command_line (); content }

let string_of_docstring doc =
  let loc_str = Location.string_of_location doc.location in
  loc_str ^ "\nContent\n" ^ doc.content ^ "\n"

let transform doc f = f doc.content
