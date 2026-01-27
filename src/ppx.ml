open Ppxlib

let disable_exhaustive_deps_flag = ref false
let disable_order_of_hooks_flag = ref false
let enable_corrections_flag = ref false

let make_error_stri ~loc msg =
  Ast_builder.Default.pstr_extension ~loc
    (Location.error_extensionf ~loc "%s" msg)
    []

let diff list1 list2 = List.filter (fun x -> not (List.mem x list2)) list1

let rec unique lst =
  match lst with
  | [] -> []
  | h :: t -> h :: unique (List.filter (fun x -> x <> h) t)

let quotes = Printf.sprintf "'%s'"

type meta = { ids : longident list; values : string list }

let rec extract_pattern_names (pattern : Parsetree.pattern) : string list =
  match pattern.ppat_desc with
  | Ppat_var { txt; _ } -> [ txt ]
  | Ppat_tuple patterns -> List.concat_map extract_pattern_names patterns
  | Ppat_record (fields, _) ->
      List.concat_map (fun (_, pat) -> extract_pattern_names pat) fields
  | Ppat_construct (_, Some (_, pat)) -> extract_pattern_names pat
  | Ppat_variant (_, Some pat) -> extract_pattern_names pat
  | Ppat_or (p1, p2) -> extract_pattern_names p1 @ extract_pattern_names p2
  | Ppat_constraint (pat, _) -> extract_pattern_names pat
  | Ppat_alias (pat, { txt; _ }) -> txt :: extract_pattern_names pat
  | Ppat_array patterns -> List.concat_map extract_pattern_names patterns
  | Ppat_lazy pat -> extract_pattern_names pat
  | Ppat_open (_, pat) -> extract_pattern_names pat
  | Ppat_exception pat -> extract_pattern_names pat
  | Ppat_any -> []
  | Ppat_constant _ -> []
  | Ppat_interval _ -> []
  | Ppat_construct (_, None) -> []
  | Ppat_variant (_, None) -> []
  | Ppat_type _ -> []
  | Ppat_unpack _ -> []
  | Ppat_extension _ -> []

let rec extract_function_params (expr : Parsetree.expression) : string list =
  match expr.pexp_desc with
  | Pexp_function (params, _, Pfunction_body body) ->
      let param_names =
        List.concat_map
          (fun (p : Parsetree.function_param) ->
            match p.pparam_desc with
            | Pparam_val (_, _, pat) -> extract_pattern_names pat
            | Pparam_newtype _ -> [])
          params
      in
      param_names @ extract_function_params body
  | Pexp_function (params, _, Pfunction_cases (cases, _, _)) ->
      let param_names =
        List.concat_map
          (fun (p : Parsetree.function_param) ->
            match p.pparam_desc with
            | Pparam_val (_, _, pat) -> extract_pattern_names pat
            | Pparam_newtype _ -> [])
          params
      in
      let case_params =
        List.concat_map (fun case -> extract_pattern_names case.pc_lhs) cases
      in
      param_names @ case_params
  | Pexp_constraint (e, _) -> extract_function_params e
  | Pexp_newtype (_, e) -> extract_function_params e
  | _ -> []

