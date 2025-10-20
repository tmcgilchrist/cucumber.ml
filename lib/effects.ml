(** Effect-based API for Cucumber step definitions using OCaml 5.x effect
    handlers *)

open Effect
open Effect.Deep

(** {1 Effect Type Definitions} *)

type _ Effect.t +=
  | GetWorld : 'a option Effect.t
  | SetWorld : 'a -> unit Effect.t
  | GetGroups : Re.Group.t option Effect.t
  | GetCapture : int -> string option Effect.t
  | GetArgs : Step.arg option Effect.t
  | AssertTrue : bool * string -> unit Effect.t
  | AssertEqual : 'b * 'b * ('b -> 'b -> bool) * ('b -> string) -> unit Effect.t
  | Fail : string -> 'a Effect.t
  | Skip : string -> 'a Effect.t
  | Pending : string -> 'a Effect.t
  | Log : string -> unit Effect.t
  | Debug : string -> unit Effect.t
  | Info : string -> unit Effect.t
  | Warn : string -> unit Effect.t
  | BeforeScenario : (Pickle.t -> unit) -> unit Effect.t
  | AfterScenario : (Pickle.t -> unit) -> unit Effect.t
  | BeforeStep : (Step.t -> unit) -> unit Effect.t
  | AfterStep : (Step.t -> Outcome.t -> unit) -> unit Effect.t

(** {1 World State Management} *)

let get_world () = perform GetWorld
let set_world w = perform (SetWorld w)

let update_world f =
  match get_world () with
  | Some w -> set_world (f w)
  | None -> failwith "Cannot update_world: no world state exists"

(** {1 Step Data Access} *)

let get_groups () = perform GetGroups
let get_capture n = perform (GetCapture n)

let get_capture_exn n =
  match get_capture n with
  | Some s -> s
  | None -> failwith (Printf.sprintf "Capture group %d not found" n)

let get_capture_int n =
  match get_capture n with Some s -> int_of_string_opt s | None -> None

let get_capture_int_exn n =
  match get_capture_int n with
  | Some i -> i
  | None ->
      failwith
        (Printf.sprintf "Capture group %d not found or not a valid integer" n)

let get_capture_float n =
  match get_capture n with Some s -> float_of_string_opt s | None -> None

let get_capture_float_exn n =
  match get_capture_float n with
  | Some f -> f
  | None ->
      failwith
        (Printf.sprintf "Capture group %d not found or not a valid float" n)

let get_args () = perform GetArgs

let get_table () =
  match get_args () with Some (Step.Table t) -> Some t | _ -> None

let get_docstring () =
  match get_args () with Some (Step.DocString d) -> Some d | _ -> None

(** {1 Assertions} *)

let assert_true ?(msg = "Assertion failed") cond =
  perform (AssertTrue (cond, msg))

let assert_false ?(msg = "Assertion failed") cond = assert_true ~msg (not cond)

let assert_equal ?(eq = ( = )) ~to_string expected actual =
  perform (AssertEqual (expected, actual, eq, to_string))

let assert_not_equal ?(eq = ( = )) ~to_string expected actual =
  if eq expected actual then
    failwith
      (Printf.sprintf "Values should not be equal: %s" (to_string expected))

(** {1 Test Control Flow} *)

let fail msg = perform (Fail msg)
let skip msg = perform (Skip msg)
let pending msg = perform (Pending msg)

(** {1 Logging} *)

let log msg = perform (Log msg)
let debug msg = perform (Debug msg)
let info msg = perform (Info msg)
let warn msg = perform (Warn msg)
let logf fmt = Printf.ksprintf log fmt
let debugf fmt = Printf.ksprintf debug fmt
let infof fmt = Printf.ksprintf info fmt
let warnf fmt = Printf.ksprintf warn fmt

(** {1 Hooks} *)

let before_scenario hook = perform (BeforeScenario hook)
let after_scenario hook = perform (AfterScenario hook)
let before_step hook = perform (BeforeStep hook)
let after_step hook = perform (AfterStep hook)

(** {1 Effect Handler Implementation} *)

type 'a handler_config = {
  world : 'a option;
  groups : Re.Group.t option;
  args : Step.arg option;
  verbosity : int;
}

type hooks = {
  before_scenario : (Pickle.t -> unit) list;
  after_scenario : (Pickle.t -> unit) list;
  before_step : (Step.t -> unit) list;
  after_step : (Step.t -> Outcome.t -> unit) list;
}

type 'a step_result = {
  world : 'a option;
  outcome : Outcome.t;
  logs : (string * int) list;
  hooks : hooks;
}

