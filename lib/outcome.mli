(** A type representing the outcome of a user run step defintion. *)

type t = Pass | Fail | Pending | Undefined | Skip

val string_of_outcome : t -> string
(** Pretty print a string of the outcome.  

    This will be:
    {ul {- . -> Pass}
        {- "F" -> Fail}
        {- "P" -> Pending}
        {- "U" -> Undefined}
        {- "-" -> Skip}
    }
 *)

val string_of_outcomes : t list -> string
(** Pretty print [t list] as a string. *)

val count_outcome : t -> t list -> int
val count_failed : t list -> int
val count_undefined : t list -> int
val count_skipped : t list -> int
val count_pending : t list -> int
val count_passed : t list -> int
val print_outcomes : t list -> unit

val exit_status : t list -> int
(** Calculate the exit status based on the list of outcomes.  

    If any are other than Pass, the exit status returned is non-zero *)