let get_idents (expression : Parsetree.expression) =
  let rec get_idents_inner (expression : Parsetree.expression) (meta : meta) =
    let push_ident_list exprs =
      let results = List.map (fun expr -> get_idents_inner expr meta) exprs in
      let new_ids = List.concat_map (fun m -> m.ids) results in
      let new_values = List.concat_map (fun m -> m.values) results in
      {
        ids = List.append meta.ids new_ids;
        values = List.append meta.values new_values;
      }
    in
    let push_ident_list_with_bindings exprs bindings =
      let results =
        List.map
          (fun expr ->
            get_idents_inner expr { meta with values = meta.values @ bindings })
          exprs
      in
      let new_ids = List.concat_map (fun m -> m.ids) results in
      let new_values = List.concat_map (fun m -> m.values) results in
      {
        ids = List.append meta.ids new_ids;
        values = List.append meta.values new_values @ bindings;
      }
    in
    match expression.pexp_desc with
    | Pexp_ident { txt = ident; _ } -> { meta with ids = ident :: meta.ids }
    | Pexp_let (_, value_bindings, expr) ->
        let binding_names =
          List.concat_map
            (fun value -> extract_pattern_names value.pvb_pat)
            value_bindings
        in
        let binding_exprs =
          List.map (fun value -> value.pvb_expr) value_bindings
        in
        let func_params =
          List.concat_map
            (fun value -> extract_function_params value.pvb_expr)
            value_bindings
        in
        let all_local_bindings = binding_names @ func_params in
        let new_meta =
          push_ident_list_with_bindings binding_exprs all_local_bindings
        in
        let final_meta =
          get_idents_inner expr
            { new_meta with values = new_meta.values @ all_local_bindings }
        in
        { final_meta with values = meta.values @ all_local_bindings }
    | Pexp_function (params, _, Pfunction_body body) ->
        let param_names =
          List.concat_map
            (fun (p : Parsetree.function_param) ->
              match p.pparam_desc with
              | Pparam_val (_, _, pat) -> extract_pattern_names pat
              | Pparam_newtype _ -> [])
            params
        in
        get_idents_inner body { meta with values = meta.values @ param_names }
    | Pexp_function (params, _, Pfunction_cases (cases, _, _)) ->
        let param_names =
          List.concat_map
            (fun (p : Parsetree.function_param) ->
              match p.pparam_desc with
              | Pparam_val (_, _, pat) -> extract_pattern_names pat
              | Pparam_newtype _ -> [])
            params
        in
        let case_results =
          List.map
            (fun case ->
              let case_bindings = extract_pattern_names case.pc_lhs in
              get_idents_inner case.pc_rhs
                { meta with values = meta.values @ param_names @ case_bindings })
            cases
        in
        let all_ids = List.concat_map (fun m -> m.ids) case_results in
        { meta with ids = meta.ids @ all_ids }
    | Pexp_apply (fn_expr, labeled_expr) ->
        let is_operator name =
          String.length name > 0
          &&
          let c = name.[0] in
          not
            (Char.equal c '_'
            || (c >= 'a' && c <= 'z')
            || (c >= 'A' && c <= 'Z'))
        in
        let fn_ident =
          match fn_expr.pexp_desc with
          | Pexp_ident { txt = Lident name as ident; _ }
            when not (is_operator name) ->
              [ ident ]
          | _ -> []
        in
        let arg_exprs = List.map snd labeled_expr in
        let arg_result = push_ident_list arg_exprs in
        { arg_result with ids = fn_ident @ arg_result.ids }
    | Pexp_match (expr, cases) ->
        let expr_meta = get_idents_inner expr meta in
        let case_results =
          List.map
            (fun case ->
              let case_bindings = extract_pattern_names case.pc_lhs in
              get_idents_inner case.pc_rhs
                { meta with values = meta.values @ case_bindings })
            cases
        in
        let all_ids =
          expr_meta.ids @ List.concat_map (fun m -> m.ids) case_results
        in
        { meta with ids = all_ids }
    | Pexp_try (expr, cases) ->
        let expr_meta = get_idents_inner expr meta in
        let case_results =
          List.map
            (fun case ->
              let case_bindings = extract_pattern_names case.pc_lhs in
              get_idents_inner case.pc_rhs
                { meta with values = meta.values @ case_bindings })
            cases
        in
        let all_ids =
          expr_meta.ids @ List.concat_map (fun m -> m.ids) case_results
        in
        { meta with ids = all_ids }
    | Pexp_tuple exprs -> push_ident_list exprs
    | Pexp_construct ({ txt = Lident "None"; _ }, _) -> meta
    | Pexp_construct (_, Some expr) -> get_idents_inner expr meta
    | Pexp_variant (_, Some expr) -> get_idents_inner expr meta
    | Pexp_record (fields, Some expr) ->
        let exprs = List.map snd fields in
        push_ident_list (expr :: exprs)
    | Pexp_record (fields, None) ->
        let exprs = List.map snd fields in
        push_ident_list exprs
    | Pexp_field (expr, _) -> get_idents_inner expr meta
    | Pexp_setfield (expr1, _, expr2) -> push_ident_list [ expr1; expr2 ]
    | Pexp_array exprs -> push_ident_list exprs
    | Pexp_ifthenelse (expr1, expr2, None) -> push_ident_list [ expr1; expr2 ]
    | Pexp_ifthenelse (expr1, expr2, Some expr3) ->
        push_ident_list [ expr1; expr2; expr3 ]
    | Pexp_sequence (expr, seq_expr) -> push_ident_list [ expr; seq_expr ]
    | Pexp_while (expr1, expr2) -> push_ident_list [ expr1; expr2 ]
    | Pexp_for (pat, expr1, expr2, _, expr3) ->
        let loop_var = extract_pattern_names pat in
        let meta1 = get_idents_inner expr1 meta in
        let meta2 = get_idents_inner expr2 meta in
        let meta3 =
          get_idents_inner expr3 { meta with values = meta.values @ loop_var }
        in
        { meta with ids = meta1.ids @ meta2.ids @ meta3.ids }
    | Pexp_constraint (expr, _) -> get_idents_inner expr meta
    | Pexp_coerce (expr, _, _) -> get_idents_inner expr meta
    | Pexp_send (expr, _) -> get_idents_inner expr meta
    | Pexp_setinstvar (_, expr) -> get_idents_inner expr meta
    | Pexp_override fields ->
        let exprs = List.map snd fields in
        push_ident_list exprs
    | Pexp_letmodule (_, _, expr) -> get_idents_inner expr meta
    | Pexp_letexception (_, expr) -> get_idents_inner expr meta
    | Pexp_assert expr -> get_idents_inner expr meta
    | Pexp_lazy expr -> get_idents_inner expr meta
    | Pexp_poly (expr, _) -> get_idents_inner expr meta
    | Pexp_newtype (_, expr) -> get_idents_inner expr meta
    | Pexp_open (_, expr) -> get_idents_inner expr meta
    | _ -> meta
  in
  get_idents_inner expression { ids = []; values = [] }

