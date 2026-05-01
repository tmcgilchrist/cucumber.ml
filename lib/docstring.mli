(** A type representing a Doc String.

    Doc Strings are used to pass a larger piece of text to a step definition. *)

type t

val make : string -> t
(** Create a docstring from content. *)

val string_of_docstring : t -> string
(** Pretty print a Doc String. *)

val transform : t -> (string -> 'a) -> 'a
(** Map across a Doc String. *)
