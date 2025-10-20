open Ppxlib

(** {1 Helper Functions} *)

(** Determine step type from attribute/extension name *)
let step_type_of_name ~loc name =
  match name with
  | "cucumber.given" | "given" -> [%expr `Given]
  | "cucumber.when" | "when" -> [%expr `When]
  | "cucumber.then" | "then" -> [%expr `Then]
  | _ -> Location.raise_errorf ~loc "Unknown step type: %s" name

(** Generate a unique name for a step handler function *)
let gen_unique_name =
  let counter = ref 0 in
  fun () ->
    incr counter;
    Printf.sprintf "__cucumber_step_handler_%d" !counter

(** {1 Attribute-Based PPX (Existing)} *)

(** Detect if a handler uses the effect-based API (unit -> unit) vs classic API
    (3 params -> tuple).

    Effect handlers have signature: fun () -> body
    Classic handlers have signature: fun world groups args -> body

    Note: In ppxlib 0.36.0+/OCaml 5.2+, functions use Pexp_function instead
    of nested Pexp_fun constructors. Pexp_function takes:
    (function_param list, type_constraint option, function_body) *)
let is_effect_handler value_binding =
  match value_binding.pvb_expr.pexp_desc with
  | Pexp_function (params, _, _) -> (
      (* Check if function has exactly one parameter that is unit pattern () *)
      match params with
      | [ { pparam_desc = Pparam_val (_arg_label, _default_opt, pat); _ } ] -> (
          match pat.ppat_desc with
          | Ppat_construct ({ txt = Lident "()"; _ }, None) -> true
          | _ -> false)
      | _ -> false)
  | _ -> false

(** Generate the registration code for a step definition using attributes *)
let generate_registration ~loc ~step_type ~pattern ~func_name =
  let pattern_expr = Ast_builder.Default.estring ~loc pattern in
  let file_expr = Ast_builder.Default.estring ~loc loc.loc_start.pos_fname in
  let line_expr = Ast_builder.Default.eint ~loc loc.loc_start.pos_lnum in
  let column_expr =
    Ast_builder.Default.eint ~loc
      (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)
  in

  [%stri
    let () =
      Cucumber.Step_registry.register ~step_type:[%e step_type]
        ~pattern:[%e pattern_expr]
        ~location:
          (Some
             {
               Cucumber.Step_registry.file = [%e file_expr];
               line = [%e line_expr];
               column = [%e column_expr];
             })
        ~handler:(fun world groups args ->
          [%e Ast_builder.Default.evar ~loc func_name] world groups args)]

(** Generate registration code for effect-based steps *)
let generate_effect_registration ~loc ~step_type ~pattern ~handler_name =
  let pattern_expr = Ast_builder.Default.estring ~loc pattern in
  let file_expr = Ast_builder.Default.estring ~loc loc.loc_start.pos_fname in
  let line_expr = Ast_builder.Default.eint ~loc loc.loc_start.pos_lnum in
  let column_expr =
    Ast_builder.Default.eint ~loc
      (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)
  in

  [%stri
    let () =
      Cucumber.Step_registry.register ~step_type:[%e step_type]
        ~pattern:[%e pattern_expr]
        ~location:
          (Some
             {
               Cucumber.Step_registry.file = [%e file_expr];
               line = [%e line_expr];
               column = [%e column_expr];
             })
        ~handler:(fun world groups args ->
          let config =
            { Cucumber.Effects.world; groups; args; verbosity = 0 }
          in
          Cucumber.Effects.make_handler config
            [%e Ast_builder.Default.evar ~loc handler_name])]

(** Transform a value binding with cucumber attribute *)
let expand_cucumber_step ~ctxt:_ (attr_name, payload) value_binding =
  let loc = value_binding.pvb_loc in

  (* Extract pattern from payload *)
  let pattern_str =
    match payload with
    | PStr
        [
          {
            pstr_desc =
              Pstr_eval
                ({ pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ }, _);
            _;
          };
        ] ->
        s
    | _ ->
        Location.raise_errorf ~loc:value_binding.pvb_loc
          "Step pattern must be a string literal, e.g., [@@%s \"pattern\"]"
          attr_name
  in

  (* Get function name *)
  let func_name =
    match value_binding.pvb_pat.ppat_desc with
    | Ppat_var { txt; _ } -> txt
    | _ ->
        Location.raise_errorf ~loc
          "Step definition must have a simple variable pattern"
  in

  let step_type = step_type_of_name ~loc attr_name in

  (* Keep the original function (without the attribute) *)
  let original_binding =
    {
      value_binding with
      pvb_attributes =
        List.filter
          (fun attr ->
            not
              (List.mem attr.attr_name.txt
                 [
                   "cucumber.given";
                   "cucumber.when";
                   "cucumber.then";
                   "given";
                   "when";
                   "then";
                 ]))
          value_binding.pvb_attributes;
    }
  in

  (* Generate registration - use effect wrapper for unit -> unit handlers *)
  let registration =
    if is_effect_handler value_binding then
      generate_effect_registration ~loc ~step_type ~pattern:pattern_str
        ~handler_name:func_name
    else
      generate_registration ~loc ~step_type ~pattern:pattern_str ~func_name
  in

  [
    Ast_builder.Default.pstr_value ~loc Nonrecursive [ original_binding ];
    registration;
  ]

(** {1 Extension Point-Based PPX (New - Effect Handlers)} *)

(** Expand let%given/when/then extension points *)
let expand_extension_point ~ctxt ext_name pattern_str body =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in

  (* Determine step type from extension name *)
  let step_type = step_type_of_name ~loc ext_name in

  (* Generate unique handler name *)
  let handler_name = gen_unique_name () in

  (* Create the handler function: let __handler () = <body> *)
  let handler_func =
    Ast_builder.Default.pstr_value ~loc Nonrecursive
      [
        {
          pvb_pat = Ast_builder.Default.pvar ~loc handler_name;
          pvb_expr = [%expr fun () -> [%e body]];
          pvb_attributes = [];
          pvb_constraint = None;
          pvb_loc = loc;
        };
      ]
  in

  (* Generate registration *)
  let registration =
    generate_effect_registration ~loc ~step_type ~pattern:pattern_str
      ~handler_name
  in

  [ handler_func ] @ [ registration ]

(** Extension point expanders are simpler - we'll use the attribute approach for
    now and add extension point support in a future version. The attribute
    syntax works well. *)
let given_expander =
  Extension.V3.declare "given" Extension.Context.expression
    Ast_pattern.(pstr nil)
    (fun ~ctxt ->
      let loc = Expansion_context.Extension.extension_point_loc ctxt in
      Ast_builder.Default.eunit ~loc)

let when_expander =
  Extension.V3.declare "when" Extension.Context.expression
    Ast_pattern.(pstr nil)
    (fun ~ctxt ->
      let loc = Expansion_context.Extension.extension_point_loc ctxt in
      Ast_builder.Default.eunit ~loc)

let then_expander =
  Extension.V3.declare "then" Extension.Context.expression
    Ast_pattern.(pstr nil)
    (fun ~ctxt ->
      let loc = Expansion_context.Extension.extension_point_loc ctxt in
      Ast_builder.Default.eunit ~loc)

(** {1 Attribute-Based Transformation Mapper} *)

(** Transformation mapper for attribute-based steps *)
let cucumber_mapper =
  object
    inherit Ast_traverse.map

    method! structure items =
      List.concat_map
        (fun item ->
          match item.pstr_desc with
          | Pstr_value (Nonrecursive, bindings) ->
              let attribute_names =
                [
                  "cucumber.given";
                  "cucumber.when";
                  "cucumber.then";
                  "given";
                  "when";
                  "then";
                ]
              in
              let check_for_step_attribute value_binding =
                List.find_map
                  (fun attr ->
                    if List.mem attr.attr_name.txt attribute_names then
                      Some (attr.attr_name.txt, attr.attr_payload)
                    else None)
                  value_binding.pvb_attributes
              in

              (* Check if any binding has a step attribute *)
              let has_step_attr =
                List.exists
                  (fun b -> Option.is_some (check_for_step_attribute b))
                  bindings
              in

              if has_step_attr then
                (* Expand each binding separately *)
                List.concat_map
                  (fun binding ->
                    match check_for_step_attribute binding with
                    | Some attr_info ->
                        let ctxt = Expansion_context.Base.top_level in
                        expand_cucumber_step ~ctxt attr_info binding
                    | None ->
                        [
                          Ast_builder.Default.pstr_value ~loc:binding.pvb_loc
                            Nonrecursive [ binding ];
                        ])
                  bindings
              else [ item ]
          | _ -> [ item ])
        items
  end

(** {1 Driver Registration} *)

(** Register the transformation with both approaches *)
let () =
  Driver.register_transformation "ppx_cucumber" ~impl:cucumber_mapper#structure
    ~extensions:[ given_expander; when_expander; then_expander ]
