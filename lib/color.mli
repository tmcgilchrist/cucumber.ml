(** ANSI color support for terminal output *)

val is_tty : unit -> bool
(** Check if stdout is a TTY (terminal). Returns false if output is redirected.
*)

val green : string -> string
(** Colorize text in green if outputting to a TTY *)

val red : string -> string
(** Colorize text in red if outputting to a TTY *)

val purple : string -> string
(** Colorize text in purple/magenta if outputting to a TTY *)

val reset : string -> string
(** Return text unchanged (for compatibility) *)
