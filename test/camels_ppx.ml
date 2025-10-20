(** Camel farm example using PPX attributes for automatic step registration.

    This demonstrates using PPX for automatic step registration:
    - PPX attributes ([@@given], [@@when], [@@then]) for automatic registration
    - No need for manual regex compilation
    - Steps auto-register at module initialization time
    - Pattern strings directly in attributes

    Note: This example uses classic handler signatures. For effect handlers, we
    need extension point support (let%given etc.) which is planned for future.

    Compare with camels.ml to see the manual builder-based approach. *)

type farm = { camels : int }
(** Our world state - a simple farm with camels *)

(** Initialize the farm with a number of camels *)
let[@given "I have (\\d+) camel on my farm"] given_initial_camels world groups args =
  let count =
    Option.bind groups (fun g -> Re.Group.get_opt g 1)
    |> Option.map int_of_string_opt
    |> Option.join
  in
  match count with
  | Some n -> (Some { camels = n }, Cucumber.Outcome.Pass)
  | None -> (None, Cucumber.Outcome.Fail)

(** Buy more camels and add them to the farm *)
let[@when "I buy (\\d+) more camels"] when_buy_camels world groups args =
  let more =
    Option.bind groups (fun g -> Re.Group.get_opt g 1)
    |> Option.map int_of_string_opt
    |> Option.join |> Option.value ~default:0
  in
  match world with
  | Some farm -> (Some { camels = farm.camels + more }, Cucumber.Outcome.Pass)
  | None -> (None, Cucumber.Outcome.Fail)

(** Sell camels from the farm *)
let[@when "I sell (\\d+) camels"] when_sell_camels world groups args =
  let sold =
    Option.bind groups (fun g -> Re.Group.get_opt g 1)
    |> Option.map int_of_string_opt
    |> Option.join |> Option.value ~default:0
  in
  match world with
  | Some farm ->
      let new_count = farm.camels - sold in
      if new_count < 0 then (Some farm, Cucumber.Outcome.Fail)
      else (Some { camels = new_count }, Cucumber.Outcome.Pass)
  | None -> (None, Cucumber.Outcome.Fail)

(** Verify the number of camels on the farm *)
let[@then "I have (\\d+) camels on my farm"] then_check_camels world groups args =
  let expected =
    Option.bind groups (fun g -> Re.Group.get_opt g 1)
    |> Option.map int_of_string_opt
    |> Option.join |> Option.value ~default:0
  in
  match world with
  | Some farm when farm.camels = expected -> (Some farm, Cucumber.Outcome.Pass)
  | Some farm -> (Some farm, Cucumber.Outcome.Fail)
  | None -> (None, Cucumber.Outcome.Fail)

(** Execute all registered steps from the feature file *)
let () = Cucumber.execute_from_registry ()
