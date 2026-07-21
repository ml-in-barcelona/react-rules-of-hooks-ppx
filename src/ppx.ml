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
  let list2_set = StringSet.of_list list2 in
  List.filter (fun item -> not (StringSet.mem item list2_set)) list1

let unique_strings list =
  let _, acc_rev =
    List.fold_left
      (fun (seen, acc_rev) item ->
        if StringSet.mem item seen then (seen, acc_rev)
        else (StringSet.add item seen, item :: acc_rev))
      (StringSet.empty, []) list
  in
  List.rev acc_rev

let find_duplicates list =
  let rec go seen dups = function
    | [] -> StringSet.elements dups
    | x :: xs ->
        if StringSet.mem x seen then go seen (StringSet.add x dups) xs
        else go (StringSet.add x seen) dups xs
  in
  go StringSet.empty StringSet.empty list

let unique_locations list =
  let _, acc_rev =
    List.fold_left
      (fun (seen, acc_rev) item ->
        if LocationSet.mem item seen then (seen, acc_rev)
        else (LocationSet.add item seen, item :: acc_rev))
      (LocationSet.empty, []) list
  in
  List.rev acc_rev

let quotes = Printf.sprintf "'%s'"

type ident_info = { used_idents : longident list; bound_names : string list }

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

let extract_param_names (params : Parsetree.function_param list) : string list =
  List.concat_map
    (fun (p : Parsetree.function_param) ->
      match p.pparam_desc with
      | Pparam_val (_, _, pat) -> extract_pattern_names pat
      | Pparam_newtype _ -> [])
    params

let extract_platform_match (expr : Parsetree.expression) :
    (Parsetree.expression * Parsetree.case list) option =
  match expr.pexp_desc with
  | Pexp_extension
      ( { txt = "platform"; _ },
        PStr
          [
            {
              pstr_desc =
                Pstr_eval ({ pexp_desc = Pexp_match (scrut, cases); _ }, _);
              _;
            };
          ] ) ->
      Some (scrut, cases)
  | _ -> None

let extract_browser_only_payload (expr : Parsetree.expression) :
    Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_extension
      ( { txt = "browser_only"; _ },
        PStr [ { pstr_desc = Pstr_eval (payload, _); _ } ] ) ->
      Some payload
  | _ -> None

let rec is_client_pattern (pat : Parsetree.pattern) =
  match pat.ppat_desc with
  | Ppat_construct ({ txt = Lident "Client" | Ldot (_, "Client"); _ }, None) ->
      true
  | Ppat_constraint (p, _) | Ppat_alias (p, _) | Ppat_open (_, p) ->
      is_client_pattern p
  | _ -> false

let find_platform_client_case (cases : Parsetree.case list) :
    Parsetree.case option =
  List.find_opt (fun case -> is_client_pattern case.pc_lhs) cases

let rec extract_function_params (expr : Parsetree.expression) : string list =
  match expr.pexp_desc with
  | Pexp_function (params, _, Pfunction_body body) ->
      extract_param_names params @ extract_function_params body
  | Pexp_function (params, _, Pfunction_cases (cases, _, _)) ->
      let case_params =
        List.concat_map (fun case -> extract_pattern_names case.pc_lhs) cases
      in
      extract_param_names params @ case_params
  | Pexp_constraint (e, _) -> extract_function_params e
  | Pexp_newtype (_, e) -> extract_function_params e
  | _ -> (
      match extract_platform_match expr with
      | Some (_, cases) ->
          List.concat_map
            (fun (case : Parsetree.case) -> extract_function_params case.pc_rhs)
            cases
      | None -> [])

