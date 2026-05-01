(** Effect-based API for Cucumber step definitions.

    This module provides an ergonomic API for writing step definitions using
    OCaml 5.x effect handlers. Step functions can use effects to access the test
    world state, regex captures, and control test flow without manually
    threading state through function parameters.

    Example:
    {[
      let%given "I have (\\d+) camels" =
        let count = get_capture 1 |> Option.get |> int_of_string in
        set_world { camels = count }

      let%then "I should have (\\d+) camels" =
        let expected = get_capture 1 |> Option.get |> int_of_string in
        let world = get_world () |> Option.get in
        assert_equal expected world.camels ~to_string:string_of_int
    ]} *)
(* TODO Add example for how to run PPX steps from main function. *)

(** {1 Effect Types} *)

(** The effect type for Cucumber operations. Users typically don't use this
    directly, but instead use the helper functions like [get_world],
    [set_world], etc. *)
type _ Effect.t +=
  | GetWorld : 'a option Effect.t  (** Get the current world state *)
  | SetWorld : 'a -> unit Effect.t  (** Set the world state *)
  | GetGroups : Re.Group.t option Effect.t
        (** Get regex match groups from the step pattern *)
  | GetCapture : int -> string option Effect.t
        (** Get a specific regex capture group by index *)
  | GetArgs : Step.arg option Effect.t
        (** Get step arguments (tables, docstrings) *)
  | AssertTrue : bool * string -> unit Effect.t
        (** Assert a condition is true, failing the test with message if false
        *)
  | AssertEqual : 'b * 'b * ('b -> 'b -> bool) * ('b -> string) -> unit Effect.t
        (** Assert two values are equal using custom equality and formatter *)
  | Fail : string -> 'a Effect.t  (** Fail the test with a message *)
  | Skip : string -> 'a Effect.t  (** Skip the test with a reason *)
  | Pending : string -> 'a Effect.t
        (** Mark the test as pending with a reason *)
  | Log : string -> unit Effect.t  (** Log a message during test execution *)
  | Debug : string -> unit Effect.t  (** Log a debug message (shown with -vv) *)
  | Info : string -> unit Effect.t  (** Log an info message (shown with -v) *)
  | Warn : string -> unit Effect.t  (** Log a warning message *)
  | BeforeScenario : (Pickle.t -> unit) -> unit Effect.t
        (** Register a before scenario hook *)
  | AfterScenario : (Pickle.t -> unit) -> unit Effect.t
        (** Register an after scenario hook *)
  | BeforeStep : (Step.t -> unit) -> unit Effect.t
        (** Register a before step hook *)
  | AfterStep : (Step.t -> Outcome.t -> unit) -> unit Effect.t
        (** Register an after step hook *)

(** {1 World State Management} *)

val get_world : unit -> 'a option
(** Get the current world state. Returns [None] if no state has been set yet.

    Example:
    {[
      let world = get_world () in
      match world with
      | Some { camels } -> log (Printf.sprintf "We have %d camels" camels)
      | None -> fail "No world state initialized"
    ]} *)

val set_world : 'a -> unit
(** Set the world state. This state will be available to subsequent steps.

    Example:
    {[
      set_world { camels = 5; chickens = 10 }
    ]} *)

val update_world : ('a -> 'a) -> unit
(** Update the world state using a function. Fails if no world state exists.

    Example:
    {[
      update_world (fun w -> { w with camels = w.camels + 1 })
    ]} *)

(** {1 Step Data Access} *)

val get_groups : unit -> Re.Group.t option
(** Get the regex match groups from the current step's pattern. *)

val get_capture : int -> string option
(** Get a specific regex capture group by index (1-based).

    Example:
    {[
      let count_str = get_capture 1 in
      match count_str with
      | Some s -> int_of_string s
      | None -> fail "No capture group found"
    ]} *)

val get_capture_exn : int -> string
(** Like [get_capture] but raises [Failure] if the capture group doesn't exist.
*)

val get_capture_int : int -> int option
(** Get a capture group and parse it as an integer. *)

val get_capture_int_exn : int -> int
(** Like [get_capture_int] but raises [Failure] if parsing fails. *)

val get_capture_float : int -> float option
(** Get a capture group and parse it as a float. *)

val get_capture_float_exn : int -> float
(** Like [get_capture_float] but raises [Failure] if parsing fails. *)

val get_args : unit -> Step.arg option
(** Get step arguments (data tables or docstrings). *)

val get_table : unit -> Table.t option
(** Get the data table attached to this step, if any. *)

val get_docstring : unit -> Docstring.t option
(** Get the docstring attached to this step, if any. *)

(** {1 Assertions} *)

val assert_true : ?msg:string -> bool -> unit
(** Assert that a condition is true. If false, fails the test with the given
    message.

    Example:
    {[
      assert_true ~msg:"Expected positive camels" (camels > 0)
    ]} *)

val assert_false : ?msg:string -> bool -> unit
(** Assert that a condition is false. *)

val assert_equal :
  ?eq:('a -> 'a -> bool) -> to_string:('a -> string) -> 'a -> 'a -> unit
(** Assert that two values are equal.

    Example:
    {[
      assert_equal ~to_string:string_of_int 5 actual_count
    ]}

    @param eq Custom equality function (default is [Stdlib.(=)])
    @param to_string Function to convert values to strings for error messages *)

val assert_not_equal :
  ?eq:('a -> 'a -> bool) -> to_string:('a -> string) -> 'a -> 'a -> unit
(** Assert that two values are not equal. *)

(** {1 Test Control Flow} *)

val fail : string -> 'a
(** Fail the current test with a message.

    Example:
    {[
      if camels < 0 then fail "Cannot have negative camels"
    ]} *)

val skip : string -> 'a
(** Skip the current test with a reason. *)

val pending : string -> 'a
(** Mark the current test as pending (not yet implemented). *)

(** {1 Logging} *)

val log : string -> unit
(** Log a message during test execution. Always visible. *)

val debug : string -> unit
(** Log a debug message. Only visible with [-vv] verbosity. *)

val info : string -> unit
(** Log an info message. Visible with [-v] verbosity. *)

val warn : string -> unit
(** Log a warning message. Always visible. *)

val logf : ('a, unit, string, unit) format4 -> 'a
(** Printf-style logging. *)

val debugf : ('a, unit, string, unit) format4 -> 'a
(** Printf-style debug logging. *)

val infof : ('a, unit, string, unit) format4 -> 'a
(** Printf-style info logging. *)

val warnf : ('a, unit, string, unit) format4 -> 'a
(** Printf-style warning logging. *)

(** {1 Hooks} *)

val before_scenario : (Pickle.t -> unit) -> unit
(** Register a hook to run before each scenario. *)

val after_scenario : (Pickle.t -> unit) -> unit
(** Register a hook to run after each scenario. *)

val before_step : (Step.t -> unit) -> unit
(** Register a hook to run before each step. *)

val after_step : (Step.t -> Outcome.t -> unit) -> unit
(** Register a hook to run after each step with its outcome. *)

(** {1 Effect Handler Runner} *)

type 'a handler_config = {
  world : 'a option;  (** Initial world state *)
  groups : Re.Group.t option;  (** Regex match groups *)
  args : Step.arg option;  (** Step arguments *)
  verbosity : int;
      (** Verbosity level for logging (0=normal, 1=info, 2=debug) *)
}
(** Configuration for the effect handler *)

type 'a step_result = {
  world : 'a option;  (** Final world state *)
  outcome : Outcome.t;  (** Test outcome *)
  logs : (string * int) list;
      (** Collected log messages with verbosity levels *)
  hooks : hooks;  (** Hooks registered during execution *)
}
(** Result of running a step with effects *)

and hooks = {
  before_scenario : (Pickle.t -> unit) list;
  after_scenario : (Pickle.t -> unit) list;
  before_step : (Step.t -> unit) list;
  after_step : (Step.t -> Outcome.t -> unit) list;
}
(** Hooks collected during step execution *)

val run_with_effects : 'a handler_config -> (unit -> unit) -> 'a step_result
(** Run a step function with the effect handler.

    This is typically called by the PPX-generated code, not by users directly.

    Example:
    {[
      let config =
        {
          world = Some { camels = 5 };
          groups = Some match_groups;
          args = None;
          verbosity = 0;
        }
      in
      let result =
        run_with_effects config (fun () ->
            let count = get_capture_int_exn 1 in
            update_world (fun w -> { w with camels = w.camels + count }))
      in
      match result.outcome with
      | Pass -> Printf.printf "Test passed!\n"
      | Fail -> Printf.printf "Test failed!\n"
      | _ -> ()
    ]} *)

val make_handler : 'a handler_config -> (unit -> unit) -> 'a option * Outcome.t
(** Create a handler function compatible with the step registry.

    This converts an effect-based step function into a classic handler with
    signature:
    ['a option -> Re.Group.t option -> Step.arg option -> 'a option * Outcome.t]

    Used by the PPX to wrap effect-based steps for registration. *)
