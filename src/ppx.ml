open Ppxlib
module StringSet = Set.Make (String)

module LocationSet = Set.Make (struct
  type t = Location.t

  let compare = Stdlib.compare
end)

let disable_exhaustive_deps_flag = ref false
let disable_order_of_hooks_flag = ref false
let enable_corrections_flag = ref false

let timing_enabled =
  match Sys.getenv_opt "REACT_HOOKS_PPX_TIMING" with
  | None -> false
  | Some value ->
      let value = String.lowercase_ascii value in
      value = "1" || value = "true" || value = "yes" || value = "on"

let time_execution label f =
  if timing_enabled then (
    let start = Unix.gettimeofday () in
    let result = f () in
    let elapsed_ms = (Unix.gettimeofday () -. start) *. 1000.0 in
    Printf.eprintf "[react-rules-of-hooks-ppx] %s: %.3fms\n" label elapsed_ms;
    result)
  else f ()

let make_error_stri ~loc msg =
  Ast_builder.Default.pstr_extension ~loc
    (Location.error_extensionf ~loc "%s" msg)
    []

let diff list1 list2 =
  let list1_set = StringSet.of_list list1 in
  let list2_set = StringSet.of_list list2 in
  let diff_set = StringSet.diff list1_set list2_set in
  List.filter (fun item -> StringSet.mem item diff_set) list1

let unique_strings list =
  let _seen, acc_rev =
    List.fold_left
      (fun (seen, acc_rev) item ->
        if StringSet.mem item seen then (seen, acc_rev)
        else (StringSet.add item seen, item :: acc_rev))
      (StringSet.empty, []) list
  in
  List.rev acc_rev

let find_duplicates list =
  let _seen, dups_rev =
    List.fold_left
      (fun (seen, dups_rev) item ->
        if StringSet.mem item seen then (seen, item :: dups_rev)
        else (StringSet.add item seen, dups_rev))
      (StringSet.empty, []) list
  in
  List.rev dups_rev |> unique_strings