let rec extract_label_names (expr : Parsetree.expression) : string list =
  match expr.pexp_desc with
  | Pexp_function (params, _, _) ->
      List.filter_map
        (fun (p : Parsetree.function_param) ->
          match p.pparam_desc with
          | Pparam_val (Labelled name, _, _) | Pparam_val (Optional name, _, _)
            ->
              Some name
          | _ -> None)
        params
  | Pexp_constraint (e, _) | Pexp_newtype (_, e) -> extract_label_names e
  | _ -> (
      match extract_platform_match expr with
      | Some (_, cases) ->
          List.concat_map
            (fun (case : Parsetree.case) -> extract_label_names case.pc_rhs)
            cases
      | None -> [])

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
        let ids_rev, values_rev =
          List.fold_left
            (fun (ids_rev, values_rev) (p : Parsetree.function_param) ->
              match p.pparam_desc with
              | Pparam_val (_, default_arg, pat) ->
                  let ids_rev, values_rev =
                    match default_arg with
                    | None -> (ids_rev, values_rev)
                    | Some e -> collect e (ids_rev, values_rev)
                  in
                  (ids_rev, add_values values_rev (extract_pattern_names pat))
              | Pparam_newtype _ -> (ids_rev, values_rev))
            (ids_rev, values_rev) params
        in
        collect body (ids_rev, values_rev)
    | Pexp_function (params, _, Pfunction_cases (cases, _, _)) ->
        let ids_rev, values_rev =
          List.fold_left
            (fun (ids_rev, values_rev) (p : Parsetree.function_param) ->
              match p.pparam_desc with
              | Pparam_val (_, default_arg, pat) ->
                  let ids_rev, values_rev =
                    match default_arg with
                    | None -> (ids_rev, values_rev)
                    | Some e -> collect e (ids_rev, values_rev)
                  in
                  (ids_rev, add_values values_rev (extract_pattern_names pat))
              | Pparam_newtype _ -> (ids_rev, values_rev))
            (ids_rev, values_rev) params
        in
        List.fold_left
          (fun (ids_rev, values_rev) case ->
            let case_bindings = extract_pattern_names case.pc_lhs in
            let values_rev = add_values values_rev case_bindings in
            let ids_rev, values_rev =
              match case.pc_guard with
              | None -> (ids_rev, values_rev)
              | Some guard -> collect guard (ids_rev, values_rev)
            in
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
    | Pexp_letop { let_; ands; body } ->
        let ids_rev, values_rev = collect let_.pbop_exp (ids_rev, values_rev) in
        let binding_names = extract_pattern_names let_.pbop_pat in
        let ids_rev, values_rev =
          List.fold_left
            (fun (ids_rev, values_rev) and_op ->
              let ids_rev, values_rev =
                collect and_op.pbop_exp (ids_rev, values_rev)
              in
              let and_names = extract_pattern_names and_op.pbop_pat in
              (ids_rev, add_values values_rev and_names))
            (ids_rev, values_rev) ands
        in
        let values_rev = add_values values_rev binding_names in
        collect body (ids_rev, values_rev)
    | Pexp_extension _ -> (
        match extract_browser_only_payload expression with
        | Some payload -> collect payload (ids_rev, values_rev)
        | None -> (
            match extract_platform_match expression with
            | Some (_, cases) -> (
                match find_platform_client_case cases with
                | Some case ->
                    let values_rev =
                      add_values values_rev (extract_pattern_names case.pc_lhs)
                    in
                    collect case.pc_rhs (ids_rev, values_rev)
                | None -> (ids_rev, values_rev))
            | None -> (ids_rev, values_rev)))
    | _ -> (ids_rev, values_rev)
  in
  let ids_rev, values_rev = collect expression ([], []) in
  { used_idents = List.rev ids_rev; bound_names = List.rev values_rev }

let rec get_function_body (expr : Parsetree.expression) :
    Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_function (_, _, Pfunction_body body) -> Some body
  | Pexp_function (_, _, Pfunction_cases _) -> Some expr
  | Pexp_constraint (e, _) -> get_function_body e
  | _ -> (
      match extract_browser_only_payload expr with
      | Some payload -> get_function_body payload
      | None -> None)

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
  let expr =
    match extract_platform_match vb.pvb_expr with
    | Some (_, cases) -> (
        match find_platform_client_case cases with
        | Some case -> case.pc_rhs
        | None -> vb.pvb_expr)
    | None -> vb.pvb_expr
  in
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

let decode_hook_name (name : string) : (string * string * int option) option =
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

let has_attribute name attrs =
  attrs |> List.exists (fun { attr_name; _ } -> attr_name.txt = name)

let check_duplicate_deps ~is_reason ~deps_loc dependencies_names =
  let duplicate_deps = find_duplicates dependencies_names in
  if duplicate_deps = [] then []
  else
    let duplicates_str =
      duplicate_deps |> List.map quotes |> String.concat ", "
    in
    let msg =
      Printf.sprintf
        "exhaustive-deps: Duplicate %s %s in the dependency array.\n%s"
        (if List.length duplicate_deps = 1 then "dependency" else "dependencies")
        duplicates_str
        (suppress_exhaustive_deps_hint ~is_reason)
    in
    [ Driver.Lint_error.of_string deps_loc msg ]

let register_missing_deps_correction ~name ~fn_loc ~expr_loc ~deps_loc ~deps_arg
    ~callback_arg ~all_deps ~total_dep_count =
  let hook_info = decode_hook_name name in
  let register_hook_rename ~loc hook_info =
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
          Driver.register_correction ~loc ~repl:new_name
    | None -> ()
  in
  match deps_arg with
  | None -> (
      match (hook_info, callback_arg) with
      | Some (prefix, base, current_variant), Some (_, callback_expr) ->
          let needs_rename =
            match current_variant with
            | None -> true
            | Some n -> n <> total_dep_count
          in
          if needs_rename then
            let callback_str =
              Format.asprintf "%a" Pprintast.expression callback_expr
            in
            let new_name =
              make_hook_name ~prefix ~base ~variant:total_dep_count
            in
            let corrected_deps = format_deps all_deps in
            let full_correction =
              Printf.sprintf "%s (%s) %s" new_name callback_str corrected_deps
            in
            Driver.register_correction ~loc:expr_loc ~repl:full_correction
      | _ -> ())
  | Some _ ->
      let corrected_deps = format_deps all_deps in
      Driver.register_correction ~loc:deps_loc ~repl:corrected_deps;
      register_hook_rename ~loc:fn_loc hook_info

let check_missing_deps ~is_reason ~deps_loc ~name ~fn_loc ~expr_loc ~deps_arg
    ~callback_arg ~(static_deps : StringSet.t)
    ~(component_scope_bindings : StringSet.t)
    ~(qualified_body_idents : StringSet.t) ~dependencies_names
    ~body_idents_inside_scope =
  let missing =
    diff body_idents_inside_scope dependencies_names
    |> List.filter (fun dep ->
        StringSet.mem dep component_scope_bindings
        && (not (StringSet.mem dep qualified_body_idents))
        && not (StringSet.mem dep static_deps))
    |> unique_strings
  in
  if missing = [] then []
  else
    let missing_str = missing |> List.map quotes |> String.concat ", " in
    let all_deps = (dependencies_names |> unique_strings) @ missing in
    let total_dep_count = List.length all_deps in
    if !enable_corrections_flag then
      register_missing_deps_correction ~name ~fn_loc ~expr_loc ~deps_loc
        ~deps_arg ~callback_arg ~all_deps ~total_dep_count;
    let msg =
      Printf.sprintf
        "exhaustive-deps: Missing %s %s from the dependency array.\n%s"
        (if List.length missing = 1 then "dependency" else "dependencies")
        missing_str
        (suppress_exhaustive_deps_hint ~is_reason)
    in
    [ Driver.Lint_error.of_string deps_loc msg ]

let check_outer_scope_deps ~is_reason ~deps_loc ~name
    ~(outer_scope_bindings : StringSet.t) ~dependencies_names
    ~dependencies_idents =
  let outer_scope_deps =
    dependencies_names
    |> List.filter (fun dep -> StringSet.mem dep outer_scope_bindings)
    |> unique_strings
  in
  let external_module_deps =
    dependencies_idents.used_idents
    |> List.filter_map (fun lid ->
        match lid with Ldot _ -> Some (Longident.name lid) | _ -> None)
    |> unique_strings
  in
  let all_outer_scope =
    outer_scope_deps @ external_module_deps |> unique_strings
  in
  if all_outer_scope = [] then []
  else
    let deps_str = all_outer_scope |> List.map quotes |> String.concat ", " in
    let msg =
      Printf.sprintf
        "exhaustive-deps: %s has %s: %s. Outer scope values like %s aren't \
         valid dependencies because they are constant and never change between \
         renders.\n\
         %s"
        name
        (if List.length all_outer_scope = 1 then "an unnecessary dependency"
         else "unnecessary dependencies")
        deps_str
        (List.hd all_outer_scope |> quotes)
        (suppress_exhaustive_deps_hint ~is_reason)
    in
    [ Driver.Lint_error.of_string deps_loc msg ]

let check_hook_deps (ctx : Expansion_context.Base.t)
    ~(static_deps : StringSet.t) ~(outer_scope_bindings : StringSet.t)
    ~(component_scope_bindings : StringSet.t) (e : Parsetree.expression) :
    Driver.Lint_error.t list =
  match e.pexp_desc with
  | Pexp_apply
      ( ({ pexp_desc = Pexp_ident { txt = lident; _ }; pexp_loc = fn_loc; _ } as
         _fn_expr),
        args ) ->
      let name = Longident.name lident in
      if not (is_hook_with_deps name) then []
      else
        let deps_arg = List.nth_opt args 1 in
        let is_disabled =
          has_attribute "disable_exhaustive_deps" e.pexp_attributes
          || Option.map
               (fun (_, deps_expr) ->
                 has_attribute "disable_exhaustive_deps"
                   deps_expr.pexp_attributes)
               deps_arg
             |> Option.value ~default:false
        in
        if is_disabled then []
        else
          let body_idents =
            (match List.nth_opt args 0 with
              | Some (_, fn_expr) -> get_function_body fn_expr
              | _ -> None)
            |> Option.map get_idents
            |> Option.value ~default:{ used_idents = []; bound_names = [] }
          in
          let body_idents_inside_scope =
            diff
              (body_idents.used_idents |> List.map Longident.name)
              body_idents.bound_names
          in
          let qualified_body_idents =
            body_idents.used_idents
            |> List.filter_map (fun lid ->
                match lid with Ldot _ -> Some (Longident.name lid) | _ -> None)
            |> StringSet.of_list
          in
          let dependencies_idents =
            deps_arg
            |> Option.map (fun (_, deps) -> get_idents deps)
            |> Option.value ~default:{ used_idents = []; bound_names = [] }
          in
          let dependencies_names =
            dependencies_idents.used_idents |> List.map Longident.name
          in
          let deps_loc =
            match deps_arg with
            | Some (_, deps_expr) -> deps_expr.pexp_loc
            | None -> e.pexp_loc
          in
          let is_reason = is_reason_file ctx in
          check_duplicate_deps ~is_reason ~deps_loc dependencies_names
          @ check_missing_deps ~is_reason ~deps_loc ~name ~fn_loc
              ~expr_loc:e.pexp_loc ~deps_arg ~callback_arg:(List.nth_opt args 0)
              ~static_deps ~component_scope_bindings ~qualified_body_idents
              ~dependencies_names ~body_idents_inside_scope
          @ check_outer_scope_deps ~is_reason ~deps_loc ~name
              ~outer_scope_bindings ~dependencies_names ~dependencies_idents
  | _ -> []

let get_name longident =
  match longident with Lident l -> Some l | Ldot (_, l) -> Some l | _ -> None

let is_a_hook_name name =
  let len = String.length name in
  if len = 3 then name = "use"
  else
    len >= 4
    && name.[0] = 'u'
    && name.[1] = 's'
    && name.[2] = 'e'
    && ((name.[3] >= 'A' && name.[3] <= 'Z')
       || name.[3] = '_'
       || name.[3] = '\''
       || (name.[3] >= '0' && name.[3] <= '9'))

let is_a_hook longident =
  match get_name longident with
  | Some name -> is_a_hook_name name
  | None -> false

let contains_jsx (attrs : attributes) =
  attrs |> List.exists (fun { attr_name; _ } -> attr_name.txt = "JSX")

exception Hook_found

let hook_scanner =
  object
    inherit Ast_traverse.iter as super

    method! expression e =
      match e.pexp_desc with
      | Pexp_apply ({ pexp_desc = Pexp_ident { txt = lident; _ }; _ }, _)
        when is_a_hook lident && not (contains_jsx e.pexp_attributes) ->
          raise Hook_found
      | _ -> super#expression e
  end

let has_any_hooks (structure : Parsetree.structure) : bool =
  try
    hook_scanner#structure structure;
    false
  with Hook_found -> true

let expression_has_hook_calls (expr : Parsetree.expression) : bool =
  try
    hook_scanner#expression expr;
    false
  with Hook_found -> true

let is_browser_only_hook_wrapper (vb : Parsetree.value_binding) : bool =
  match get_function_body vb.pvb_expr with
  | Some _ -> expression_has_hook_calls vb.pvb_expr
  | None -> (
      match vb.pvb_expr.pexp_desc with
      | Pexp_ident { txt; _ } -> is_a_hook txt
      | _ -> false)

let browser_only_hook_names (vbs : Parsetree.value_binding list) : string list =
  vbs
  |> List.filter is_browser_only_hook_wrapper
  |> List.concat_map (fun (vb : Parsetree.value_binding) ->
      extract_pattern_names vb.pvb_pat)

let is_tracked_browser_only_hook (lident : Longident.t) (tracked : StringSet.t)
    : bool =
  match lident with Lident name -> StringSet.mem name tracked | _ -> false

type hook_context = {
  is_inside_component : bool;
  is_inside_custom_hook : bool;
  is_inside_conditional : bool;
  is_inside_jsx : bool;
}

type analysis_state = {
  context : hook_context;
  static_deps : StringSet.t;
  outer_scope_bindings : StringSet.t;
  component_scope_bindings : StringSet.t;
  browser_only_hooks : StringSet.t;
  lint_errors_rev : Driver.Lint_error.t list;
  conditional_locations_rev : Location.t list;
  outside_locations_rev : Location.t list;
}

type analysis = {
  lint_errors : Driver.Lint_error.t list;
  conditional_locations : Location.t list;
  outside_locations : Location.t list;
}

type binding_kind = Component | Custom_hook | Function | Value

let classify_binding (t : Parsetree.value_binding) =
  let is_function =
    match extract_platform_match t.pvb_expr with
    | Some (_, cases) ->
        List.exists
          (fun (case : Parsetree.case) ->
            Option.is_some (get_function_body case.pc_rhs))
          cases
    | None -> Option.is_some (get_function_body t.pvb_expr)
  in
  if not is_function then Value
  else
    let names = extract_pattern_names t.pvb_pat in
    if
      has_attribute "react.component" t.pvb_attributes
      || has_attribute "react.component" t.pvb_pat.ppat_attributes
    then Component
    else if List.exists is_a_hook_name names then Custom_hook
    else Function

let analysis_cache : (string, analysis) Hashtbl.t = Hashtbl.create 16

let empty_analysis =
  { lint_errors = []; conditional_locations = []; outside_locations = [] }

let initial_state =
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
    component_scope_bindings = StringSet.empty;
    browser_only_hooks = StringSet.empty;
    lint_errors_rev = [];
    conditional_locations_rev = [];
    outside_locations_rev = [];
  }

