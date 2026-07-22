open Ppxlib
module StringSet = Set.Make (String)
module StringMap = Map.Make (String)

type t = {
  static_deps : StringSet.t;
  outer_bindings : StringSet.t;
  component_bindings : StringSet.t;
  browser_only_hooks : StringSet.t;
  stable_hooks : Stable.shape StringMap.t;
}

type kind = Component | Custom_hook | Function | Value

let component_attributes =
  [ "react.component"; "react.client.component"; "react.async.component" ]

let has_component_attribute attrs =
  attrs
  |> List.exists (fun { attr_name; _ } ->
      List.mem attr_name.txt component_attributes)

let classify (t : Parsetree.value_binding) =
  let is_function =
    match Platform.match_payload t.pvb_expr with
    | Some (_, cases) ->
        List.exists
          (fun (case : Parsetree.case) ->
            Option.is_some (Bindings.function_body case.pc_rhs))
          cases
    | None -> Option.is_some (Bindings.function_body t.pvb_expr)
  in
  if not is_function then Value
  else
    let names = Bindings.of_pattern t.pvb_pat in
    if
      has_component_attribute t.pvb_attributes
      || has_component_attribute t.pvb_pat.ppat_attributes
    then Component
    else if List.exists Hook.is_hook_name names then Custom_hook
    else Function

let initial =
  {
    static_deps = StringSet.empty;
    outer_bindings = StringSet.empty;
    component_bindings = StringSet.empty;
    browser_only_hooks = StringSet.empty;
    stable_hooks = StringMap.empty;
  }

let stable_lookup scope name = StringMap.find_opt name scope.stable_hooks

let enter_binding kind ~in_component_or_hook (t : Parsetree.value_binding) scope
    =
  let binding_names = Bindings.of_pattern t.pvb_pat in
  let scope =
    {
      scope with
      browser_only_hooks =
        StringSet.diff scope.browser_only_hooks
          (StringSet.of_list binding_names);
      stable_hooks =
        List.fold_left
          (fun map name -> StringMap.remove name map)
          scope.stable_hooks binding_names;
    }
  in
  let is_plain_binding = kind = Value || kind = Function in
  let scope =
    if not is_plain_binding then scope
    else if in_component_or_hook then
      {
        scope with
        component_bindings =
          StringSet.union scope.component_bindings
            (StringSet.of_list binding_names);
      }
    else
      {
        scope with
        outer_bindings =
          StringSet.union scope.outer_bindings (StringSet.of_list binding_names);
      }
  in
  let scope =
    match Stable.static_deps_of_binding ~lookup:(stable_lookup scope) t with
    | [] -> scope
    | new_static_deps ->
        {
          scope with
          static_deps =
            StringSet.union scope.static_deps
              (StringSet.of_list new_static_deps);
        }
  in
  match Stable.wrapper_shape ~lookup:(stable_lookup scope) t with
  | Some (name, shape) ->
      { scope with stable_hooks = StringMap.add name shape scope.stable_hooks }
  | None -> scope

let binding_body kind (t : Parsetree.value_binding) scope =
  match kind with
  | Component | Custom_hook ->
      let function_params =
        StringSet.of_list
          (Bindings.function_params t.pvb_expr @ Bindings.label_names t.pvb_expr)
      in
      {
        scope with
        static_deps = StringSet.empty;
        component_bindings = function_params;
      }
  | Function | Value -> scope

let exit_binding kind ~entered ~traversed =
  let enters_new_scope = kind = Component || kind = Custom_hook in
  if enters_new_scope then
    {
      traversed with
      static_deps = entered.static_deps;
      component_bindings = entered.component_bindings;
      stable_hooks = entered.stable_hooks;
    }
  else traversed

let static_deps scope = scope.static_deps
let outer_bindings scope = scope.outer_bindings
let component_bindings scope = scope.component_bindings

let is_browser_only_hook_wrapper (vb : Parsetree.value_binding) : bool =
  match Bindings.function_body vb.pvb_expr with
  | Some _ -> Hook.expression_has_hook_calls vb.pvb_expr
  | None -> (
      match vb.pvb_expr.pexp_desc with
      | Pexp_ident { txt; _ } -> Hook.is_hook_ident txt
      | _ -> false)

let track_browser_only_wrappers (vbs : Parsetree.value_binding list) scope =
  let names =
    vbs
    |> List.filter is_browser_only_hook_wrapper
    |> List.concat_map (fun (vb : Parsetree.value_binding) ->
        Bindings.of_pattern vb.pvb_pat)
  in
  {
    scope with
    browser_only_hooks =
      StringSet.union scope.browser_only_hooks (StringSet.of_list names);
  }

let is_tracked_browser_only_hook scope (lident : Longident.t) : bool =
  match lident with
  | Lident name -> StringSet.mem name scope.browser_only_hooks
  | _ -> false

let browser_only_snapshot scope = scope.browser_only_hooks
let restore_browser_only saved scope = { scope with browser_only_hooks = saved }
