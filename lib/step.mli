(** Implementation of the Cucumber Step (Given, When, Then).

    This is mainly used by the runtime to manipulate the step. *)

type t
type arg = DocString of Docstring.t | Table of Table.t

val make : string -> Location.t list -> string -> arg option -> t
(** Create a step from keyword, locations, text, and argument. *)

val string_of_arg : arg option -> string
val string_of_step : t -> string

val find : t -> Re.re -> bool
(** Match a user supplied regular expression to a step. *)

val find_groups : t -> Re.re -> Re.Group.t option
(** Extract string groups from the step to pass to a user supplied function *)

val text : t -> string
(** Obtain the full text string of a step *)

val keyword : t -> string
(** Obtain the keyword of a step (Given, When, Then, And, But) *)

val argument : t -> arg option
(** Extract arguments to a step *)
