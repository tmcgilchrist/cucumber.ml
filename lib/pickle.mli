(** Module for parsing and running Cucumber feature files.

    This module models the Cucumber Pickle which is returned from the Gherkin parser. 
 *)

type t

val load_feature_file : string -> string -> t list
(** Load a Gherkin feature file and return [t list]. *)

val execute_hooks : (string -> unit) list -> t -> unit
(** Execute user supplied Before and After hooks. *)

val steps : t -> Step.t list
(** Return all steps which are defined for the Pickle. *)

val name : t -> string
(** Return the name of the pickle (eg the Scenario name). *)

val filter_pickles : Tag.t list * Tag.t list -> t list -> t list
(** Filter pickles so that only the ones supplied by the user are
    executed.  See also [Tag.t] *)

val construct_hooks : (string -> unit Lwt.t) list -> t -> unit Lwt.t
