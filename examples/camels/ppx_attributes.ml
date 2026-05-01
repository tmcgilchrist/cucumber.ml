(** Camel farm example using PPX attributes for automatic step registration.

    This demonstrates the PPX attribute approach:
    - Attributes ([@@given], [@@when], [@@then]) for automatic registration
    - Pattern strings directly in attributes (no manual Re.Perl.compile_pat)
    - Steps auto-register at module initialization
    - Cleaner than builder pipeline

    Compare with classic.ml to see the manual approach.

    Note: For even more ergonomic code with effect handlers (get_world(),
    set_world(), etc.), extension point syntax (let%given) is planned.
*)

type farm = { camels : int }

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
  | Some farm ->
      (Some { camels = farm.camels + more }, Cucumber.Outcome.Pass)
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
      if new_count < 0 then
        (Some farm, Cucumber.Outcome.Fail)
      else
        (Some { camels = new_count }, Cucumber.Outcome.Pass)
  | None -> (None, Cucumber.Outcome.Fail)

(** Verify the number of camels on the farm *)
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

(** Execute all registered steps from the feature file *)
let () = Cucumber.execute_from_registry ()
