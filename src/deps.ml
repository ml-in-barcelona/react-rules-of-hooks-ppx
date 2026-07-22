open Ppxlib

type path = { root : Longident.t; fields : string list }
type t = { used_paths : path list; bound_names : string list }

let path_of_ident root = { root; fields = [] }
let root_name path = Longident.name path.root

let is_qualified path =
  match path.root with Lident _ -> false | Ldot _ | Lapply _ -> true

let path_to_string path = String.concat "." (root_name path :: path.fields)

let rec fields_are_prefix prefix fields =
  match (prefix, fields) with
  | [], _ -> true
  | _ :: _, [] -> false
  | p :: ps, f :: fs -> String.equal p f && fields_are_prefix ps fs

let is_prefix ~prefix ~path =
  String.equal (root_name prefix) (root_name path)
  && fields_are_prefix prefix.fields path.fields

let is_strict_prefix ~prefix ~path =
  List.length prefix.fields < List.length path.fields && is_prefix ~prefix ~path

(* [path_with_fields e fields] resolves [e] as a field chain over an ident and
   appends [fields] after the chain's own fields. *)
let rec path_with_fields (expression : Parsetree.expression) fields :
    path option =
  match expression.pexp_desc with
  | Pexp_ident { txt; _ } -> Some { root = txt; fields }
  | Pexp_field (inner, { txt = Lident field; _ }) ->
      path_with_fields inner (field :: fields)
  | Pexp_constraint (inner, _) -> path_with_fields inner fields
  | _ -> None

let path_of_expression expression = path_with_fields expression []

let is_operator name =
  String.length name > 0
  &&
  let c = name.[0] in
  not (Char.equal c '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'))

let add_values values_rev new_values = List.rev_append new_values values_rev

