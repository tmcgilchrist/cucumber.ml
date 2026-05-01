(** Global registry for step definitions registered via PPX *)

(** {1 Types} *)

type step_location = { file : string; line : int; column : int }
type step_type = [ `Given | `When | `Then ]

type 'a step_handler =
  'a option -> Re.Group.t option -> Step.arg option -> 'a option * Outcome.t

(** GADT for type-safe step storage *)
type _ step_kind =
  | Step : {
      step_type : step_type;
      pattern : string;
      regex : Re.re;
      location : step_location option;
      handler : 'a step_handler;
    }
      -> 'a step_kind

(** Existential wrapper for heterogeneous storage *)
type registered_step = RegisteredStep : 'a step_kind -> registered_step

(** Match result type *)
type 'a match_result =
  | NoMatch
  | Match of 'a step_handler * Re.Group.t option
  | Ambiguous of step_location option list

(** Global mutable registry - steps are registered at module initialization *)
let registry : registered_step list ref = ref []

(** {1 Pattern Compilation} *)

let compile_pattern pattern =
  try Re.Perl.compile_pat pattern
  with Re.Perl.Parse_error ->
    failwith
      (Printf.sprintf "Invalid regex pattern in step definition: %s" pattern)

(** {1 Registration} *)

let register ~step_type ~pattern ~location ~(handler : 'a step_handler) =
  let regex = compile_pattern pattern in
  let step = Step { step_type; pattern; regex; location; handler } in
  registry := RegisteredStep step :: !registry

(** {1 Querying} *)

let get_steps_by_type stype =
  List.filter (fun (RegisteredStep (Step s)) -> s.step_type = stype) !registry

let get_all_steps () = !registry

(** {1 Matching} *)

let find_step (step_text : string) (stype : step_type) : 'a match_result =
  (* Filter steps by type and check regex match *)
  let matches =
    List.filter
      (fun (RegisteredStep (Step s)) ->
        s.step_type = stype && Re.execp s.regex step_text)
      !registry
  in

  match matches with
  | [] -> NoMatch
  | [ RegisteredStep (Step single) ] ->
      let groups = Re.exec_opt single.regex step_text in
      (* We use Obj.magic here because the existential type is hidden.
         This is safe because the handler will be called with the same
         world type that was used when registering it. *)
      Match (Obj.magic single.handler, groups)
  | multiples ->
      (* Ambiguous match - collect locations *)
      let locations =
        List.map (fun (RegisteredStep (Step s)) -> s.location) multiples
      in
      Ambiguous locations

(** {1 Utilities} *)

let step_type_of_keyword keyword =
  match String.lowercase_ascii keyword with
  | "given" -> `Given
  | "when" -> `When
  | "then" -> `Then
  | "and" | "but" | "*" ->
     (* These inherit from previous step - not handled here
        TODO Track which type the And/But etc steps inherited from. *)
      failwith "And/But/* steps should inherit type from previous step"
  | _ -> failwith ("Unknown step keyword: " ^ keyword)

let clear () = registry := []