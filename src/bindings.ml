open Ppxlib

let rec of_pattern (pattern : Parsetree.pattern) : string list =
  match pattern.ppat_desc with
  | Ppat_var { txt; _ } -> [ txt ]
  | Ppat_tuple patterns -> List.concat_map of_pattern patterns
  | Ppat_record (fields, _) ->
      List.concat_map (fun (_, pat) -> of_pattern pat) fields
  | Ppat_construct (_, Some (_, pat)) -> of_pattern pat
  | Ppat_variant (_, Some pat) -> of_pattern pat
  | Ppat_or (p1, p2) -> of_pattern p1 @ of_pattern p2
  | Ppat_constraint (pat, _) -> of_pattern pat
  | Ppat_alias (pat, { txt; _ }) -> txt :: of_pattern pat
  | Ppat_array patterns -> List.concat_map of_pattern patterns
  | Ppat_lazy pat -> of_pattern pat
  | Ppat_open (_, pat) -> of_pattern pat
  | Ppat_exception pat -> of_pattern pat
  | Ppat_any -> []
  | Ppat_constant _ -> []
  | Ppat_interval _ -> []
  | Ppat_construct (_, None) -> []
  | Ppat_variant (_, None) -> []
  | Ppat_type _ -> []
  | Ppat_unpack _ -> []
  | Ppat_extension _ -> []

let of_params (params : Parsetree.function_param list) : string list =
  List.concat_map
    (fun (p : Parsetree.function_param) ->
      match p.pparam_desc with
      | Pparam_val (_, _, pat) -> of_pattern pat
      | Pparam_newtype _ -> [])
    params

let rec function_params (expr : Parsetree.expression) : string list =
  match expr.pexp_desc with
  | Pexp_function (params, _, Pfunction_body body) ->
      of_params params @ function_params body
  | Pexp_function (params, _, Pfunction_cases (cases, _, _)) ->
      let case_params =
        List.concat_map (fun case -> of_pattern case.pc_lhs) cases
      in
      of_params params @ case_params
  | Pexp_constraint (e, _) -> function_params e
  | Pexp_newtype (_, e) -> function_params e
  | _ -> (
      match Platform.match_payload expr with
      | Some (_, cases) ->
          List.concat_map
            (fun (case : Parsetree.case) -> function_params case.pc_rhs)
            cases
      | None -> [])

let rec label_names (expr : Parsetree.expression) : string list =
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
  | Pexp_constraint (e, _) | Pexp_newtype (_, e) -> label_names e
  | _ -> (
      match Platform.match_payload expr with
      | Some (_, cases) ->
          List.concat_map
            (fun (case : Parsetree.case) -> label_names case.pc_rhs)
            cases
      | None -> [])

let rec function_body (expr : Parsetree.expression) :
    Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_function (_, _, Pfunction_body body) -> Some body
  | Pexp_function (_, _, Pfunction_cases _) -> Some expr
  | Pexp_constraint (e, _) -> function_body e
  | _ -> (
      match Platform.browser_only_payload expr with
      | Some payload -> function_body payload
      | None -> None)

let rec body_of_fun_chain (e : Parsetree.expression) : Parsetree.expression =
  match e.pexp_desc with
  | Pexp_function (_, _, Pfunction_body body) -> body_of_fun_chain body
  | Pexp_function
      (_, _, Pfunction_cases ([ { pc_guard = None; pc_rhs; _ } ], _, _)) ->
      body_of_fun_chain pc_rhs
  | Pexp_constraint (e, _) | Pexp_newtype (_, e) -> body_of_fun_chain e
  | _ -> (
      match Platform.client_case e with
      | Some case -> body_of_fun_chain case.pc_rhs
      | None -> e)