let make_linter ~(ctx : Expansion_context.Base.t) ~check_exhaustive
    ~check_order_of_hooks =
  object (self)
    inherit [analysis_state] Ast_traverse.fold as super

    method! value_binding t state =
      if not check_order_of_hooks then super#value_binding t state
      else self#binding_with_kind (classify_binding t) t state

    method private browser_only_binding vb state =
      if
        check_order_of_hooks
        && is_browser_only_hook_wrapper vb
        && Option.is_some (get_function_body vb.pvb_expr)
      then self#binding_with_kind Custom_hook vb state
      else self#value_binding vb state

    method private binding_with_kind kind t state =
      let binding_names = extract_pattern_names t.pvb_pat in
      let state =
        if StringSet.is_empty state.browser_only_hooks then state
        else
          {
            state with
            browser_only_hooks =
              StringSet.diff state.browser_only_hooks
                (StringSet.of_list binding_names);
          }
      in
      let is_outside_component = not state.context.is_inside_component in
      let is_outside_custom_hook = not state.context.is_inside_custom_hook in
      let is_outer_scope =
        is_outside_component && is_outside_custom_hook
        && (kind = Value || kind = Function)
      in
      let state_with_outer_scope =
        if is_outer_scope then
          {
            state with
            outer_scope_bindings =
              StringSet.union state.outer_scope_bindings
                (StringSet.of_list binding_names);
          }
        else state
      in
      let is_inside_scope =
        state.context.is_inside_component || state.context.is_inside_custom_hook
      in
      let state_with_component_scope =
        if is_inside_scope && (kind = Value || kind = Function) then
          {
            state_with_outer_scope with
            component_scope_bindings =
              StringSet.union state_with_outer_scope.component_scope_bindings
                (StringSet.of_list binding_names);
          }
        else state_with_outer_scope
      in
      let new_static_deps = extract_static_deps_from_binding t in
      let state_with_static_deps =
        if new_static_deps <> [] then
          {
            state_with_component_scope with
            static_deps =
              StringSet.union state_with_component_scope.static_deps
                (StringSet.of_list new_static_deps);
          }
        else state_with_component_scope
      in
      let saved_static_deps = state_with_static_deps.static_deps in
      let saved_component_scope =
        state_with_static_deps.component_scope_bindings
      in
      let function_params =
        let pattern_names = extract_function_params t.pvb_expr in
        let label_names = extract_label_names t.pvb_expr in
        StringSet.of_list (pattern_names @ label_names)
      in
      let state_for_binding =
        match kind with
        | Component ->
            {
              state_with_static_deps with
              context =
                {
                  state_with_static_deps.context with
                  is_inside_component = true;
                  is_inside_custom_hook = false;
                };
              static_deps = StringSet.empty;
              component_scope_bindings = function_params;
            }
        | Custom_hook ->
            {
              state_with_static_deps with
              context =
                {
                  state_with_static_deps.context with
                  is_inside_component = false;
                  is_inside_custom_hook = true;
                };
              static_deps = StringSet.empty;
              component_scope_bindings = function_params;
            }
        | Function ->
            {
              state_with_static_deps with
              context =
                {
                  state_with_static_deps.context with
                  is_inside_component = false;
                  is_inside_custom_hook = false;
                };
            }
        | Value -> state_with_static_deps
      in
      let state_after_traversal = super#value_binding t state_for_binding in
      let enters_new_scope = kind = Component || kind = Custom_hook in
      let static_deps =
        if enters_new_scope then saved_static_deps
        else state_after_traversal.static_deps
      in
      let component_scope_bindings =
        if enters_new_scope then saved_component_scope
        else state_after_traversal.component_scope_bindings
      in
      {
        state with
        static_deps;
        component_scope_bindings;
        outer_scope_bindings = state_after_traversal.outer_scope_bindings;
        browser_only_hooks = state_after_traversal.browser_only_hooks;
        lint_errors_rev = state_after_traversal.lint_errors_rev;
        conditional_locations_rev =
          state_after_traversal.conditional_locations_rev;
        outside_locations_rev = state_after_traversal.outside_locations_rev;
      }

    method! structure_item t state =
      match t.pstr_desc with
      | Pstr_extension
          ( ( { txt = "browser_only"; _ },
              PStr [ { pstr_desc = Pstr_value (_, vbs); _ } ] ),
            _ ) ->
          let state =
            List.fold_left
              (fun state vb -> self#browser_only_binding vb state)
              state vbs
          in
          {
            state with
            browser_only_hooks =
              StringSet.union state.browser_only_hooks
                (StringSet.of_list (browser_only_hook_names vbs));
          }
      | _ -> super#structure_item t state

    method private collect_exhaustive_deps_errors expr state =
      if not check_exhaustive then state
      else
        match
          check_hook_deps ctx ~static_deps:state.static_deps
            ~outer_scope_bindings:state.outer_scope_bindings
            ~component_scope_bindings:state.component_scope_bindings expr
        with
        | [] -> state
        | errors ->
            {
              state with
              lint_errors_rev = List.rev_append errors state.lint_errors_rev;
            }

    method private collect_hook_order_errors ~is_conditional_or_jsx
        ~is_outside_component_or_hook (expr : Parsetree.expression) state =
      if not check_order_of_hooks then state
      else
        match expr.pexp_desc with
        | Pexp_apply ({ pexp_desc = Pexp_ident { txt = lident; _ }; _ }, _args)
          when (is_a_hook lident
               || is_tracked_browser_only_hook lident state.browser_only_hooks)
               && not (contains_jsx expr.pexp_attributes) ->
            if has_attribute "disable_order_of_hooks" expr.pexp_attributes then
              state
            else
              let state =
                if is_conditional_or_jsx then
                  {
                    state with
                    conditional_locations_rev =
                      expr.pexp_loc :: state.conditional_locations_rev;
                  }
                else state
              in
              if is_outside_component_or_hook then
                {
                  state with
                  outside_locations_rev =
                    expr.pexp_loc :: state.outside_locations_rev;
                }
              else state
        | _ -> state

    method! expression t state =
      let state =
        if check_order_of_hooks then
          {
            state with
            context =
              {
                state.context with
                is_inside_jsx =
                  state.context.is_inside_jsx || contains_jsx t.pexp_attributes;
              };
          }
        else state
      in
      let hook_context = state.context in
      let mark_conditional state =
        if check_order_of_hooks then
          {
            state with
            context = { state.context with is_inside_conditional = true };
          }
        else state
      in
      let restore_context original_ctx state =
        { state with context = original_ctx }
      in
      let state =
        match t.pexp_desc with
        | Pexp_extension
            ( { txt = "platform"; _ },
              PStr
                [
                  {
                    pstr_desc =
                      Pstr_eval ({ pexp_desc = Pexp_match (scrut, cases); _ }, _);
                    _;
                  };
                ] ) ->
            let state = self#expression scrut state in
            let state =
              List.fold_left
                (fun state case -> self#expression case.pc_rhs state)
                state cases
            in
            restore_context hook_context state
        | Pexp_extension
            ( { txt = "browser_only"; _ },
              PStr [ { pstr_desc = Pstr_eval (payload, _); _ } ] ) -> (
            match payload.pexp_desc with
            | Pexp_let (_, vbs, body) ->
                let saved_browser_only = state.browser_only_hooks in
                let state =
                  List.fold_left
                    (fun state vb -> self#browser_only_binding vb state)
                    state vbs
                in
                let state =
                  {
                    state with
                    browser_only_hooks =
                      StringSet.union state.browser_only_hooks
                        (StringSet.of_list (browser_only_hook_names vbs));
                  }
                in
                let state = self#expression body state in
                let state =
                  { state with browser_only_hooks = saved_browser_only }
                in
                restore_context hook_context state
            | _ ->
                let state = self#expression payload state in
                restore_context hook_context state)
        | Pexp_match (expr, cases) ->
            let state = self#expression expr state in
            let state =
              List.fold_left
                (fun state case ->
                  self#expression case.pc_rhs (mark_conditional state))
                state cases
            in
            restore_context hook_context state
        | Pexp_try (expr, cases) ->
            let state = self#expression expr (mark_conditional state) in
            let state =
              List.fold_left
                (fun state case ->
                  self#expression case.pc_rhs (mark_conditional state))
                state cases
            in
            restore_context hook_context state
        | Pexp_while (cond, expr) ->
            let state = self#expression cond state in
            let state = self#expression expr (mark_conditional state) in
            restore_context hook_context state
        | Pexp_for (_, start_expr, end_expr, _, body) ->
            let state = self#expression start_expr state in
            let state = self#expression end_expr state in
            let state = self#expression body (mark_conditional state) in
            restore_context hook_context state
        | Pexp_ifthenelse (if_expr, then_expr, else_expr) ->
            let state = self#expression if_expr state in
            let state = self#expression then_expr (mark_conditional state) in
            let state =
              match else_expr with
              | Some expr -> self#expression expr (mark_conditional state)
              | None -> state
            in
            restore_context hook_context state
        | Pexp_lazy expr ->
            let state = self#expression expr (mark_conditional state) in
            restore_context hook_context state
        | Pexp_assert expr ->
            let state = self#expression expr (mark_conditional state) in
            restore_context hook_context state
        | Pexp_apply
            ( { pexp_desc = Pexp_ident { txt = Lident ("&&" | "||"); _ }; _ },
              args ) ->
            let state =
              List.fold_left
                (fun state (_, arg_expr) ->
                  self#expression arg_expr (mark_conditional state))
                state args
            in
            restore_context hook_context state
        | Pexp_function (params, _, func_body) ->
            let saved_jsx_context = hook_context.is_inside_jsx in
            let state =
              List.fold_left
                (fun state (p : Parsetree.function_param) ->
                  match p.pparam_desc with
                  | Pparam_val (_, default_arg, pattern) ->
                      let state =
                        match default_arg with
                        | Some expr -> self#expression expr state
                        | None -> state
                      in
                      self#pattern pattern state
                  | Pparam_newtype _ -> state)
                state params
            in
            let state_for_body =
              {
                state with
                context =
                  { state.context with is_inside_jsx = saved_jsx_context };
              }
            in
            let state =
              match func_body with
              | Pfunction_body body -> self#expression body state_for_body
              | Pfunction_cases (cases, _, _) ->
                  List.fold_left
                    (fun state case -> self#case case state)
                    state_for_body cases
            in
            restore_context hook_context state
        | Pexp_apply ({ pexp_desc = Pexp_ident { txt = lident; _ }; _ }, args)
          when is_hook_with_deps (Longident.name lident) ->
            let callback_arg = List.nth_opt args 0 in
            let deps_arg = List.nth_opt args 1 in
            let state =
              match callback_arg with
              | Some (_, callback_expr) ->
                  self#expression callback_expr (mark_conditional state)
              | None -> state
            in
            let state =
              match deps_arg with
              | Some (_, deps_expr) -> self#expression deps_expr state
              | None -> state
            in
            restore_context hook_context state
        | _ -> super#expression t state
      in
      state
      |> self#collect_exhaustive_deps_errors t
      |> self#collect_hook_order_errors
           ~is_conditional_or_jsx:
             (hook_context.is_inside_conditional || hook_context.is_inside_jsx)
           ~is_outside_component_or_hook:
             ((not hook_context.is_inside_component)
             && not hook_context.is_inside_custom_hook)
           t
  end

let compute_analysis (ctx : Expansion_context.Base.t)
    (structure : Parsetree.structure) : analysis =
  if not (has_any_hooks structure) then empty_analysis
  else
    let check_exhaustive = not !disable_exhaustive_deps_flag in
    let check_order_of_hooks = not !disable_order_of_hooks_flag in
    let linter = make_linter ~ctx ~check_exhaustive ~check_order_of_hooks in
    let final_state = linter#structure structure initial_state in
    {
      lint_errors = List.rev final_state.lint_errors_rev;
      conditional_locations = List.rev final_state.conditional_locations_rev;
      outside_locations = List.rev final_state.outside_locations_rev;
    }

let analyze_structure (ctx : Expansion_context.Base.t)
    (structure : Parsetree.structure) : analysis =
  let key = Expansion_context.Base.input_name ctx in
  match Hashtbl.find_opt analysis_cache key with
  | Some analysis -> analysis
  | None ->
      let analysis =
        time_execution ("analyze:" ^ key) (fun () ->
            compute_analysis ctx structure)
      in
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
             level of your component or custom hook. Move this hook call \
             outside of conditionals, loops, or nested functions.")
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
