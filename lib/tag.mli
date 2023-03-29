(** Module implementing Cucumber Tags.

    Tags are a great way to organise your features and scenarios.

    They can be used for two purposes:
    {ul {- Running a subset of scenarios}
        {- Restricting hooks to a subset of scenarios}
    }
 *)

type t

val string_of_tag : t -> string
(** Create a string from a Tag. *)

val compare : t -> t -> bool
(** Compare two tags for equality. *)

val list_of_string : string -> t list * t list
(** Given a list of tags as a string, return a tuple representing
   the allowed and disallowed tags.  

   These are set by the command line argument --tags and
   primarily used to filter pickles during runtime. *)