let rec get_function_body (expr : Parsetree.expression) :
    Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_function (_, _, Pfunction_body body) -> Some body
  | Pexp_function (_, _, Pfunction_cases _) -> Some expr
  | Pexp_constraint (e, _) -> get_function_body e
  | _ -> None

let hooks_with_deps =
  let variants = [ ""; "0"; "1"; "2"; "3"; "4"; "5"; "6"; "7" ] in
  let prefixes = [ "React."; "" ] in
  let hooks =
    [
      "useEffect";
      "useLayoutEffect";
      "useInsertionEffect";
      "useCallback";
      "useMemo";
    ]
  in
  List.concat_map
    (fun hook ->
      List.concat_map
        (fun variant ->
          List.map (fun prefix -> prefix ^ hook ^ variant) prefixes)
        variants)
    hooks

let is_hook_with_deps name = List.mem name hooks_with_deps

let is_reason_file (ctx : Expansion_context.Base.t) =
  let filename = Expansion_context.Base.input_name ctx in
  Filename.check_suffix filename ".re" || Filename.check_suffix filename ".rei"

let suppress_exhaustive_deps_hint ~is_reason =
  if is_reason then
    "To suppress this warning, add [@disable_exhaustive_deps] before the \
     expression"
  else
    "To suppress this warning, add [@disable_exhaustive_deps] to the expression"

let starts_with affix str =
  let start = try String.sub str 0 (String.length affix) with _ -> "" in
  start = affix

let format_deps (deps : string list) : string =
  match deps with
  | [] -> "[||]"
  | [ dep ] -> "[| " ^ dep ^ " |]"
  | _ -> "(" ^ String.concat ", " deps ^ ")"

let hooks_base_names =
  [
    "useEffect";
    "useLayoutEffect";
    "useInsertionEffect";
    "useCallback";
    "useMemo";
  ]

