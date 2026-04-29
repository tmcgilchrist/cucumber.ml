(** Cucumber.ml - BDD Testing Framework for OCaml

    This module provides the main API for Cucumber.ml, a Behavior-Driven Development
    (BDD) testing framework for OCaml.

    {1 API Styles}

    Three API styles are supported:
    - Classic builder API: Use [open Cucumber] for pipeline-based step definitions
    - PPX attributes: Use [let[@given]], [let[@when]], [let[@then]] with classic handlers
    - PPX + Effects: Use [let[@given]], [let[@when]], [let[@then]] with effect handlers ([open Cucumber.Effects])

    {1 Parser Selection}

    Cucumber.ml ships a pure OCaml Gherkin parser (no C dependencies). You can:
    - Use the default: [open Cucumber]
    - Use a custom parser via functor: [module MyCucumber = Cucumber.Make(My_parser)]

    @see <https://github.com/cucumber/cucumber.ml> for documentation and examples. *)

(** {1 Functor for Custom Parsers} *)

module Make : functor (Parser : Gherkin_parser_intf.PARSER) ->
  sig
    include module type of Lib.Make (Parser)
  end
(** Create a Cucumber instance with a custom parser.

    Example:
    {[
      module My_parser : Cucumber.Gherkin_parser_intf.PARSER = struct
        exception Parse_error of string * Gherkin_ast.position option
        let parse_file fname = (* ... *)
        let parse_string content = (* ... *)
        let detect_language content = "en"
      end

      module My_cucumber = Cucumber.Make(My_parser)

      let steps = My_cucumber.empty |> My_cucumber._Given ...
      let () = My_cucumber.execute steps
    ]} *)

(** {1 Classic Builder API}

    The classic API is exposed at the top level. Use [open Cucumber] to access these functions. *)

type 'a t
(** A cucumber context type which contains a world state type parameter *)

val empty : 'a t
(** Create an empty Cucumber context. *)

val _Given :
  Re.re ->
  ('a option -> Re.Group.t option -> Step.arg option -> 'a option * Outcome.t) ->
  'a t ->
  'a t
(** Attach a regular expression and a step definition to a Cucumber context. The
    step definition should accept three parameters: state, regular expression
    groups captured from the regular expression, and any step arguments. The
    function should return a tuple which has an optional state parameter and an
    [Outcome.t] (see the {!module-Outcome} for more information. *)

val _When :
  Re.re ->
  ('a option -> Re.Group.t option -> Step.arg option -> 'a option * Outcome.t) ->
  'a t ->
  'a t

val _Then :
  Re.re ->
  ('a option -> Re.Group.t option -> Step.arg option -> 'a option * Outcome.t) ->
  'a t ->
  'a t

val _Before : (string -> unit) -> 'a t -> 'a t
(** Attach a BeforeStep hook to a Cucumber context. *)

val _After : (string -> unit) -> 'a t -> 'a t
(** Attach an AfterStep hook to a Cucumber context. *)

val set_dialect : Dialect.t -> 'a t -> 'a t
(** Set the human language dialect of a set of feature files. The default is set
    to English ([Dialect.En]). *)

val execute : 'a t -> unit
(** Once the step definitions have been attached to the Cucumber context, this
    executes the step definitions then exits the program with an appropriate
    exit code. *)

val execute_from_registry : ?dialect:Dialect.t -> unit -> unit
(** Execute using steps registered via PPX attributes.

    This function is used when steps are registered automatically via PPX
    attributes like [let[@given]], [let[@when]], and [let[@then]]. The registry is populated
    at module initialization time.

    Example usage:
    {[
      let[@given "I have (\\d+) items"] given_step world groups args =
        (* step implementation *)
        (Some new_world, Outcome.Pass)

      let () = execute_from_registry ()
    ]}

    @param dialect The Gherkin language dialect (default: Dialect.En) *)

val fail : 'a option * Outcome.t
(** This function is a convenience method when a step definition does not wish
    to pass back a state and fail the step. *)

val pass : 'a option * Outcome.t
(** This function is a convenience method when a step definition does not wish
    to pass back a state and pass the step. *)

val pass_with_state : 'a -> 'a option * Outcome.t
(** This function is a convenience method when a step definition does wish to
    pass back a state and pass the step. *)

(** {1 Supporting Modules} *)

module Location : module type of Location
(** Source location information for Gherkin elements *)

module Docstring : module type of Docstring
(** DocString parsing and representation *)

module Table : module type of Table
(** Data table parsing and representation *)

module Step : module type of Step
(** Step definition types *)

module Outcome : module type of Outcome
(** Step execution outcome types (Pass, Fail, Skip, Pending) *)

module Tag : module type of Tag
(** Feature and scenario tags *)

module Pickle : module type of Pickle
(** Compiled test cases from Gherkin features *)

module Report : module type of Report
(** Test execution reporting *)

module Dialect : module type of Dialect
(** Gherkin language dialects (En, Fr, De, etc.) *)

module Gherkin_ast : module type of Gherkin_ast
(** Gherkin Abstract Syntax Tree *)

module Gherkin_keywords : module type of Gherkin_keywords
(** Gherkin keyword definitions by language *)

module Gherkin_parser_intf : module type of Gherkin_parser_intf
(** Parser interface module - defines the {!module-type:Gherkin_parser_intf.PARSER} signature *)

module Gherkin_parser : module type of Gherkin_parser_pure
(** Pure OCaml parser implementation (default) *)

module Lex : module type of Lex
(** Lexer for Gherkin *)

module Parser : module type of Parser
(** Parser for Gherkin *)

module Step_registry : module type of Step_registry
(** Global step registry for PPX-registered steps *)

module Effects : module type of Effects
(** Effect handler API for ergonomic step definitions.

    Use [open Cucumber.Effects] to access effect-based helpers like
    [get_world], [set_world], [assert_equal], etc. *)
