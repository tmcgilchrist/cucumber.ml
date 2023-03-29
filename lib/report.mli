(** Module for generating a formatted report for output to the user. *)

val print : string -> Outcome.t list list -> unit
(** Print a formatted report to stdout. *)
