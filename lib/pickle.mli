(** Module for parsing and running Cucumber feature files.

    This module models the Cucumber Pickle which is returned from the Gherkin
    parser. It is functorized over a parser implementation, allowing different
    parser backends to be used.

    The default implementation uses {!Gherkin_parser_pure}. *)

(** Functor signature for creating Pickle modules with custom parsers *)
module Make (Parser : Gherkin_parser_intf.PARSER) : sig
  type t

  val load_feature_file : string -> string -> t list
  (** Load a Gherkin feature file and return [t list]. *)

  val execute_hooks : (string -> unit) list -> t -> unit
  (** Execute user supplied Before and After hooks. *)

  val steps : t -> Step.t list
  (** Return all steps which are defined for the Pickle. *)

  val name : t -> string
  (** Return the name of the pickle (eg the Scenario name). *)

  val feature_keyword : t -> string
  (** Return the feature keyword (eg "Feature"). *)

  val feature_name : t -> string
  (** Return the feature name. *)

  val filter_pickles : Tag.t list * Tag.t list -> t list -> t list
  (** Filter pickles so that only the ones supplied by the user are executed. See
      also [Tag.t] *)
end

(** Default instantiation using pure OCaml parser *)
type t

val load_feature_file : string -> string -> t list
(** Load a Gherkin feature file and return [t list]. *)

val execute_hooks : (string -> unit) list -> t -> unit
(** Execute user supplied Before and After hooks. *)

val steps : t -> Step.t list
(** Return all steps which are defined for the Pickle. *)

val name : t -> string
(** Return the name of the pickle (eg the Scenario name). *)

val feature_keyword : t -> string
(** Return the feature keyword (eg "Feature"). *)

val feature_name : t -> string
(** Return the feature name. *)

val filter_pickles : Tag.t list * Tag.t list -> t list -> t list
(** Filter pickles so that only the ones supplied by the user are executed. See
    also [Tag.t] *)