let of_expression (expression : Parsetree.expression) : t =
  let rec collect (expression : Parsetree.expression) (paths_rev, values_rev) =
    match expression.pexp_desc with
    | Pexp_ident { txt = ident; _ } ->
        (path_of_ident ident :: paths_rev, values_rev)
    | Pexp_let (_, value_bindings, expr) ->
        let paths_rev, values_rev =
          List.fold_left
            (fun (paths_rev, values_rev) value ->
              let binding_names = Bindings.of_pattern value.pvb_pat in
              let func_params = Bindings.function_params value.pvb_expr in
              let values_rev =
                values_rev |> add_values binding_names |> add_values func_params
              in
              collect value.pvb_expr (paths_rev, values_rev))
            (paths_rev, values_rev) value_bindings
        in
        collect expr (paths_rev, values_rev)
    | Pexp_function (params, _, body) -> (
        let paths_rev, values_rev = collect_params params (paths_rev, values_rev) in
        match body with
        | Pfunction_body body -> collect body (paths_rev, values_rev)
        | Pfunction_cases (cases, _, _) ->
            List.fold_left
              (fun (paths_rev, values_rev) case ->
                let case_bindings = Bindings.of_pattern case.pc_lhs in
                let values_rev = add_values values_rev case_bindings in
                let paths_rev, values_rev =
                  match case.pc_guard with
                  | None -> (paths_rev, values_rev)
                  | Some guard -> collect guard (paths_rev, values_rev)
                in
                collect case.pc_rhs (paths_rev, values_rev))
              (paths_rev, values_rev) cases)
    | Pexp_constraint (expr, _) -> collect expr (paths_rev, values_rev)
    | Pexp_newtype (_, expr) -> collect expr (paths_rev, values_rev)
    | Pexp_apply (fn_expr, labeled_expr) ->
        let paths_rev =
          match fn_expr.pexp_desc with
          | Pexp_ident { txt = Lident name as ident; _ }
            when not (is_operator name) ->
              path_of_ident ident :: paths_rev
          | _ -> paths_rev
        in
        List.fold_left
          (fun (paths_rev, values_rev) (_, arg_expr) ->
            collect arg_expr (paths_rev, values_rev))
          (paths_rev, values_rev) labeled_expr
    | Pexp_match (expr, cases) | Pexp_try (expr, cases) ->
        let paths_rev, values_rev = collect expr (paths_rev, values_rev) in
        List.fold_left
          (fun (paths_rev, values_rev) case ->
            let case_bindings = Bindings.of_pattern case.pc_lhs in
            let values_rev = add_values values_rev case_bindings in
            collect case.pc_rhs (paths_rev, values_rev))
          (paths_rev, values_rev) cases
    | Pexp_tuple exprs | Pexp_array exprs ->
        List.fold_left
          (fun acc expr -> collect expr acc)
          (paths_rev, values_rev) exprs
    | Pexp_construct ({ txt = Lident "None"; _ }, _) -> (paths_rev, values_rev)
    | Pexp_construct (_, Some expr) -> collect expr (paths_rev, values_rev)
    | Pexp_variant (_, Some expr) -> collect expr (paths_rev, values_rev)
    | Pexp_record (fields, base) ->
        let acc =
          match base with
          | Some expr -> collect expr (paths_rev, values_rev)
          | None -> (paths_rev, values_rev)
        in
        List.fold_left (fun acc (_, expr) -> collect expr acc) acc fields
    | Pexp_field (expr, _) -> (
        match path_of_expression expression with
        | Some path -> (path :: paths_rev, values_rev)
        | None -> collect expr (paths_rev, values_rev))
    | Pexp_setfield (expr1, field, expr2) ->
        let paths_rev, values_rev =
          match field.txt with
          | Lident name -> (
              match path_with_fields expr1 [ name ] with
              | Some path -> (path :: paths_rev, values_rev)
              | None -> collect expr1 (paths_rev, values_rev))
          | _ -> collect expr1 (paths_rev, values_rev)
        in
        collect expr2 (paths_rev, values_rev)
    | Pexp_ifthenelse (expr1, expr2, None) ->
        let paths_rev, values_rev = collect expr1 (paths_rev, values_rev) in
        collect expr2 (paths_rev, values_rev)
    | Pexp_ifthenelse (expr1, expr2, Some expr3) ->
        let paths_rev, values_rev = collect expr1 (paths_rev, values_rev) in
        let paths_rev, values_rev = collect expr2 (paths_rev, values_rev) in
        collect expr3 (paths_rev, values_rev)
    | Pexp_sequence (expr, seq_expr) ->
        let paths_rev, values_rev = collect expr (paths_rev, values_rev) in
        collect seq_expr (paths_rev, values_rev)
    | Pexp_while (expr1, expr2) ->
        let paths_rev, values_rev = collect expr1 (paths_rev, values_rev) in
        collect expr2 (paths_rev, values_rev)
    | Pexp_for (pat, expr1, expr2, _, expr3) ->
        let loop_var = Bindings.of_pattern pat in
        let values_rev = add_values values_rev loop_var in
        let paths_rev, values_rev = collect expr1 (paths_rev, values_rev) in
        let paths_rev, values_rev = collect expr2 (paths_rev, values_rev) in
        collect expr3 (paths_rev, values_rev)
    | Pexp_coerce (expr, _, _) -> collect expr (paths_rev, values_rev)
    | Pexp_send (expr, _) -> collect expr (paths_rev, values_rev)
    | Pexp_setinstvar (_, expr) -> collect expr (paths_rev, values_rev)
    | Pexp_override fields ->
        List.fold_left
          (fun acc (_, expr) -> collect expr acc)
          (paths_rev, values_rev) fields
    | Pexp_letmodule (_, _, expr) -> collect expr (paths_rev, values_rev)
    | Pexp_letexception (_, expr) -> collect expr (paths_rev, values_rev)
    | Pexp_assert expr -> collect expr (paths_rev, values_rev)
    | Pexp_lazy expr -> collect expr (paths_rev, values_rev)
    | Pexp_poly (expr, _) -> collect expr (paths_rev, values_rev)
    | Pexp_open (_, expr) -> collect expr (paths_rev, values_rev)
    | Pexp_letop { let_; ands; body } ->
        let paths_rev, values_rev = collect let_.pbop_exp (paths_rev, values_rev) in
        let binding_names = Bindings.of_pattern let_.pbop_pat in
        let paths_rev, values_rev =
          List.fold_left
            (fun (paths_rev, values_rev) and_op ->
              let paths_rev, values_rev =
                collect and_op.pbop_exp (paths_rev, values_rev)
              in
              let and_names = Bindings.of_pattern and_op.pbop_pat in
              (paths_rev, add_values values_rev and_names))
            (paths_rev, values_rev) ands
        in
        let values_rev = add_values values_rev binding_names in
        collect body (paths_rev, values_rev)
    | Pexp_extension _ -> (
        match Platform.browser_only_payload expression with
        | Some payload -> collect payload (paths_rev, values_rev)
        | None -> (
            match Platform.client_case expression with
            | Some case ->
                let values_rev =
                  add_values values_rev (Bindings.of_pattern case.pc_lhs)
                in
                collect case.pc_rhs (paths_rev, values_rev)
            | None -> (paths_rev, values_rev)))
    | _ -> (paths_rev, values_rev)
  and collect_params params (paths_rev, values_rev) =
    List.fold_left
      (fun (paths_rev, values_rev) (p : Parsetree.function_param) ->
        match p.pparam_desc with
        | Pparam_val (_, default_arg, pat) ->
            let paths_rev, values_rev =
              match default_arg with
              | None -> (paths_rev, values_rev)
              | Some e -> collect e (paths_rev, values_rev)
            in
            (paths_rev, add_values values_rev (Bindings.of_pattern pat))
        | Pparam_newtype _ -> (paths_rev, values_rev))
      (paths_rev, values_rev) params
  in
  let paths_rev, values_rev = collect expression ([], []) in
  { used_paths = List.rev paths_rev; bound_names = List.rev values_rev }