let parse_hook_name (name : string) : (string * string * int option) option =
  let prefixes = [ "React."; "" ] in
  let try_parse prefix base =
    let full_base = prefix ^ base in
    if starts_with full_base name then
      let suffix =
        String.sub name (String.length full_base)
          (String.length name - String.length full_base)
      in
      match suffix with
      | "" -> Some (prefix, base, None)
      | "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" ->
          Some (prefix, base, Some (int_of_string suffix))
      | _ -> None
    else None
  in
  let all_combinations =
    List.concat_map
      (fun base -> List.map (fun prefix -> (prefix, base)) prefixes)
      hooks_base_names
  in
  List.find_map (fun (prefix, base) -> try_parse prefix base) all_combinations

let make_hook_name ~prefix ~base ~variant =
  prefix ^ base ^ string_of_int variant

let check_hook_deps (ctx : Expansion_context.Base.t) (e : Parsetree.expression)
    : Driver.Lint_error.t option =
  match e.pexp_desc with
  | Pexp_apply
      ( ({ pexp_desc = Pexp_ident { txt = lident; _ }; pexp_loc = fn_loc; _ } as
         _fn_expr),
        args ) ->
      let name = Longident.name lident in
      if is_hook_with_deps name then
        let deps_arg = List.nth_opt args 1 in
        let check_disable_attr attrs =
          attrs
          |> List.exists (fun { attr_name; _ } ->
              attr_name.txt = "disable_exhaustive_deps")
        in
        let has_disable_attr_on_expr = check_disable_attr e.pexp_attributes in
        let has_disable_attr_on_deps =
          deps_arg
          |> Option.map (fun (_, deps_expr) ->
              check_disable_attr deps_expr.pexp_attributes)
          |> Option.value ~default:false
        in
        if has_disable_attr_on_expr || has_disable_attr_on_deps then None
        else
          let body_expression =
            match List.nth_opt args 0 with
            | Some (_, fn_expr) -> get_function_body fn_expr
            | _ -> None
          in
          let body_idents =
            body_expression |> Option.map get_idents
            |> Option.value ~default:{ ids = []; values = [] }
          in
          let body_idents_inside_scope =
            diff (body_idents.ids |> List.map Longident.name) body_idents.values
          in
          let dependencies_idents =
            deps_arg
            |> Option.map (fun a -> snd a)
            |> Option.map (fun deps -> get_idents deps)
            |> Option.value ~default:{ ids = []; values = [] }
          in
          let dependencies_names =
            dependencies_idents.ids |> List.map Longident.name
          in
          let result = diff body_idents_inside_scope dependencies_names in
          let missing_deps_unique = result |> unique in
          let missing_dependencies =
            missing_deps_unique |> List.map quotes |> String.concat ", "
          in
          if List.length missing_deps_unique > 0 then (
            let deps_loc =
              match deps_arg with
              | Some (_, deps_expr) -> deps_expr.pexp_loc
              | None -> e.pexp_loc
            in
            let all_deps = dependencies_names @ missing_deps_unique in
            let total_dep_count = List.length all_deps in
            if !enable_corrections_flag then begin
              let hook_info = parse_hook_name name in
              match deps_arg with
              | None -> (
                  match (hook_info, List.nth_opt args 0) with
                  | Some (prefix, base, current_variant), Some (_, callback_expr)
                    ->
                      let needs_rename =
                        match current_variant with
                        | None -> true
                        | Some n -> n <> total_dep_count
                      in
                      if needs_rename then
                        let callback_str =
                          Format.asprintf "%a" Pprintast.expression
                            callback_expr
                        in
                        let new_name =
                          make_hook_name ~prefix ~base ~variant:total_dep_count
                        in
                        let corrected_deps = format_deps all_deps in
                        let full_correction =
                          Printf.sprintf "%s (%s) %s" new_name callback_str
                            corrected_deps
                        in
                        Driver.register_correction ~loc:e.pexp_loc
                          ~repl:full_correction
                  | _ -> ())
              | Some _ -> (
                  let corrected_deps = format_deps all_deps in
                  Driver.register_correction ~loc:deps_loc ~repl:corrected_deps;
                  match hook_info with
                  | Some (prefix, base, current_variant) ->
                      let needs_rename =
                        match current_variant with
                        | None -> true
                        | Some n -> n <> total_dep_count
                      in
                      if needs_rename then
                        let new_name =
                          make_hook_name ~prefix ~base ~variant:total_dep_count
                        in
                        Driver.register_correction ~loc:fn_loc ~repl:new_name
                  | None -> ())
            end;
            let is_reason = is_reason_file ctx in
            let msg =
              Printf.sprintf
                "exhaustive-deps: Missing %s in the dependency array.\n%s"
                missing_dependencies
                (suppress_exhaustive_deps_hint ~is_reason)
            in
            Some (Driver.Lint_error.of_string deps_loc msg))
          else None
      else None
  | _ -> None

