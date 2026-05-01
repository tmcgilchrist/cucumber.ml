(** Camel farm example using PPX attributes and effect handlers.

    This demonstrates the modern ergonomic API for Cucumber.ml using:
    - PPX attributes ([@@given], [@@when], [@@then]) for automatic registration
    - Effect handlers for implicit state management
    - Helper functions (get_capture_int_exn, assert_equal, etc.)
    - Clean, readable test code with minimal boilerplate

    Compare with classic.ml to see the traditional builder-based approach.

    Key improvements:
    - ~50% less code (56 lines → 28 lines)
    - No manual Option.bind chains
    - Implicit state management via effects
    - Better error messages with file:line:column locations
    - Type-safe while remaining concise
*)

open Cucumber.Effects

(** Our world state - a simple farm with camels *)
type farm = { camels : int }

(** Initialize the farm with a number of camels from the step text *)
let[@given "I have (\\d+) camel on my farm"] given_initial_camels () =
  let count = get_capture_int_exn 1 in
  set_world { camels = count }

(** Buy more camels and add them to the farm *)
let[@when "I buy (\\d+) more camels"] when_buy_camels () =
  let more = get_capture_int_exn 1 in
  let farm = Option.get (get_world ()) in
  set_world { camels = farm.camels + more }

(** Sell camels from the farm, failing if we don't have enough *)
let[@when "I sell (\\d+) camels"] when_sell_camels () =
  let sold = get_capture_int_exn 1 in
  let farm = Option.get (get_world ()) in
  let new_count = farm.camels - sold in
  if new_count < 0 then
    fail "Cannot sell more camels than we have!"
  else
    set_world { camels = new_count }

(** Verify the number of camels on the farm matches expectations *)
let[@then "I have (\\d+) camels on my farm"] then_check_camels () =
  let expected = get_capture_int_exn 1 in
  let farm = Option.get (get_world ()) in
  assert_equal ~to_string:string_of_int expected farm.camels

(** Execute all registered steps from the camels.feature file *)
let () = Cucumber.execute_from_registry ()
