# Effect Handlers and Async Integration in Cucumber.ml

This document explains how Cucumber.ml uses OCaml 5.x effect handlers to provide an ergonomic API, how the PPX automatically detects handler types, and how this design enables seamless integration with async runtimes like Eio and Lwt.

## Table of Contents

1. [PPX Signature Detection](#ppx-signature-detection)
2. [Code Comparison: Three Approaches](#code-comparison-three-approaches)
3. [Effect Handler Architecture](#effect-handler-architecture)
4. [Async Runtime Integration](#async-runtime-integration)
5. [Usage Examples](#usage-examples)

---

## PPX Signature Detection

Cucumber.ml's PPX automatically detects whether a step handler uses the classic API or the modern effect-based API by analyzing the function signature in the Abstract Syntax Tree (AST).

### Detection Mechanism

The `[@@given]`, `[@@when]`, and `[@@then]` attributes work with **both** handler styles:

**Classic Handler (3 parameters):**
```ocaml
let[@given "I have (\\d+) camels"] my_step world groups args =
  (* Signature: 'a option -> Re.Group.t option -> Step.arg option -> 'a option * Outcome.t *)
  match world with
  | Some state -> (Some state, Outcome.Pass)
  | None -> (None, Outcome.Fail)
```

**Effect Handler (zero parameters):**
```ocaml
let[@given "I have (\\d+) camels"] my_step () =
  (* Signature: unit -> unit *)
  let count = get_capture_int_exn 1 in
  set_world { camels = count }
```

### How Detection Works

In `ppx/ppx_cucumber.ml`, the `is_effect_handler` function examines the value binding's expression:

```ocaml
let is_effect_handler value_binding =
  match value_binding.pvb_expr.pexp_desc with
  | Pexp_fun (Nolabel, None, pat, _body) ->
      (* Check if first parameter is unit pattern () *)
      (match pat.ppat_desc with
      | Ppat_construct ({txt = Lident "()"; _}, None) -> true
      | _ -> false)
  | _ -> false
```

**Detection logic:**
1. If the function's first parameter is `()` (the unit pattern), it's an effect handler
2. Otherwise, it's a classic handler expecting `world groups args` parameters

### Code Generation

Based on detection, the PPX generates different wrapper code:

**For classic handlers:**
```ocaml
let () =
  Cucumber.Step_registry.register
    ~handler:(fun world groups args ->
      my_step world groups args)
```

**For effect handlers:**
```ocaml
let () =
  Cucumber.Step_registry.register
    ~handler:(fun world groups args ->
      let config = { Cucumber.Effects.world; groups; args; verbosity = 0 } in
      Cucumber.Effects.make_handler config my_step)
```

The effect handler is wrapped with `Cucumber.Effects.make_handler`, which sets up the effect handler context and converts the `unit -> unit` function to the expected `'a option * Outcome.t` return type.

---

## Code Comparison: Three Approaches

Let's compare the same step definition written in three different styles.

### Classic Builder API (62 lines)

```ocaml
open Cucumber

type farm = { camels : int }

let steps =
  empty
  |> set_dialect Cucumber.Dialect.En
  |> _Given (Re.Perl.compile_pat "I have (\\d+) camel on my farm")
       (fun state group args ->
         let no_camels =
           Option.bind group (fun g -> Re.Group.get_opt g 1)
           |> Option.map (fun f -> int_of_string_opt f)
           |> Option.join
         in
         match no_camels with
         | Some no_camels -> pass_with_state { camels = no_camels }
         | None -> fail)
  |> _When (Re.Perl.compile_pat "I buy (\\d+) more camels")
       (fun state group args ->
         let more_camels =
           Option.bind group (fun g -> Re.Group.get_opt g 1)
           |> Option.map (fun f -> int_of_string_opt f)
           |> Option.join |> Option.value ~default:0
         in
         let state =
           match state with None -> failwith "No state" | Some state -> state
         in
         pass_with_state { camels = state.camels + more_camels })
  |> _Then (Re.Perl.compile_pat "I have (\\d+) camels on my farm")
       (fun state group args ->
         let camels =
           Option.bind group (fun g -> Re.Group.get_opt g 1)
           |> Option.map (fun f -> int_of_string_opt f)
           |> Option.join |> Option.value ~default:0
         in
         let state =
           match state with None -> failwith "No state" | Some state -> state
         in
         if state.camels == camels then (Some state, Outcome.Pass)
         else (Some state, Outcome.Fail))

let () = execute steps
```

**Characteristics:**
- Manual regex compilation with `Re.Perl.compile_pat`
- Explicit state threading through parameters
- Builder pipeline (`_Given |> _When |> _Then`)
- Verbose Option handling chains
- Must explicitly return `(world option * Outcome.t)` tuples

### PPX Attributes (74 lines)

```ocaml
type farm = { camels : int }

let[@given "I have (\\d+) camel on my farm"] given_initial_camels world groups args =
  let count =
    Option.bind groups (fun g -> Re.Group.get_opt g 1)
    |> Option.map int_of_string_opt
    |> Option.join
  in
  match count with
  | Some n -> (Some { camels = n }, Cucumber.Outcome.Pass)
  | None -> (None, Cucumber.Outcome.Fail)

let[@when "I buy (\\d+) more camels"] when_buy_camels world groups args =
  let more =
    Option.bind groups (fun g -> Re.Group.get_opt g 1)
    |> Option.map int_of_string_opt
    |> Option.join |> Option.value ~default:0
  in
  match world with
  | Some farm ->
      (Some { camels = farm.camels + more }, Cucumber.Outcome.Pass)
  | None -> (None, Cucumber.Outcome.Fail)

let[@then "I have (\\d+) camels on my farm"] then_check_camels world groups args =
  let expected =
    Option.bind groups (fun g -> Re.Group.get_opt g 1)
    |> Option.map int_of_string_opt
    |> Option.join |> Option.value ~default:0
  in
  match world with
  | Some farm when farm.camels = expected ->
      (Some farm, Cucumber.Outcome.Pass)
  | Some farm -> (Some farm, Cucumber.Outcome.Fail)
  | None -> (None, Cucumber.Outcome.Fail)

let () = Cucumber.execute_from_registry ()
```

**Improvements over classic:**
- No manual regex compilation (pattern in attribute)
- Steps auto-register at module initialization
- No builder pipeline needed
- Still requires Option handling and tuple returns

### PPX + Effect Handlers (37 lines - 50% reduction!)

```ocaml
open Cucumber.Effects

type farm = { camels : int }

let[@given "I have (\\d+) camel on my farm"] given_initial_camels () =
  let count = get_capture_int_exn 1 in
  set_world { camels = count }

let[@when "I buy (\\d+) more camels"] when_buy_camels () =
  let more = get_capture_int_exn 1 in
  let farm = Option.get (get_world ()) in
  set_world { camels = farm.camels + more }

let[@then "I have (\\d+) camels on my farm"] then_check_camels () =
  let expected = get_capture_int_exn 1 in
  let farm = Option.get (get_world ()) in
  assert_equal ~to_string:string_of_int expected farm.camels

let () = Cucumber.execute_from_registry ()
```

**Improvements over PPX attributes:**
- **50% less code** (74 lines → 37 lines)
- No manual Option.bind chains
- Implicit state management via effects (`get_world`, `set_world`)
- No explicit return tuples
- Exception-based error handling (`get_capture_int_exn`)
- Functions are just `unit -> unit` - maximally simple

### Comparison Table

| Aspect | Classic | PPX Attributes | PPX + Effects |
|--------|---------|----------------|---------------|
| Lines of code | 62 | 74 | **37** |
| State management | Explicit tuples | Explicit tuples | **Implicit (effects)** |
| Option handling | Manual chains | Manual chains | **Helpers (`_exn`)** |
| Error handling | `(None, Fail)` | `(None, Fail)` | **`fail "msg"`** |
| Registration | Manual pipeline | **Automatic** | **Automatic** |
| Regex compilation | Manual | **Automatic** | **Automatic** |
| Handler signature | 3 params + tuple | 3 params + tuple | **`unit -> unit`** |
| Readability | Low | Medium | **High** |

---

## Effect Handler Architecture

### Effect Types

Cucumber.ml defines several effects in `lib/effects.mli`:

```ocaml
type _ Effect.t +=
  | GetWorld : 'a option Effect.t
  | SetWorld : 'a -> unit Effect.t
  | GetCapture : int -> string option Effect.t
  | AssertEqual : 'b * 'b * ('b -> 'b -> bool) * ('b -> string) -> unit Effect.t
  | Fail : string -> 'a Effect.t
  | Log : string -> unit Effect.t
  (* ... and more *)
```

### Helper Functions

Users typically interact with effects through helper functions:

```ocaml
val get_world : unit -> 'a option
val set_world : 'a -> unit
val get_capture : int -> string option
val get_capture_int_exn : int -> int
val assert_equal : ?eq:('a -> 'a -> bool) -> to_string:('a -> string) -> 'a -> 'a -> unit
val fail : string -> 'a
```

These helpers perform the effects and handle the results:

```ocaml
let get_world () = Effect.perform GetWorld
let set_world world = Effect.perform (SetWorld world)

let get_capture_int_exn n =
  match Effect.perform (GetCapture n) with
  | Some s -> int_of_string s
  | None -> failwith (Printf.sprintf "Capture group %d not found" n)
```

### The Effect Handler

The `run_with_effects` function in `lib/effects.ml` sets up the effect handler context:

```ocaml
let run_with_effects config f =
  let current_world = ref None in
  let current_outcome = ref Outcome.Pass in
  let logs = ref [] in

  let handler = {
    retc = (fun () -> ());
    exnc = (fun ex -> (* handle exceptions *));
    effc = (fun (type a) (eff : a Effect.t) ->
      match eff with
      | GetWorld ->
          Some (fun k -> continue k !current_world)
      | SetWorld w ->
          Some (fun k -> current_world := Some w; continue k ())
      | GetCapture n ->
          Some (fun k ->
            let result = Option.bind config.groups (fun g -> Re.Group.get_opt g n) in
            continue k result)
      | AssertEqual (expected, actual, eq, to_string) ->
          Some (fun k ->
            if not (eq expected actual) then (
              current_outcome := Outcome.Fail;
              discontinue k (Failure "Assertion failed"))
            else continue k ())
      (* ... handle other effects ... *)
      | _ -> None  (* ← KEY: unhandled effects bubble up! *)
    )
  } in

  Effect.Deep.match_with f () handler;
  (!current_world, !current_outcome, !logs)
```

**Key design points:**

1. **Local state**: World, outcome, and logs are stored in refs within the handler scope
2. **Effect handling**: Each Cucumber effect is matched and handled appropriately
3. **Unhandled effects**: Returning `None` allows effects to bubble up to outer handlers
4. **Continuation management**: Uses `continue` for normal flow, `discontinue` for failures

---

## Async Runtime Integration

The most powerful aspect of OCaml 5.x effects is **effect composability**: multiple effect handlers can be nested, and unhandled effects automatically propagate to outer handlers.

### Effect Bubbling Architecture

```
[User Step Code]
    ↓ performs Cucumber.Effects (GetWorld, AssertEqual, etc.)
    ↓ performs Eio.Net effects (Read, Write, Sleep, etc.)
    ↓
[Cucumber Effect Handler] ← handles GetWorld, SetWorld, etc.
    ↓ returns None for unrecognized effects
    ↓ bubbles unhandled effects upward
    ↓
[Eio Runtime Handler] ← handles Read, Write, Sleep, etc.
    ↓ performs actual I/O operations
    ↓ resumes continuations
    ↓
[Operating System]
```

This architecture means:
- **Zero overhead** for async integration (no explicit wrapping needed)
- **Clean separation** of concerns (testing logic vs I/O runtime)
- **Type-safe composition** (effect types checked at compile time)
- **Works with any effect-based library** (not just Eio/Lwt)

### Integration Pattern 1: Eio Inside Steps

Steps can perform async I/O directly - Eio effects bubble through Cucumber's handler:

```ocaml
open Cucumber.Effects

let[@given "I fetch user data from API"] fetch_user_data () =
  (* Access Eio environment from context *)
  let env = get_eio_env () in

  (* Eio.Net effects bubble through Cucumber's effect handler *)
  let response =
    Eio.Net.with_tcp_connect ~host:"api.example.com" ~service:"https" env#net
      (fun flow ->
        Eio.Flow.copy_string "GET /users HTTP/1.1\r\n\r\n" flow;
        Eio.Flow.read_all flow) in

  set_world (parse_user_data response)
```

**How it works:**
1. User calls `Eio.Net.with_tcp_connect` which performs an `Eio.Net.Connect` effect
2. Cucumber's `effc` doesn't recognize this effect → returns `None`
3. Effect bubbles up to Eio's runtime handler
4. Eio performs async I/O and resumes the continuation
5. Control returns to the step, which continues normally

### Integration Pattern 2: Running Tests Inside Async Runtime

The test execution must be launched within the async runtime context:

```ocaml
(* Without async runtime: *)
let () = Cucumber.execute_from_registry ()

(* With Eio: *)
let () =
  Eio_main.run @@ fun env ->
  (* Tests run inside Eio's effect handler *)
  Cucumber.Lib.execute_from_registry ()
```

Because Cucumber's effect handler is **nested inside** Eio's handler, any Eio effects performed in steps will automatically bubble up to Eio for handling.

### Integration Pattern 3: Async World Setup/Teardown

Hooks can perform async operations using the same bubbling mechanism:

```ocaml
[@@before_scenario]
let setup_database () =
  (* Start test database with Eio *)
  let env = get_eio_env () in
  let db_process = Eio.Process.spawn ~sw:env#sw ["docker"; "run"; "postgres"] in

  (* Wait for database to be ready *)
  Eio.Time.sleep env#clock 2.0;

  let connection = Database.connect "localhost:5432" in
  set_world { db_connection = connection }

[@@after_scenario]
let cleanup_database () =
  let world = get_world () |> Option.get in
  Database.close world.db_connection;
  (* Eio will clean up the spawned process via switch *)
```

### Why This Works Seamlessly

OCaml 5.x effect handlers are designed for exactly this kind of composition:

1. **Handlers are first-class**: Can be nested arbitrarily deep
2. **Effects are typed**: Compiler ensures type safety across handler boundaries
3. **Unhandled effects propagate**: `effc` returning `None` passes effect to outer handler
4. **Continuations are composable**: Multiple handlers can intercept and resume the same continuation

This means you get **free async integration** - no need for:
- Explicit monad transformers
- Manual async/await lifting
- Runtime-specific wrapper code
- Sacrificing type safety

---

## Usage Examples

### Basic Step with Effects

```ocaml
open Cucumber.Effects

type world = { counter : int }

let[@given "the counter starts at {int}"] given_counter () =
  let initial = get_capture_int_exn 1 in
  set_world { counter = initial }

let[@when "I increment the counter"] when_increment () =
  let w = get_world () |> Option.get in
  set_world { counter = w.counter + 1 }

let[@then "the counter should be {int}"] then_counter_value () =
  let expected = get_capture_int_exn 1 in
  let w = get_world () |> Option.get in
  assert_equal ~to_string:string_of_int expected w.counter

let () = Cucumber.execute_from_registry ()
```

### Step with Custom Assertions

```ocaml
let[@then "the user should have role {string}"] then_user_role () =
  let expected_role = get_capture_string_exn 1 in
  let user = get_world () |> Option.get in

  (* Custom equality check *)
  assert_equal
    ~eq:String.equal
    ~to_string:(fun s -> s)
    expected_role
    user.role
```

### Step with Logging

```ocaml
let[@when "I perform complex calculation"] when_calculate () =
  log "Starting calculation...";
  let x = compute_expensive_value () in
  debug (Printf.sprintf "Intermediate result: %d" x);

  let result = x * 2 + 5 in
  info (Printf.sprintf "Final result: %d" result);

  set_world { calculation_result = result }
```

### Step with Conditional Failure

```ocaml
let[@when "I try to withdraw {int} dollars"] when_withdraw () =
  let amount = get_capture_int_exn 1 in
  let account = get_world () |> Option.get in

  if amount > account.balance then
    fail "Insufficient funds"
  else
    set_world { account with balance = account.balance - amount }
```

### Step with Eio (Async I/O)

```ocaml
let[@given "the API server is running"] given_api_server () =
  let env = get_eio_env () in

  (* Check if server is reachable - uses Eio effects *)
  let is_up =
    Eio.Net.with_tcp_connect ~host:"localhost" ~service:"8080" env#net
      (fun _flow -> true) in

  if not is_up then
    fail "API server not reachable"

let[@when "I send GET request to {string}"] when_http_get () =
  let path = get_capture_string_exn 1 in
  let env = get_eio_env () in

  (* Perform HTTP request using Eio *)
  let response = Http_client.get env path in

  let w = get_world () |> Option.get in
  set_world { w with last_response = Some response }
```

### Complete Eio Example

```ocaml
(* world.ml *)
type world = {
  eio_env : Eio_unix.Stdenv.base;
  http_responses : (string * int) list;
}

(* steps.ml *)
open Cucumber.Effects

let[@given "the test environment is set up"] setup () =
  (* Eio environment is available via effect bubbling *)
  let env = get_eio_env () in
  set_world { eio_env = env; http_responses = [] }

let[@when "I make a request to {string}"] make_request () =
  let url = get_capture_string_exn 1 in
  let w = get_world () |> Option.get in

  (* Eio HTTP request - effects bubble to Eio runtime *)
  Eio.Switch.run @@ fun sw ->
    let client = Cohttp_eio.Client.make ~https:None w.eio_env#net in
    let resp, _body = Cohttp_eio.Client.get client (Uri.of_string url) in
    let status = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in

    set_world { w with http_responses = (url, status) :: w.http_responses }

let[@then "the response status should be {int}"] check_status () =
  let expected = get_capture_int_exn 1 in
  let w = get_world () |> Option.get in

  match w.http_responses with
  | (_, actual) :: _ ->
      assert_equal ~to_string:string_of_int expected actual
  | [] ->
      fail "No HTTP responses recorded"

(* main.ml *)
let () =
  (* Run tests inside Eio runtime - enables effect bubbling *)
  Eio_main.run @@ fun env ->

  (* Make Eio environment available to steps via effect *)
  Cucumber.Effects.with_eio_env env @@ fun () ->
  Cucumber.execute_from_registry ()
```

---

## Future Enhancements

### Extension Point Syntax (Planned)

In the future, we plan to support extension point syntax (`let%given`) for even cleaner code:

```ocaml
let%given "I have {int} camels" =
  let count = get_capture_int_exn 1 in
  set_world { camels = count }

let%then "I should have {int} camels" =
  let expected = get_capture_int_exn 1 in
  let world = get_world () |> Option.get in
  assert_equal ~to_string:string_of_int expected world.camels
```

This would eliminate the need for explicit function definitions and make steps even more concise.

### Full Async Runtime Integration

Full first-class support for Eio and Lwt with:

```ocaml
(* Helper to access Eio environment *)
val get_eio_env : unit -> Eio_unix.Stdenv.base

(* Helper to access Lwt runtime *)
val with_lwt : (unit -> 'a Lwt.t) -> 'a

(* Async-aware test execution *)
val execute_from_registry_eio : Eio_unix.Stdenv.base -> unit -> unit
val execute_from_registry_lwt : unit -> unit Lwt.t
```

These would use OCaml 5.x Domain-local State to store runtime environments and provide seamless access in step definitions.

---

## Summary

**Key Takeaways:**

1. **Automatic Detection**: PPX analyzes function signatures to choose appropriate wrapper
   - `fun () -> ...` → Effect handler (wrapped with `make_handler`)
   - `fun world groups args -> ...` → Classic handler (direct pass-through)

2. **Massive Code Reduction**: Effect handlers reduce boilerplate by ~50%
   - No manual Option chains
   - No explicit state threading
   - No tuple return values

3. **Seamless Async**: Effect bubbling enables zero-overhead async integration
   - Works with Eio, Lwt, or any effect-based runtime
   - No monad transformers needed
   - Type-safe composition

4. **Backward Compatible**: Classic handlers still work - choose your style
   - Migrate incrementally
   - Mix styles in same codebase
   - No breaking changes

The combination of PPX attributes and effect handlers makes Cucumber.ml one of the most ergonomic BDD frameworks in any language, while OCaml 5.x effects enable natural integration with modern async runtimes.
