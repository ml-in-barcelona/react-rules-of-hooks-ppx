open Ppxlib

type shape = Snd | All

let shape_of_call ~(lookup : string -> shape option)
    (expr : Parsetree.expression) : shape option =
  match Hook.call_ident expr with
  | Some txt -> (
      match Longident.name txt with
      | "useState" | "React.useState" | "useReducer" | "React.useReducer" ->
          Some Snd
      | "useRef" | "React.useRef" -> Some All
      | _ -> ( match txt with Lident name -> lookup name | _ -> None))
  | None -> None

let wrapper_shape ~lookup (vb : Parsetree.value_binding) :
    (string * shape) option =
  match vb.pvb_pat.ppat_desc with
  | Ppat_var { txt = name; _ } when Hook.is_hook_name name -> (
      match shape_of_call ~lookup (Bindings.body_of_fun_chain vb.pvb_expr) with
      | Some shape -> Some (name, shape)
      | None -> None)
  | _ -> None

let looks_like_setter name =
  String.starts_with ~prefix:"dispatch" name
  || String.starts_with ~prefix:"set" name
     && String.length name > 3
     && ((name.[3] >= 'A' && name.[3] <= 'Z') || name.[3] = '_')

let is_any_hook_call (expr : Parsetree.expression) =
  Option.is_some (Hook.hook_call expr)

let second_tuple_element_names (pattern : Parsetree.pattern) : string list =
  match pattern.ppat_desc with
  | Ppat_tuple (_ :: pat2 :: _) -> Bindings.of_pattern pat2
  | _ -> []

let setter_bound_names (pattern : Parsetree.pattern) : string list =
  match pattern.ppat_desc with
  | Ppat_record (fields, _) ->
      fields
      |> List.filter_map
           (fun
             ((field : Longident.t Location.loc), (pat : Parsetree.pattern)) ->
             match Hook.last_component field.txt with
             | Some field_name when looks_like_setter field_name ->
                 Some (Bindings.of_pattern pat)
             | _ -> None)
      |> List.concat
  | _ -> []

let static_deps_of_binding ~lookup (vb : Parsetree.value_binding) : string list
    =
  let expr = Platform.client_view vb.pvb_expr in
  let pattern = vb.pvb_pat in
  match shape_of_call ~lookup expr with
  | Some Snd -> second_tuple_element_names pattern
  | Some All -> Bindings.of_pattern pattern
  | None ->
      if is_any_hook_call expr then
        (second_tuple_element_names pattern |> List.filter looks_like_setter)
        @ setter_bound_names pattern
      else []
