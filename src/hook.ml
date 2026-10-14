open Ppxlib

let is_hook_name name =
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

let last_component (longident : Longident.t) =
  match longident with Lident l -> Some l | Ldot (_, l) -> Some l | _ -> None

let is_hook_ident longident =
  match last_component longident with
  | Some name -> is_hook_name name
  | None -> false

let has_attribute name (attrs : attributes) =
  attrs |> List.exists (fun { attr_name; _ } -> attr_name.txt = name)

let is_jsx = has_attribute "JSX"

let call_ident (expr : Parsetree.expression) : Longident.t option =
  match expr.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, _)
    when not (is_jsx expr.pexp_attributes) ->
      Some txt
  | _ -> None

let hook_call (expr : Parsetree.expression) : Longident.t option =
  match call_ident expr with
  | Some lident when is_hook_ident lident -> Some lident
  | _ -> None

exception Hook_found

let hook_scanner =
  object
    inherit Ast_traverse.iter as super

    method! expression e =
      match hook_call e with
      | Some _ -> raise Hook_found
      | None -> super#expression e
  end

let contains_hook_call scan =
  try
    scan hook_scanner;
    false
  with Hook_found -> true

let expression_has_hook_calls expr =
  contains_hook_call (fun scanner -> scanner#expression expr)

let structure_has_hook_calls structure =
  contains_hook_call (fun scanner -> scanner#structure structure)

module With_deps = struct
  type t = { prefix : string; base : string; variant : int option }

  let bases =
    [
      "useEffect";
      "useLayoutEffect";
      "useInsertionEffect";
      "useCallback";
      "useMemo";
    ]

  let prefixes = [ "React."; "" ]

  let decode (name : string) : t option =
    let try_parse prefix base =
      let full_base = prefix ^ base in
      if String.starts_with ~prefix:full_base name then
        let suffix =
          String.sub name (String.length full_base)
            (String.length name - String.length full_base)
        in
        match suffix with
        | "" -> Some { prefix; base; variant = None }
        | "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" ->
            Some { prefix; base; variant = Some (int_of_string suffix) }
        | _ -> None
      else None
    in
    List.find_map
      (fun base -> List.find_map (fun prefix -> try_parse prefix base) prefixes)
      bases

  let with_variant t variant = t.prefix ^ t.base ^ string_of_int variant

  type call = {
    name : string;
    info : t;
    fn_loc : Location.t;
    callback_arg : (arg_label * Parsetree.expression) option;
    deps_arg : (arg_label * Parsetree.expression) option;
  }

  let call (expr : Parsetree.expression) : call option =
    match expr.pexp_desc with
    | Pexp_apply
        ({ pexp_desc = Pexp_ident { txt; _ }; pexp_loc = fn_loc; _ }, args) ->
        let name = Longident.name txt in
        decode name
        |> Option.map (fun info ->
            {
              name;
              info;
              fn_loc;
              callback_arg = List.nth_opt args 0;
              deps_arg = List.nth_opt args 1;
            })
    | _ -> None
end