let find_missing_deps ctx =
  object (_self)
    inherit [Driver.Lint_error.t list] Ast_traverse.fold as super

    method! expression t acc =
      let acc = super#expression t acc in
      match check_hook_deps ctx t with
      | Some error -> error :: acc
      | None -> acc
  end

let exhaustive_deps_linter (ctx : Expansion_context.Base.t)
    (structure : Parsetree.structure) : Driver.Lint_error.t list =
  if !disable_exhaustive_deps_flag then []
  else (find_missing_deps ctx)#structure structure []

let get_name longident =
  match longident with Lident l -> Some l | Ldot (_, l) -> Some l | _ -> None

let is_a_hook_name name = starts_with "use" name

let is_a_hook longident =
  match get_name longident with
  | Some name -> is_a_hook_name name
  | None -> false

type hook_context = {
  is_inside_component : bool;
  is_inside_custom_hook : bool;
  locations : Location.t list;
}

let has_attribute name attrs =
  attrs |> List.exists (fun { attr_name; _ } -> attr_name.txt = name)

let find_hooks_outside_allowed_context =
  let linter =
    object (_self)
      inherit [hook_context] Ast_traverse.fold as super

      method! value_binding t acc =
        let is_function_binding =
          match get_function_body t.pvb_expr with
          | Some _ -> true
          | None -> false
        in
        let binding_names = extract_pattern_names t.pvb_pat in
        let is_custom_hook_binding =
          is_function_binding && List.exists is_a_hook_name binding_names
        in
        let is_component_binding =
          is_function_binding
          && (has_attribute "react.component" t.pvb_attributes
             || has_attribute "react.component" t.pvb_pat.ppat_attributes)
        in
        let acc_for_binding =
          if is_function_binding then
            if is_component_binding then
              {
                acc with
                is_inside_component = true;
                is_inside_custom_hook = false;
              }
            else if is_custom_hook_binding then
              {
                acc with
                is_inside_component = false;
                is_inside_custom_hook = true;
              }
            else
              {
                acc with
                is_inside_component = false;
                is_inside_custom_hook = false;
              }
          else acc
        in
        let acc_after = super#value_binding t acc_for_binding in
        { acc with locations = acc_after.locations }

      method! expression t acc =
        let acc = super#expression t acc in
        match t.pexp_desc with
        | Pexp_apply ({ pexp_desc = Pexp_ident { txt = lident; _ }; _ }, _args)
          when is_a_hook lident
               && not (acc.is_inside_component || acc.is_inside_custom_hook) ->
            { acc with locations = t.pexp_loc :: acc.locations }
        | _ -> acc
    end
  in
  linter#structure

let hooks_outside_allowed_context_linter (_ctx : Expansion_context.Base.t)
    (structure : Parsetree.structure) : Driver.Lint_error.t list =
  if !disable_order_of_hooks_flag then []
  else
    let { locations; _ } =
      find_hooks_outside_allowed_context structure
        {
          is_inside_component = false;
          is_inside_custom_hook = false;
          locations = [];
        }
    in
    locations |> unique
    |> List.map (fun loc ->
        let msg =
          "React hooks can only be called from [@react.component] functions or \
           custom hooks."
        in
        Driver.Lint_error.of_string loc msg)

type acc = {
  is_inside_conditional : bool;
  is_inside_jsx : bool;
  locations : Location.t list;
}

