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
  let add_path path (paths_rev, values_rev) = (path :: paths_rev, values_rev) in
  let rec collect (expression : Parsetree.expression) acc =
    match expression.pexp_desc with
    | Pexp_ident { txt = ident; _ } -> add_path (path_of_ident ident) acc
    | Pexp_let (_, value_bindings, expr) ->
        let acc =
          List.fold_left
            (fun (paths_rev, values_rev) value ->
              let binding_names = Bindings.of_pattern value.pvb_pat in
              let func_params = Bindings.function_params value.pvb_expr in
              let values_rev =
                values_rev |> add_values binding_names |> add_values func_params
              in
              collect value.pvb_expr (paths_rev, values_rev))
            acc value_bindings
        in
        collect expr acc
    | Pexp_function (params, _, body) -> (
        let acc = collect_params params acc in
        match body with
        | Pfunction_body body -> collect body acc
        | Pfunction_cases (cases, _, _) -> List.fold_left collect_case acc cases
        )
    | Pexp_apply (fn_expr, labeled_expr) ->
        let acc =
          match path_of_expression fn_expr with
          | Some { root = Lident name; fields = [] } when is_operator name ->
              acc
          | Some path -> add_path path acc
          | None -> collect fn_expr acc
        in
        collect_all (List.map snd labeled_expr) acc
    | Pexp_match (expr, cases) | Pexp_try (expr, cases) ->
        List.fold_left collect_case (collect expr acc) cases
    | Pexp_tuple exprs | Pexp_array exprs -> collect_all exprs acc
    | Pexp_construct ({ txt = Lident "None"; _ }, _) -> acc
    | Pexp_construct (_, Some expr)
    | Pexp_variant (_, Some expr)
    | Pexp_constraint (expr, _)
    | Pexp_newtype (_, expr)
    | Pexp_coerce (expr, _, _)
    | Pexp_send (expr, _)
    | Pexp_setinstvar (_, expr)
    | Pexp_letmodule (_, _, expr)
    | Pexp_letexception (_, expr)
    | Pexp_assert expr
    | Pexp_lazy expr
    | Pexp_poly (expr, _)
    | Pexp_open (_, expr) ->
        collect expr acc
    | Pexp_record (fields, base) ->
        collect_all (Option.to_list base @ List.map snd fields) acc
    | Pexp_override fields -> collect_all (List.map snd fields) acc
    | Pexp_field (expr, _) -> (
        match path_of_expression expression with
        | Some path -> add_path path acc
        | None -> collect expr acc)
    | Pexp_setfield (expr1, field, expr2) ->
        let written_path =
          match field.txt with
          | Lident name -> path_with_fields expr1 [ name ]
          | _ -> None
        in
        let acc =
          match written_path with
          | Some path -> add_path path acc
          | None -> collect expr1 acc
        in
        collect expr2 acc
    | Pexp_ifthenelse (expr1, expr2, else_expr) ->
        collect_all ([ expr1; expr2 ] @ Option.to_list else_expr) acc
    | Pexp_sequence (expr1, expr2) | Pexp_while (expr1, expr2) ->
        collect_all [ expr1; expr2 ] acc
    | Pexp_for (pat, expr1, expr2, _, expr3) ->
        let paths_rev, values_rev = acc in
        let loop_var = Bindings.of_pattern pat in
        collect_all [ expr1; expr2; expr3 ]
          (paths_rev, add_values values_rev loop_var)
    | Pexp_letop { let_; ands; body } ->
        let acc = collect let_.pbop_exp acc in
        let binding_names = Bindings.of_pattern let_.pbop_pat in
        let paths_rev, values_rev =
          List.fold_left
            (fun acc and_op ->
              let paths_rev, values_rev = collect and_op.pbop_exp acc in
              let and_names = Bindings.of_pattern and_op.pbop_pat in
              (paths_rev, add_values values_rev and_names))
            acc ands
        in
        collect body (paths_rev, add_values values_rev binding_names)
    | Pexp_extension _ -> (
        match Platform.browser_only_payload expression with
        | Some payload -> collect payload acc
        | None -> (
            match Platform.client_case expression with
            | Some case -> collect_case acc case
            | None -> acc))
    | _ -> acc
  and collect_all exprs acc =
    List.fold_left (fun acc expr -> collect expr acc) acc exprs
  and collect_case (paths_rev, values_rev) (case : Parsetree.case) =
    let values_rev = add_values values_rev (Bindings.of_pattern case.pc_lhs) in
    collect_all
      (Option.to_list case.pc_guard @ [ case.pc_rhs ])
      (paths_rev, values_rev)
  and collect_params params acc =
    List.fold_left
      (fun acc (p : Parsetree.function_param) ->
        match p.pparam_desc with
        | Pparam_val (_, default_arg, pat) ->
            let paths_rev, values_rev =
              collect_all (Option.to_list default_arg) acc
            in
            (paths_rev, add_values values_rev (Bindings.of_pattern pat))
        | Pparam_newtype _ -> acc)
      acc params
  in
  let paths_rev, values_rev = collect expression ([], []) in
  { used_paths = List.rev paths_rev; bound_names = List.rev values_rev }
