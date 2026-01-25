open Ppxlib

let exhaustive_deps = ref true
let order_of_hooks = ref true

let make_error_expr ~loc msg =
  Ast_builder.Default.pexp_extension ~loc
    (Location.error_extensionf ~loc "%s" msg)

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

let use_effect_lint (e : Parsetree.expression) =
  match e.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident _; _ }, args) ->
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
        List.nth_opt args 1
        |> Option.map (fun a -> snd a)
        |> Option.map (fun deps -> get_idents deps)
        |> Option.value ~default:{ ids = []; values = [] }
      in
      let dependencies_names =
        dependencies_idents.ids |> List.map Longident.name
      in
      let result = diff body_idents_inside_scope dependencies_names in
      let missing_dependencies =
        result |> unique |> List.map quotes |> String.concat ", "
      in
      if List.length result > 0 then
        let msg =
          Printf.sprintf "ExhaustiveDeps: Missing %s in the dependency array"
            missing_dependencies
        in
        Some (make_error_expr ~loc:e.pexp_loc msg)
      else None
  | _ -> None

let use_effect_expand (e : Parsetree.expression) =
  if !exhaustive_deps then use_effect_lint e else None

let starts_with affix str =
  let start = try String.sub str 0 (String.length affix) with _ -> "" in
  start = affix

type acc = {
  is_inside_conditional : bool;
  is_inside_jsx : bool;
  locations : Location.t list;
}

let find_conditional_hooks =
  let get_name lident =
    match lident with Lident l -> l | Ldot (_, l) -> l | _ -> ""
  in
  let is_a_hook lident =
    let name = get_name lident in
    starts_with "use" name
  in
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

let conditional_hooks_linter (structure : Parsetree.structure) =
  if not !order_of_hooks then structure
  else
    let { locations; _ } =
      find_conditional_hooks structure
        { is_inside_conditional = false; is_inside_jsx = false; locations = [] }
    in
    let error_items =
      locations |> unique
      |> List.map (fun loc ->
          make_error_stri ~loc "Hooks can't be called conditionally")
    in
    error_items @ structure

let make_rules hooks expand =
  let variants = [ ""; "1"; "2"; "3"; "4"; "5"; "6"; "7" ] in
  let prefixes = [ "React."; "" ] in
  List.concat_map
    (fun hook ->
      List.concat_map
        (fun variant ->
          List.map
            (fun prefix ->
              Context_free.Rule.special_function
                (prefix ^ hook ^ variant)
                expand)
            prefixes)
        variants)
    hooks

let () =
  Driver.add_arg "-exhaustive-deps" (Set exhaustive_deps)
    ~doc:"If set, checks for 'exhaustive dependencies' in UseEffects";

  Driver.add_arg "-order-of-hooks" (Set order_of_hooks)
    ~doc:"If set, checks for hooks being called at the top level";

  let effect_rules =
    make_rules
      [ "useEffect"; "useLayoutEffect"; "useInsertionEffect" ]
      use_effect_expand
  in

  let callback_memo_rules =
    make_rules [ "useCallback"; "useMemo" ] use_effect_expand
  in

  Driver.register_transformation ~impl:conditional_hooks_linter
    ~rules:(effect_rules @ callback_memo_rules)
    "react-rules-of-hooks"