let run_with_effects (config : 'a handler_config) (f : unit -> unit) :
    'a step_result =
  (* Mutable state for the handler *)
  let current_world = ref config.world in
  let current_outcome = ref Outcome.Pass in
  let logs = ref [] in
  let hooks_ref =
    ref
      {
        before_scenario = [];
        after_scenario = [];
        before_step = [];
        after_step = [];
      }
  in

  (* Helper to add log message *)
  let add_log msg level =
    if level <= config.verbosity then (
      logs := (msg, level) :: !logs;
      (* Also print to stdout *)
      print_endline msg;
      flush stdout)
  in

  (* Effect handler *)
  let handler =
    {
      retc = (fun () -> ());
      exnc =
        (fun ex ->
          match ex with
          | Failure msg ->
              (* If outcome wasn't already set, set it to Fail *)
              if !current_outcome = Outcome.Pass then
                current_outcome := Outcome.Fail;
              add_log (Printf.sprintf "Error: %s" msg) 0
          | ex ->
              current_outcome := Outcome.Fail;
              add_log (Printf.sprintf "Exception: %s" (Printexc.to_string ex)) 0);
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | GetWorld ->
              Some
                (fun (k : (a, _) continuation) ->
                  let w : a = Obj.magic !current_world in
                  continue k w)
          | SetWorld w ->
              Some
                (fun k ->
                  current_world := Some (Obj.magic w);
                  continue k ())
          | GetGroups -> Some (fun k -> continue k config.groups)
          | GetCapture n ->
              Some
                (fun k ->
                  let result =
                    Option.bind config.groups (fun g -> Re.Group.get_opt g n)
                  in
                  continue k result)
          | GetArgs -> Some (fun k -> continue k config.args)
          | AssertTrue (cond, msg) ->
              Some
                (fun k ->
                  if not cond then (
                    current_outcome := Outcome.Fail;
                    add_log (Printf.sprintf "Assertion failed: %s" msg) 0;
                    discontinue k (Failure msg))
                  else continue k ())
          | AssertEqual (expected, actual, eq, to_string) ->
              Some
                (fun k ->
                  if not (eq expected actual) then (
                    current_outcome := Outcome.Fail;
                    let msg =
                      Printf.sprintf "Expected: %s\nActual: %s"
                        (to_string expected) (to_string actual)
                    in
                    add_log (Printf.sprintf "Assertion failed:\n%s" msg) 0;
                    discontinue k (Failure msg))
                  else continue k ())
          | Fail msg ->
              Some
                (fun k ->
                  current_outcome := Outcome.Fail;
                  add_log (Printf.sprintf "Failed: %s" msg) 0;
                  discontinue k (Failure msg))
          | Skip msg ->
              Some
                (fun k ->
                  current_outcome := Outcome.Skip;
                  add_log (Printf.sprintf "Skipped: %s" msg) 0;
                  discontinue k (Failure msg))
          | Pending msg ->
              Some
                (fun k ->
                  current_outcome := Outcome.Pending;
                  add_log (Printf.sprintf "Pending: %s" msg) 0;
                  discontinue k (Failure msg))
          | Log msg ->
              Some
                (fun k ->
                  add_log msg 0;
                  continue k ())
          | Debug msg ->
              Some
                (fun k ->
                  add_log (Printf.sprintf "[DEBUG] %s" msg) 2;
                  continue k ())
          | Info msg ->
              Some
                (fun k ->
                  add_log (Printf.sprintf "[INFO] %s" msg) 1;
                  continue k ())
          | Warn msg ->
              Some
                (fun k ->
                  add_log (Printf.sprintf "[WARN] %s" msg) 0;
                  continue k ())
          | BeforeScenario hook ->
              Some
                (fun k ->
                  hooks_ref :=
                    {
                      !hooks_ref with
                      before_scenario = hook :: !hooks_ref.before_scenario;
                    };
                  continue k ())
          | AfterScenario hook ->
              Some
                (fun k ->
                  hooks_ref :=
                    {
                      !hooks_ref with
                      after_scenario = hook :: !hooks_ref.after_scenario;
                    };
                  continue k ())
          | BeforeStep hook ->
              Some
                (fun k ->
                  hooks_ref :=
                    {
                      !hooks_ref with
                      before_step = hook :: !hooks_ref.before_step;
                    };
                  continue k ())
          | AfterStep hook ->
              Some
                (fun k ->
                  hooks_ref :=
                    {
                      !hooks_ref with
                      after_step = hook :: !hooks_ref.after_step;
                    };
                  continue k ())
          | _ -> None);
    }
  in

  (* Run the step function with the effect handler *)
  match_with f () handler;

  (* Return the result *)
  {
    world = !current_world;
    outcome = !current_outcome;
    logs = List.rev !logs;
    hooks = !hooks_ref;
  }

let make_handler (config : 'a handler_config) (f : unit -> unit) :
    'a option * Outcome.t =
  let result = run_with_effects config f in
  (result.world, result.outcome)
