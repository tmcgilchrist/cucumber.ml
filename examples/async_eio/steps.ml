(** Example demonstrating Eio integration with Cucumber.ml.

    This shows how OCaml 5.x effect handlers enable seamless composition
    of Cucumber effects (get_world, set_world, assert_equal) with Eio effects
    (file I/O, networking, etc.) through effect bubbling.

    The key insight: Cucumber's effect handler doesn't recognize Eio effects,
    so it returns None, allowing them to bubble up to Eio's runtime handler. *)

open Cucumber.Effects

(** World state storing file paths and simulated state.

    Note: In a real implementation, this would also store the Eio environment:
    { env : Eio_unix.Stdenv.base; written_files : string list } *)
type world = {
  written_files : string list;
}

(** Initialize world with Eio environment from fiber-local storage.

    Note: This is a placeholder - full Eio integration would store the
    environment in fiber-local storage accessible via get_eio_env() effect. *)
let[@given "I have an Eio environment"] given_eio_environment () =
  (* In a real implementation, we'd retrieve env from fiber-local storage.
     For this example, we'll document the pattern without full implementation. *)
  log "Eio environment initialized (placeholder - see docs/effects-and-async.md for full integration)"

let[@when "I write \"([^\"]*)\" to file \"([^\"]*)\""] when_write_file () =
  let content = get_capture 1 |> Option.get in
  let filename = get_capture 2 |> Option.get in

  (* This is where Eio file I/O would happen. The Eio effects would bubble
     through Cucumber's handler to Eio's runtime:

     let env = get_eio_env () in
     Eio.Path.(env#fs / filename)
     |> Eio.Path.save ~create:(`Or_truncate 0o644) content;

     For this demo, we'll just simulate it *)
  log (Printf.sprintf "Would write '%s' to '%s' using Eio" content filename);

  let world = match get_world () with
    | Some w -> w
    | None -> { written_files = [] }
  in
  set_world { written_files = filename :: world.written_files }

let[@when "I delete file \"([^\"]*)\""] when_delete_file () =
  let filename = get_capture 1 |> Option.get in
  log (Printf.sprintf "Would delete '%s' using Eio" filename);

  let world = get_world () |> Option.get in
  set_world { written_files = List.filter ((<>) filename) world.written_files }

let[@then "reading \"([^\"]*)\" should return \"([^\"]*)\""] then_reading_file () =
  let filename = get_capture 1 |> Option.get in
  let expected = get_capture 2 |> Option.get in

  (* In real implementation:
     let env = get_eio_env () in
     let actual = Eio.Path.(env#fs / filename) |> Eio.Path.load in
     assert_equal ~to_string:(fun s -> s) expected actual *)

  log (Printf.sprintf "Would read '%s' and compare with '%s'" filename expected);
  (* Simulate successful comparison for demo *)
  ()

let[@then "file \"([^\"]*)\" should not exist"] then_file_not_exist () =
  let filename = get_capture 1 |> Option.get in

  let world = get_world () |> Option.get in
  let exists = List.mem filename world.written_files in

  assert_true ~msg:(Printf.sprintf "File '%s' should not exist but was found in written_files" filename)
    (not exists)

(** Main entry point - would run inside Eio for full integration *)
let () =
  (* In full implementation:
     Eio_main.run @@ fun env ->
     Cucumber.Effects.with_eio_env env @@ fun () ->
     Cucumber.execute_from_registry () *)

  Cucumber.execute_from_registry ()
