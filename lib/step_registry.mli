(** Global registry for step definitions registered via PPX.

    This module provides a type-safe registry for step definitions using GADTs
    to track world state types. Steps can be registered either through the PPX
    (using [let[@given]], [let[@when]], [let[@then]] attributes or [let%given],
    [let%when], [let%then] extension points) or manually using the [register]
    function. *)

(** {1 Types} *)

type step_location = { file : string; line : int; column : int }
(** Location information for a step definition *)

type step_type = [ `Given | `When | `Then ]
(** Step type: Given, When, or Then *)

type 'a step_handler =
  'a option -> Re.Group.t option -> Step.arg option -> 'a option * Outcome.t
(** Handler function for a step.

    The handler receives:
    - The current world state (None if not set)
    - Regex match groups (if the pattern matched)
    - Step arguments (table or docstring, if present)

    And returns:
    - The updated world state (or None)
    - The outcome of the step *)

(** GADT for tracking world type in step definitions.

    This allows us to store steps with different world types in the same
    registry while maintaining type safety when retrieving and executing them.
*)
type _ step_kind =
  | Step : {
      step_type : step_type;
      pattern : string;
      regex : Re.re;
      location : step_location option;
      handler : 'a step_handler;
    }
      -> 'a step_kind

(** Existential wrapper for heterogeneous step storage.

    Since steps can have different world types, we use an existential to store
    them together in a list. The type variable is hidden, but can be recovered
    when matching steps. *)
type registered_step = RegisteredStep : 'a step_kind -> registered_step

(** {1 Registration} *)

val register :
  step_type:step_type ->
  pattern:string ->
  location:step_location option ->
  handler:'a step_handler ->
  unit
(** Register a step definition.

    This function is typically called automatically by PPX-generated code, but
    can also be used manually.

    @param step_type The type of step (Given, When, or Then)
    @param pattern A regex pattern to match step text
    @param location Optional source location for error messages
    @param handler The function to execute when the step matches

    Example:
    {[
      register ~step_type:`Given ~pattern:"I have (\\d+) camels" ~location:None
        ~handler:(fun world groups args ->
          (* handler implementation *)
          (Some new_world, Outcome.Pass))
    ]}

    Raises Invalid_argument if the pattern is not a valid regex. *)

(** {1 Querying} *)

val get_steps_by_type : step_type -> registered_step list
(** Get all registered steps of a specific type.

    Returns steps in the order they were registered (most recent first). *)

val get_all_steps : unit -> registered_step list
(** Get all registered steps.

    Returns steps in the order they were registered (most recent first). *)

(** {1 Matching} *)

(** Result of finding a matching step *)
type 'a match_result =
  | NoMatch  (** No step matched the given text *)
  | Match of 'a step_handler * Re.Group.t option
      (** Exactly one step matched *)
  | Ambiguous of step_location option list
      (** Multiple steps matched (error case) *)

val find_step : string -> step_type -> 'a match_result
(** Find a matching step handler for the given step text and type.

    Returns:
    - [NoMatch] if no steps match
    - [Match (handler, groups)] if exactly one step matches
    - [Ambiguous locations] if multiple steps match

    The [groups] value contains the regex capture groups if the pattern had
    capturing groups.

    Example:
    {[
      match find_step "I have 5 camels" `Given with
      | Match (handler, groups) ->
          let world, outcome = handler None groups None in
          (* ... *)
      | NoMatch ->
          Printf.printf "No step defined for this text\n"
      | Ambiguous locs ->
          Printf.printf "Multiple steps match!\n"
    ]} *)

(** {1 Utilities} *)

val step_type_of_keyword : string -> step_type
(** Convert a Gherkin keyword to step type.

    Recognizes: "Given", "When", "Then" (case-insensitive)

    Raises Invalid_argument for "And", "But", "*" (these should inherit from
    the previous step) or for unknown keywords. *)

val clear : unit -> unit
(** Clear the registry.

    Useful for testing to ensure a clean state between test runs. *)

(** {1 Pattern Compilation} *)

val compile_pattern : string -> Re.re
(** Compile a pattern string into a regex.

    Raises Invalid_argument if the pattern is not valid Perl-style regex. *)

(** {1 Advanced} *)

(** Extract information from a registered step for debugging/reporting *)
val step_info : registered_step -> step_type * string * step_location option
(** Get the step type, pattern, and location from a registered step.

    Example:
    {[
      let steps = get_all_steps () in
      List.iter
        (fun step ->
          let stype, pattern, loc = step_info step in
          Printf.printf "%s: %s\n"
            (match stype with
            | `Given -> "Given"
            | `When -> "When"
            | `Then -> "Then")
            pattern)
        steps
    ]} *)
