(* ANSI color codes for terminal output *)

let is_tty () = try Unix.isatty Unix.stdout with _ -> false
let green_code = "\027[32m"
let red_code = "\027[31m"
let purple_code = "\027[35m"
let reset_code = "\027[0m"

let colorize color_code text =
  if is_tty () then color_code ^ text ^ reset_code else text

let green text = colorize green_code text
let red text = colorize red_code text
let purple text = colorize purple_code text
let reset text = text
