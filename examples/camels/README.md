# Camel Farm Example

This example demonstrates two approaches to writing Cucumber tests in OCaml: the **classic builder-based API** and the **PPX attributes API**.

## The Feature

Both examples implement the same Gherkin feature (`camels.feature`):

```gherkin
Feature: Dromedary farm

@smoke
Scenario: Buy more camels
  Given I have 1 camel on my farm
  When I buy 2 more camels
  Then I have 3 camels on my farm

@wip
Scenario: Sell some camels
  Given I have 1 camel on my farm
  When I sell 1 camels
  Then I have 0 camels on my farm
```

## Approach Comparison

### Classic API (`classic.ml`)

The traditional builder-based approach using:
- Manual regex compilation with `Re.Perl.compile_pat`
- Explicit state threading through function parameters
- Builder pipeline: `empty |> _Given |> _When |> _Then`
- Verbose `Option.bind` chains for regex capture extraction
- Manual state unwrapping with pattern matching

**Lines of code:** 56

**Example step definition:**
```ocaml
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
```

### PPX Attributes API (`ppx_attributes.ml`)

The PPX-enhanced approach using:
- PPX attributes: `let[@given "pattern"]`, `let[@when "pattern"]`, `let[@then "pattern"]`
- Automatic step registration at module initialization
- Pattern strings in attributes (no manual `Re.Perl.compile_pat`)
- No builder pipeline needed

**Lines of code:** 45 (~20% reduction)

**Example step definition:**
```ocaml
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
```

**Note:** Effect handlers (with `get_world()`, `set_world()`, etc.) are fully supported with PPX attributes - see `ppx_effects.ml`.

## Key Improvements

| Feature | Classic | PPX Attributes |
|---------|---------|----------------|
| **Code Verbosity** | 56 lines | 45 lines |
| **Regex Compilation** | Manual `Re.Perl.compile_pat` | Pattern in attribute string |
| **State Management** | Manual threading via parameters | Still manual |
| **Step Registration** | Builder pipeline | Automatic via attributes |
| **Error Location** | Runtime errors only | File:line:column from PPX |
| **Boilerplate** | Builder pipeline | Attributes only |
| **Type Safety** | Full | Full |

## Building and Running

### Build both versions:
```bash
dune build
```

### Run classic version:
```bash
dune exec -- classic camels.feature
```

### Run PPX version:
```bash
dune exec -- ppx_attributes camels.feature
```

### Run with tags:
```bash
# Run only smoke tests
dune exec -- ppx_attributes --tags @smoke camels.feature

# Skip wip tests
dune exec -- ppx_attributes --tags "~@wip" camels.feature
```

## Migration Guide

Converting from classic to PPX attributes:

### 1. Convert step definitions:

**Before (Builder Pipeline):**
```ocaml
let steps =
  empty
  |> _Given (Re.Perl.compile_pat "I have (\\d+) camel on my farm")
       (fun state group args ->
         let count =
           Option.bind group (fun g -> Re.Group.get_opt g 1)
           |> Option.map int_of_string_opt
           |> Option.join
         in
         match count with
         | Some n -> pass_with_state { camels = n }
         | None -> fail)
```

**After (PPX Attributes):**
```ocaml
let[@given "I have (\\d+) camel on my farm"] given_initial_camels world groups args =
  let count =
    Option.bind groups (fun g -> Re.Group.get_opt g 1)
    |> Option.map int_of_string_opt
    |> Option.join
  in
  match count with
  | Some n -> (Some { camels = n }, Cucumber.Outcome.Pass)
  | None -> (None, Cucumber.Outcome.Fail)
```

### 2. Change execution:

**Before:**
```ocaml
let steps = empty |> _Given ... |> _When ... |> _Then ...
let () = execute steps
```

**After:**
```ocaml
(* Steps auto-register via PPX attributes *)
let () = Cucumber.execute_from_registry ()
```

### 3. Update dune file:

Add PPX preprocessing:
```lisp
(executable
 (name my_test)
 (libraries cucumber)
 (preprocess
  (pps ppx_cucumber)))
```

## Future: Effect Handler API

A more ergonomic effect-based API is planned for a future release using extension points (`let%given`):

```ocaml
(* Future syntax - not yet available *)
let%given "I have (\\d+) camels" =
  let count = get_capture_int_exn 1 in
  set_world { camels = count }

let%when "I buy (\\d+) more camels" =
  let more = get_capture_int_exn 1 in
  update_world (fun w -> { w with camels = w.camels + more })

let%then "I should have (\\d+) camels" =
  let expected = get_capture_int_exn 1 in
  let world = get_world () |> Option.get in
  assert_equal ~to_string:string_of_int expected world.camels
```

This will provide:
- Implicit state management via `get_world()`/`set_world()`
- Helper functions: `get_capture_int_exn`, `assert_equal`, etc.
- Even cleaner, more readable code
- ~50% less code than classic approach

## Requirements

- OCaml >= 5.0.0 (for effect handlers)
- Dune >= 3.2
- ppx_cucumber package (for PPX version)

## Learn More

- [Cucumber.ml Documentation](https://github.com/cucumber/cucumber.ml)
- [Effect Handlers in OCaml 5](https://v2.ocaml.org/manual/effects.html)
- [PPXlib Documentation](https://ppxlib.readthedocs.io/)