let find_conditional_hooks =
  let contains_jsx (attrs : attributes) =
    attrs
    |> List.find_opt (fun { attr_name; _ } -> attr_name.txt = "JSX")
    |> Option.is_some
  in
  let linter =
    object (_self)
      inherit [acc] Ast_traverse.fold as super

      method! expression t acc =
        let acc =
          super#expression t
            {
              acc with
              is_inside_jsx =
                acc.is_inside_jsx || contains_jsx t.pexp_attributes;
            }
        in
        match t.pexp_desc with
        | Pexp_apply ({ pexp_desc = Pexp_ident { txt = lident; _ }; _ }, _args)
          when is_a_hook lident && acc.is_inside_conditional ->
            { acc with locations = t.pexp_loc :: acc.locations }
        | Pexp_apply ({ pexp_desc = Pexp_ident { txt = lident; _ }; _ }, _args)
          when is_a_hook lident && acc.is_inside_jsx ->
            {
              acc with
              locations = t.pexp_loc :: acc.locations;
              is_inside_jsx = false;
            }
        | Pexp_sequence (_, exp) ->
            let acc =
              super#expression exp
                { acc with is_inside_jsx = contains_jsx exp.pexp_attributes }
            in
            acc
        | Pexp_match (_expr, list_of_expr) ->
            List.fold_left
              (fun acc expr ->
                super#expression expr.pc_rhs
                  { acc with is_inside_conditional = true })
              acc list_of_expr
        | Pexp_while (_cond, expr) ->
            super#expression expr { acc with is_inside_conditional = true }
        | Pexp_for (_, _, _, _, expr) ->
            super#expression expr { acc with is_inside_conditional = true }
        | Pexp_ifthenelse (if_expr, then_expr, else_expr) ->
            let acc =
              super#expression if_expr { acc with is_inside_conditional = true }
            in
            let acc =
              super#expression then_expr
                { acc with is_inside_conditional = true }
            in
            let acc =
              match else_expr with
              | Some expr ->
                  super#expression expr
                    { acc with is_inside_conditional = true }
              | None -> acc
            in
            { acc with is_inside_conditional = true }
        | Pexp_try (expr, cases) ->
            let acc =
              super#expression expr { acc with is_inside_conditional = true }
            in
            List.fold_left
              (fun acc case ->
                super#expression case.pc_rhs
                  { acc with is_inside_conditional = true })
              acc cases
        | Pexp_lazy expr ->
            super#expression expr { acc with is_inside_conditional = true }
        | Pexp_assert expr ->
            super#expression expr { acc with is_inside_conditional = true }
        | Pexp_apply
            ( { pexp_desc = Pexp_ident { txt = Lident ("&&" | "||"); _ }; _ },
              args ) ->
            List.fold_left
              (fun acc (_, arg_expr) ->
                super#expression arg_expr
                  { acc with is_inside_conditional = true })
              acc args
        | _ -> super#expression t acc
    end
  in
  linter#structure

let conditional_hooks_linter (_ctx : Expansion_context.Base.t)
    (structure : Parsetree.structure) =
  if !disable_order_of_hooks_flag then structure
  else
    let { locations; _ } =
      find_conditional_hooks structure
        { is_inside_conditional = false; is_inside_jsx = false; locations = [] }
    in
    let error_items =
      locations |> unique
      |> List.map (fun loc ->
          make_error_stri ~loc
            "Hooks can't be called conditionally and must be called at the top \
             level of your component. Move this hook call outside of \
             conditionals, loops, or nested functions.")
    in
    error_items @ structure

let lint_impl (ctx : Expansion_context.Base.t) (structure : Parsetree.structure)
    : Driver.Lint_error.t list =
  exhaustive_deps_linter ctx structure
  @ hooks_outside_allowed_context_linter ctx structure

let () =
  Driver.add_arg "-disable-exhaustive-deps" (Set disable_exhaustive_deps_flag)
    ~doc:"If set, disables checking for 'exhaustive dependencies' in UseEffects";

  Driver.add_arg "-disable-order-of-hooks" (Set disable_order_of_hooks_flag)
    ~doc:"If set, disables checking for hooks being called at the top level";

  Driver.add_arg "-corrections" (Set enable_corrections_flag)
    ~doc:
      "If set, generates .ppx-corrected files with suggested fixes for \
       exhaustive dependencies";

  Driver.V2.register_transformation ~impl:conditional_hooks_linter ~lint_impl
    "react-rules-of-hooks"
