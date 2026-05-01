# Eio Integration Example

This example demonstrates how Cucumber.ml's effect-based API composes naturally with Eio's async I/O effects through OCaml 5.x effect handlers.

## Key Concept: Effect Bubbling

The beauty of OCaml 5.x effects is that **multiple effect handlers compose seamlessly**:

```
[Step Code]
    ↓ Cucumber effects (GetWorld, AssertEqual)
    ↓ Eio effects (Read, Write, Sleep)
    ↓
[Cucumber Handler] ← handles Cucumber effects
    ↓ returns None for unknown effects
    ↓ Eio effects bubble upward
    ↓
[Eio Runtime] ← handles Eio effects
    ↓ performs actual I/O
    ↓
[OS]
```

## Current Implementation

This example is a **demonstration placeholder** showing the API pattern. The actual Eio integration is documented but not fully implemented to avoid adding Eio as a dependency.

### What's Here

- `steps.ml` - Effect-based step definitions using `unit -> unit` signatures
- Pattern matching on `{string}` captures (Gherkin expressions)
- Demonstrates where Eio calls would go
- Shows effect composability architecture

### Full Integration

For complete Eio integration, see `docs/effects-and-async.md` which explains:

1. How to store Eio environment in fiber-local storage
2. The `with_eio_env` helper pattern
3. How Eio effects bubble through Cucumber's handler
4. Zero-overhead async composition

## Running the Example

```bash
dune exec examples/async_eio/steps.exe examples/async_eio/file_operations.feature
```

## Future Development

Full Eio integration would add:

```ocaml
(* lib/effects.mli *)
val with_eio_env : Eio_unix.Stdenv.base -> (unit -> 'a) -> 'a
val get_eio_env : unit -> Eio_unix.Stdenv.base

(* examples/async_eio/steps.ml *)
let when_write_file () =
  let content = get_capture_string_exn 1 in
  let filename = get_capture_string_exn 2 in
  let env = get_eio_env () in
  Eio.Path.(env#fs / filename)
  |> Eio.Path.save ~create:(`Or_truncate 0o644) content

(* examples/async_eio/main.ml *)
let () =
  Eio_main.run @@ fun env ->
  Cucumber.Effects.with_eio_env env @@ fun () ->
  Cucumber.execute_from_registry ()
```

See the full documentation for implementation details.