let unique_locations list =
  let _seen, acc_rev =
    List.fold_left
      (fun (seen, acc_rev) item ->
        if LocationSet.mem item seen then (seen, acc_rev)
        else (LocationSet.add item seen, item :: acc_rev))
      (LocationSet.empty, []) list
  in
  List.rev acc_rev

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
  let is_operator name =
    String.length name > 0
    &&
    let c = name.[0] in
    not (Char.equal c '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))
  in
  let add_values values_rev new_values =
    List.rev_append new_values values_rev
  in
  let rec collect (expression : Parsetree.expression) (ids_rev, values_rev) =
    match expression.pexp_desc with
    | Pexp_ident { txt = ident; _ } -> (ident :: ids_rev, values_rev)
    | Pexp_let (_, value_bindings, expr) ->
        let ids_rev, values_rev =
          List.fold_left
            (fun (ids_rev, values_rev) value ->
              let binding_names = extract_pattern_names value.pvb_pat in
              let func_params = extract_function_params value.pvb_expr in
              let values_rev =
                values_rev |> add_values binding_names |> add_values func_params
              in
              collect value.pvb_expr (ids_rev, values_rev))
            (ids_rev, values_rev) value_bindings
        in
        collect expr (ids_rev, values_rev)
    | Pexp_function (params, _, Pfunction_body body) ->
        let param_names =
          List.concat_map
            (fun (p : Parsetree.function_param) ->
              match p.pparam_desc with
              | Pparam_val (_, _, pat) -> extract_pattern_names pat
              | Pparam_newtype _ -> [])
            params
        in
        let values_rev = add_values values_rev param_names in
        collect body (ids_rev, values_rev)
    | Pexp_function (params, _, Pfunction_cases (cases, _, _)) ->
        let param_names =
          List.concat_map
            (fun (p : Parsetree.function_param) ->
              match p.pparam_desc with
              | Pparam_val (_, _, pat) -> extract_pattern_names pat
              | Pparam_newtype _ -> [])
            params
        in
        let values_rev = add_values values_rev param_names in
        List.fold_left
          (fun (ids_rev, values_rev) case ->
            let case_bindings = extract_pattern_names case.pc_lhs in
            let values_rev = add_values values_rev case_bindings in
            collect case.pc_rhs (ids_rev, values_rev))
          (ids_rev, values_rev) cases
    | Pexp_constraint (expr, _) -> collect expr (ids_rev, values_rev)
    | Pexp_newtype (_, expr) -> collect expr (ids_rev, values_rev)
    | Pexp_apply (fn_expr, labeled_expr) ->
        let ids_rev =
          match fn_expr.pexp_desc with
          | Pexp_ident { txt = Lident name as ident; _ }
            when not (is_operator name) ->
              ident :: ids_rev
          | _ -> ids_rev
        in
        List.fold_left
          (fun (ids_rev, values_rev) (_, arg_expr) ->
            collect arg_expr (ids_rev, values_rev))
          (ids_rev, values_rev) labeled_expr
    | Pexp_match (expr, cases) ->
        let ids_rev, values_rev = collect expr (ids_rev, values_rev) in
        List.fold_left
          (fun (ids_rev, values_rev) case ->
            let case_bindings = extract_pattern_names case.pc_lhs in
            let values_rev = add_values values_rev case_bindings in
            collect case.pc_rhs (ids_rev, values_rev))
          (ids_rev, values_rev) cases
    | Pexp_try (expr, cases) ->
        let ids_rev, values_rev = collect expr (ids_rev, values_rev) in
        List.fold_left
          (fun (ids_rev, values_rev) case ->
            let case_bindings = extract_pattern_names case.pc_lhs in
            let values_rev = add_values values_rev case_bindings in
            collect case.pc_rhs (ids_rev, values_rev))
          (ids_rev, values_rev) cases
    | Pexp_tuple exprs ->
        List.fold_left
          (fun acc expr -> collect expr acc)
          (ids_rev, values_rev) exprs
    | Pexp_construct ({ txt = Lident "None"; _ }, _) -> (ids_rev, values_rev)
    | Pexp_construct (_, Some expr) -> collect expr (ids_rev, values_rev)
    | Pexp_variant (_, Some expr) -> collect expr (ids_rev, values_rev)
    | Pexp_record (fields, Some expr) ->
        let ids_rev, values_rev = collect expr (ids_rev, values_rev) in
        List.fold_left
          (fun acc (_, expr) -> collect expr acc)
          (ids_rev, values_rev) fields
    | Pexp_record (fields, None) ->
        List.fold_left
          (fun acc (_, expr) -> collect expr acc)
          (ids_rev, values_rev) fields
    | Pexp_field (expr, _) -> collect expr (ids_rev, values_rev)
    | Pexp_setfield (expr1, _, expr2) ->
        let ids_rev, values_rev = collect expr1 (ids_rev, values_rev) in
        collect expr2 (ids_rev, values_rev)
    | Pexp_array exprs ->
        List.fold_left
          (fun acc expr -> collect expr acc)
          (ids_rev, values_rev) exprs
    | Pexp_ifthenelse (expr1, expr2, None) ->
        let ids_rev, values_rev = collect expr1 (ids_rev, values_rev) in
        collect expr2 (ids_rev, values_rev)
    | Pexp_ifthenelse (expr1, expr2, Some expr3) ->
        let ids_rev, values_rev = collect expr1 (ids_rev, values_rev) in
        let ids_rev, values_rev = collect expr2 (ids_rev, values_rev) in
        collect expr3 (ids_rev, values_rev)
    | Pexp_sequence (expr, seq_expr) ->
        let ids_rev, values_rev = collect expr (ids_rev, values_rev) in
        collect seq_expr (ids_rev, values_rev)
    | Pexp_while (expr1, expr2) ->
        let ids_rev, values_rev = collect expr1 (ids_rev, values_rev) in
        collect expr2 (ids_rev, values_rev)
    | Pexp_for (pat, expr1, expr2, _, expr3) ->
        let loop_var = extract_pattern_names pat in
        let values_rev = add_values values_rev loop_var in
        let ids_rev, values_rev = collect expr1 (ids_rev, values_rev) in
        let ids_rev, values_rev = collect expr2 (ids_rev, values_rev) in
        collect expr3 (ids_rev, values_rev)
    | Pexp_coerce (expr, _, _) -> collect expr (ids_rev, values_rev)
    | Pexp_send (expr, _) -> collect expr (ids_rev, values_rev)
    | Pexp_setinstvar (_, expr) -> collect expr (ids_rev, values_rev)
    | Pexp_override fields ->
        List.fold_left
          (fun acc (_, expr) -> collect expr acc)
          (ids_rev, values_rev) fields
    | Pexp_letmodule (_, _, expr) -> collect expr (ids_rev, values_rev)
    | Pexp_letexception (_, expr) -> collect expr (ids_rev, values_rev)
    | Pexp_assert expr -> collect expr (ids_rev, values_rev)
    | Pexp_lazy expr -> collect expr (ids_rev, values_rev)
    | Pexp_poly (expr, _) -> collect expr (ids_rev, values_rev)
    | Pexp_open (_, expr) -> collect expr (ids_rev, values_rev)
    | _ -> (ids_rev, values_rev)
  in
  let ids_rev, values_rev = collect expression ([], []) in
  { ids = List.rev ids_rev; values = List.rev values_rev }

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

let hooks_with_deps_set = StringSet.of_list hooks_with_deps
let is_hook_with_deps name = StringSet.mem name hooks_with_deps_set

let is_reason_file (ctx : Expansion_context.Base.t) =
  let filename = Expansion_context.Base.input_name ctx in
  Filename.check_suffix filename ".re" || Filename.check_suffix filename ".rei"

let suppress_exhaustive_deps_hint ~is_reason =
  if is_reason then
    "To suppress this warning, add [@disable_exhaustive_deps] before the \
     expression"
  else
    "To suppress this warning, add [@disable_exhaustive_deps] to the expression"

(* Helper to check if an expression is a call to a specific hook *)
let is_hook_call_named hook_names (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt = lident; _ }; _ }, _) ->
      let name = Longident.name lident in
      List.mem name hook_names
  | _ -> false

let is_use_state_call = is_hook_call_named [ "useState"; "React.useState" ]

let is_use_reducer_call =
  is_hook_call_named [ "useReducer"; "React.useReducer" ]

let is_use_ref_call = is_hook_call_named [ "useRef"; "React.useRef" ]

(* Extract the second element names from a tuple pattern (for useState/useReducer setters) *)
let get_second_tuple_element_names (pattern : Parsetree.pattern) : string list =
  match pattern.ppat_desc with
  | Ppat_tuple (_ :: pat2 :: _) -> extract_pattern_names pat2
  | _ -> []

(* Extract static deps from a value binding if it's a useState/useReducer/useRef call *)
let extract_static_deps_from_binding (vb : Parsetree.value_binding) :
    string list =
  let expr = vb.pvb_expr in
  let pattern = vb.pvb_pat in
  if is_use_state_call expr || is_use_reducer_call expr then
    (* Second element of tuple (setter/dispatch) is stable *)
    get_second_tuple_element_names pattern
  else if is_use_ref_call expr then
    (* Entire ref is stable *)
    extract_pattern_names pattern
  else []

let starts_with affix str =
  let affix_len = String.length affix in
  String.length str >= affix_len && String.sub str 0 affix_len = affix

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

let check_hook_deps (ctx : Expansion_context.Base.t)
    ~(static_deps : StringSet.t) ~(outer_scope_bindings : StringSet.t)
    (e : Parsetree.expression) : Driver.Lint_error.t list =
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
        if has_disable_attr_on_expr || has_disable_attr_on_deps then []
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
          let deps_loc =
            match deps_arg with
            | Some (_, deps_expr) -> deps_expr.pexp_loc
            | None -> e.pexp_loc
          in
          let is_reason = is_reason_file ctx in
          (* Check for duplicate dependencies *)
          let duplicate_deps = find_duplicates dependencies_names in
          let duplicate_errors =
            if duplicate_deps <> [] then
              let duplicates_str =
                duplicate_deps |> List.map quotes |> String.concat ", "
              in
              let msg =
                Printf.sprintf
                  "exhaustive-deps: Duplicate dependency %s in the dependency \
                   array.\n\
                   %s"
                  duplicates_str
                  (suppress_exhaustive_deps_hint ~is_reason)
              in
              [ Driver.Lint_error.of_string deps_loc msg ]
            else []
          in
          (* Check for missing dependencies *)
          let result = diff body_idents_inside_scope dependencies_names in
          (* Filter out static deps (useState setters, useReducer dispatchers, useRef results) *)
          let result_without_static =
            List.filter (fun dep -> not (StringSet.mem dep static_deps)) result
          in
          let missing_deps_unique = result_without_static |> unique_strings in
          let missing_errors =
            if missing_deps_unique <> [] then (
              let missing_dependencies =
                missing_deps_unique |> List.map quotes |> String.concat ", "
              in
              let all_deps =
                (dependencies_names |> unique_strings) @ missing_deps_unique
              in
              let total_dep_count = List.length all_deps in
              if !enable_corrections_flag then begin
                let hook_info = parse_hook_name name in
                match deps_arg with
                | None -> (
                    match (hook_info, List.nth_opt args 0) with
                    | ( Some (prefix, base, current_variant),
                        Some (_, callback_expr) ) ->
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
                            make_hook_name ~prefix ~base
                              ~variant:total_dep_count
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
                    Driver.register_correction ~loc:deps_loc
                      ~repl:corrected_deps;
                    match hook_info with
                    | Some (prefix, base, current_variant) ->
                        let needs_rename =
                          match current_variant with
                          | None -> true
                          | Some n -> n <> total_dep_count
                        in
                        if needs_rename then
                          let new_name =
                            make_hook_name ~prefix ~base
                              ~variant:total_dep_count
                          in
                          Driver.register_correction ~loc:fn_loc ~repl:new_name
                    | None -> ())
              end;
              let msg =
                Printf.sprintf
                  "exhaustive-deps: Missing %s in the dependency array.\n%s"
                  missing_dependencies
                  (suppress_exhaustive_deps_hint ~is_reason)
              in
              [ Driver.Lint_error.of_string deps_loc msg ])
            else []
          in
          (* Check for outer scope dependencies *)
          let outer_scope_deps =
            dependencies_names
            |> List.filter (fun dep -> StringSet.mem dep outer_scope_bindings)
            |> unique_strings
          in
          (* Also check for external module references (like Js.log) *)
          let external_module_deps =
            dependencies_idents.ids
            |> List.filter_map (fun lid ->
                match lid with Ldot _ -> Some (Longident.name lid) | _ -> None)
            |> unique_strings
          in
          let all_outer_scope =
            outer_scope_deps @ external_module_deps |> unique_strings
          in
          let outer_scope_errors =
            if all_outer_scope <> [] then
              let deps_str =
                all_outer_scope |> List.map quotes |> String.concat ", "
              in
              let msg =
                Printf.sprintf
                  "exhaustive-deps: React Hook %s has %s: %s. Outer scope \
                   values like %s aren't valid dependencies because mutating \
                   them doesn't re-render the component.\n\
                   %s"
                  name
                  (if List.length all_outer_scope = 1 then
                     "an unnecessary dependency"
                   else "unnecessary dependencies")
                  deps_str
                  (List.hd all_outer_scope |> quotes)
                  (suppress_exhaustive_deps_hint ~is_reason)
              in
              [ Driver.Lint_error.of_string deps_loc msg ]
            else []
          in
          duplicate_errors @ missing_errors @ outer_scope_errors
      else []
  | _ -> []

let get_name longident =
  match longident with Lident l -> Some l | Ldot (_, l) -> Some l | _ -> None

let is_a_hook_name name =
  starts_with "use" name
  && String.length name > 3
  &&
  let c = String.get name 3 in
  c >= 'A' && c <= 'Z'

let is_a_hook longident =
  match get_name longident with
  | Some name -> is_a_hook_name name
  | None -> false

let has_any_hooks (structure : Parsetree.structure) : bool =
  let exception Found in
  let scanner =
    object
      inherit Ast_traverse.iter as super

      method! expression e =
        match e.pexp_desc with
        | Pexp_apply ({ pexp_desc = Pexp_ident { txt = lident; _ }; _ }, _)
          when is_a_hook lident ->
            raise Found
        | _ -> super#expression e
    end
  in
  try
    scanner#structure structure;
    false
  with Found -> true

type hook_context = {
  is_inside_component : bool;
  is_inside_custom_hook : bool;
  is_inside_conditional : bool;
  is_inside_jsx : bool;
}

type analysis_acc = {
  context : hook_context;
  static_deps : StringSet.t;
  outer_scope_bindings : StringSet.t;
  lint_errors_rev : Driver.Lint_error.t list;
  conditional_locations_rev : Location.t list;
  outside_locations_rev : Location.t list;
}

type analysis = {
  lint_errors : Driver.Lint_error.t list;
  conditional_locations : Location.t list;
  outside_locations : Location.t list;
}

let has_attribute name attrs =
  attrs |> List.exists (fun { attr_name; _ } -> attr_name.txt = name)

let contains_jsx (attrs : attributes) =
  attrs |> List.exists (fun { attr_name; _ } -> attr_name.txt = "JSX")

let analysis_cache : (string, analysis) Hashtbl.t = Hashtbl.create 16

let empty_analysis =
  { lint_errors = []; conditional_locations = []; outside_locations = [] }

let analyze_structure (ctx : Expansion_context.Base.t)
    (structure : Parsetree.structure) : analysis =
  let key = Expansion_context.Base.input_name ctx in
  match Hashtbl.find_opt analysis_cache key with
  | Some analysis -> analysis
  | None ->
      let compute () =
        if not (has_any_hooks structure) then empty_analysis
        else
          let check_exhaustive = not !disable_exhaustive_deps_flag in
          let check_order_of_hooks = not !disable_order_of_hooks_flag in
          let initial_acc =
            {
              context =
                {
                  is_inside_component = false;
                  is_inside_custom_hook = false;
                  is_inside_conditional = false;
                  is_inside_jsx = false;
                };
              static_deps = StringSet.empty;
              outer_scope_bindings = StringSet.empty;
              lint_errors_rev = [];
              conditional_locations_rev = [];
              outside_locations_rev = [];
            }
          in
          let linter =
            object (self)
              inherit [analysis_acc] Ast_traverse.fold as super

              method! value_binding t acc =
                if not check_order_of_hooks then super#value_binding t acc
                else
                  let is_function_binding =
                    match get_function_body t.pvb_expr with
                    | Some _ -> true
                    | None -> false
                  in
                  let binding_names = extract_pattern_names t.pvb_pat in
                  let is_custom_hook_binding =
                    is_function_binding
                    && List.exists is_a_hook_name binding_names
                  in
                  let is_component_binding =
                    is_function_binding
                    && (has_attribute "react.component" t.pvb_attributes
                       || has_attribute "react.component"
                            t.pvb_pat.ppat_attributes)
                  in
                  (* Track module-level bindings (outer scope) - those defined outside components/hooks *)
                  let acc =
                    if
                      (not acc.context.is_inside_component)
                      && (not acc.context.is_inside_custom_hook)
                      && (not is_component_binding)
                      && not is_custom_hook_binding
                    then
                      {
                        acc with
                        outer_scope_bindings =
                          StringSet.union acc.outer_scope_bindings
                            (StringSet.of_list binding_names);
                      }
                    else acc
                  in
                  (* Extract static deps from useState/useReducer/useRef bindings *)
                  let new_static_deps = extract_static_deps_from_binding t in
                  let acc_with_static =
                    if new_static_deps <> [] then
                      {
                        acc with
                        static_deps =
                          StringSet.union acc.static_deps
                            (StringSet.of_list new_static_deps);
                      }
                    else acc
                  in
                  let acc_for_binding =
                    if is_function_binding then
                      if is_component_binding then
                        {
                          acc_with_static with
                          context =
                            {
                              acc_with_static.context with
                              is_inside_component = true;
                              is_inside_custom_hook = false;
                            };
                        }
                      else if is_custom_hook_binding then
                        {
                          acc_with_static with
                          context =
                            {
                              acc_with_static.context with
                              is_inside_component = false;
                              is_inside_custom_hook = true;
                            };
                        }
                      else
                        {
                          acc_with_static with
                          context =
                            {
                              acc_with_static.context with
                              is_inside_component = false;
                              is_inside_custom_hook = false;
                            };
                        }
                    else acc_with_static
                  in
                  let acc_after = super#value_binding t acc_for_binding in
                  {
                    acc with
                    static_deps = acc_after.static_deps;
                    outer_scope_bindings = acc_after.outer_scope_bindings;
                    lint_errors_rev = acc_after.lint_errors_rev;
                    conditional_locations_rev =
                      acc_after.conditional_locations_rev;
                    outside_locations_rev = acc_after.outside_locations_rev;
                  }

              method! expression t acc =
                let acc =
                  if check_order_of_hooks then
                    {
                      acc with
                      context =
                        {
                          acc.context with
                          is_inside_jsx =
                            acc.context.is_inside_jsx
                            || contains_jsx t.pexp_attributes;
                        };
                    }
                  else acc
                in
                let hook_context = acc.context in
                let mark_conditional acc =
                  if check_order_of_hooks then
                    {
                      acc with
                      context =
                        { acc.context with is_inside_conditional = true };
                    }
                  else acc
                in
                let acc =
                  match t.pexp_desc with
                  | Pexp_match (expr, cases) ->
                      let acc = self#expression expr acc in
                      List.fold_left
                        (fun acc case ->
                          self#expression case.pc_rhs (mark_conditional acc))
                        acc cases
                  | Pexp_try (expr, cases) ->
                      let acc = self#expression expr (mark_conditional acc) in
                      List.fold_left
                        (fun acc case ->
                          self#expression case.pc_rhs (mark_conditional acc))
                        acc cases
                  | Pexp_while (cond, expr) ->
                      let acc = self#expression cond acc in
                      self#expression expr (mark_conditional acc)
                  | Pexp_for (_, start_expr, end_expr, _, body) ->
                      let acc = self#expression start_expr acc in
                      let acc = self#expression end_expr acc in
                      self#expression body (mark_conditional acc)
                  | Pexp_ifthenelse (if_expr, then_expr, else_expr) -> (
                      let acc = self#expression if_expr acc in
                      let acc =
                        self#expression then_expr (mark_conditional acc)
                      in
                      match else_expr with
                      | Some expr -> self#expression expr (mark_conditional acc)
                      | None -> acc)
                  | Pexp_lazy expr ->
                      self#expression expr (mark_conditional acc)
                  | Pexp_assert expr ->
                      self#expression expr (mark_conditional acc)
                  | Pexp_apply
                      ( {
                          pexp_desc =
                            Pexp_ident { txt = Lident ("&&" | "||"); _ };
                          _;
                        },
                        args ) ->
                      List.fold_left
                        (fun acc (_, arg_expr) ->
                          self#expression arg_expr (mark_conditional acc))
                        acc args
                  | Pexp_apply
                      ({ pexp_desc = Pexp_ident { txt = lident; _ }; _ }, args)
                    when is_hook_with_deps (Longident.name lident) -> (
                      (* Hooks like useEffect/useMemo/useCallback: their callback
                       should be treated as conditional context since hooks
                       can't be called inside them *)
                      let callback_arg = List.nth_opt args 0 in
                      let deps_arg = List.nth_opt args 1 in
                      let acc =
                        match callback_arg with
                        | Some (_, callback_expr) ->
                            self#expression callback_expr (mark_conditional acc)
                        | None -> acc
                      in
                      match deps_arg with
                      | Some (_, deps_expr) -> self#expression deps_expr acc
                      | None -> acc)
                  | _ -> super#expression t acc
                in
                let acc =
                  if check_exhaustive then
                    let errors =
                      check_hook_deps ctx ~static_deps:acc.static_deps
                        ~outer_scope_bindings:acc.outer_scope_bindings t
                    in
                    if errors <> [] then
                      {
                        acc with
                        lint_errors_rev =
                          List.rev_append errors acc.lint_errors_rev;
                      }
                    else acc
                  else acc
                in
                let acc =
                  if check_order_of_hooks then
                    match t.pexp_desc with
                    | Pexp_apply
                        ( { pexp_desc = Pexp_ident { txt = lident; _ }; _ },
                          _args )
                      when is_a_hook lident ->
                        let acc =
                          if
                            hook_context.is_inside_conditional
                            || hook_context.is_inside_jsx
                          then
                            {
                              acc with
                              conditional_locations_rev =
                                t.pexp_loc :: acc.conditional_locations_rev;
                            }
                          else acc
                        in
                        let acc =
                          if
                            not
                              (hook_context.is_inside_component
                             || hook_context.is_inside_custom_hook)
                          then
                            {
                              acc with
                              outside_locations_rev =
                                t.pexp_loc :: acc.outside_locations_rev;
                            }
                          else acc
                        in
                        if hook_context.is_inside_jsx then
                          {
                            acc with
                            context = { acc.context with is_inside_jsx = false };
                          }
                        else acc
                    | _ -> acc
                  else acc
                in
                acc
            end
          in
          let final_acc = linter#structure structure initial_acc in
          {
            lint_errors = List.rev final_acc.lint_errors_rev;
            conditional_locations = List.rev final_acc.conditional_locations_rev;
            outside_locations = List.rev final_acc.outside_locations_rev;
          }
      in
      let analysis = time_execution ("analyze:" ^ key) compute in
      Hashtbl.add analysis_cache key analysis;
      analysis

let conditional_hooks_linter (ctx : Expansion_context.Base.t)
    (structure : Parsetree.structure) =
  if !disable_order_of_hooks_flag then structure
  else
    let analysis = analyze_structure ctx structure in
    let error_items =
      analysis.conditional_locations |> unique_locations
      |> List.map (fun loc ->
          make_error_stri ~loc
            "Hooks can't be called conditionally and must be called at the top \
             level of your component. Move this hook call outside of \
             conditionals, loops, or nested functions.")
    in
    error_items @ structure

let lint_impl (ctx : Expansion_context.Base.t) (structure : Parsetree.structure)
    : Driver.Lint_error.t list =
  let analysis = analyze_structure ctx structure in
  if !disable_order_of_hooks_flag then analysis.lint_errors
  else
    let outside_errors =
      analysis.outside_locations |> unique_locations
      |> List.map (fun loc ->
          let msg =
            "React hooks can only be called from [@react.component] functions \
             or custom hooks."
          in
          Driver.Lint_error.of_string loc msg)
    in
    analysis.lint_errors @ outside_errors

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
