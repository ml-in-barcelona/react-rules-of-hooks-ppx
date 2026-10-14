open Ppxlib
module StringSet = Set.Make (String)

module LocationSet = Set.Make (struct
  type t = Location.t

  let compare = Stdlib.compare
end)

let disable_order_of_hooks_attribute = "disable_order_of_hooks"
let disable_exhaustive_deps_attribute = "disable_exhaustive_deps"
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

let unique (type a) (module Set : Set.S with type elt = a) (list : a list) =
  let _, acc_rev =
    List.fold_left
      (fun (seen, acc_rev) item ->
        if Set.mem item seen then (seen, acc_rev)
        else (Set.add item seen, item :: acc_rev))
      (Set.empty, []) list
  in
  List.rev acc_rev

let unique_strings = unique (module StringSet)
let unique_locations = unique (module LocationSet)

let find_duplicates list =
  let rec go seen dups = function
    | [] -> StringSet.elements dups
    | x :: xs ->
        if StringSet.mem x seen then go seen (StringSet.add x dups) xs
        else go (StringSet.add x seen) dups xs
  in
  go StringSet.empty StringSet.empty list

let quotes = Printf.sprintf "'%s'"
let quoted_list list = list |> List.map quotes |> String.concat ", "

let unique_path_strings (paths : Deps.path list) =
  paths |> List.map Deps.path_to_string |> unique_strings

let is_reason_file (ctx : Expansion_context.Base.t) =
  let filename = Expansion_context.Base.input_name ctx in
  Filename.check_suffix filename ".re" || Filename.check_suffix filename ".rei"

let suppress_exhaustive_deps_hint ~is_reason =
  if is_reason then
    "To suppress this warning, add [@disable_exhaustive_deps] before the \
     expression"
  else
    "To suppress this warning, add [@disable_exhaustive_deps] to the expression"

let format_deps (deps : string list) : string =
  match deps with
  | [] -> "[||]"
  | [ dep ] -> "[| " ^ dep ^ " |]"
  | _ -> "(" ^ String.concat ", " deps ^ ")"

let dependency_noun list =
  if List.length list = 1 then "dependency" else "dependencies"

let check_duplicate_deps ~is_reason ~deps_loc (declared_paths : Deps.path list)
    =
  let duplicate_deps =
    find_duplicates (List.map Deps.path_to_string declared_paths)
  in
  if duplicate_deps = [] then []
  else
    let msg =
      Printf.sprintf
        "exhaustive-deps: Duplicate %s %s in the dependency array.\n%s"
        (dependency_noun duplicate_deps)
        (quoted_list duplicate_deps)
        (suppress_exhaustive_deps_hint ~is_reason)
    in
    [ Driver.Lint_error.of_string deps_loc msg ]

let register_missing_deps_correction ~hook_info ~fn_loc ~expr_loc ~deps_loc
    ~deps_arg ~callback_arg ~all_deps ~total_dep_count =
  let needs_rename (info : Hook.With_deps.t) =
    match info.variant with None -> true | Some n -> n <> total_dep_count
  in
  let renamed_hook = Hook.With_deps.with_variant hook_info total_dep_count in
  let corrected_deps = format_deps all_deps in
  match (deps_arg, callback_arg) with
  | None, Some (_, callback_expr) when needs_rename hook_info ->
      let callback_str =
        Format.asprintf "%a" Pprintast.expression callback_expr
      in
      let full_correction =
        Printf.sprintf "%s (%s) %s" renamed_hook callback_str corrected_deps
      in
      Driver.register_correction ~loc:expr_loc ~repl:full_correction
  | None, _ -> ()
  | Some _, _ ->
      Driver.register_correction ~loc:deps_loc ~repl:corrected_deps;
      if needs_rename hook_info then
        Driver.register_correction ~loc:fn_loc ~repl:renamed_hook

let check_missing_deps ~is_reason ~deps_loc ~hook_info ~fn_loc ~expr_loc
    ~deps_arg ~callback_arg ~(static_deps : StringSet.t)
    ~(component_scope_bindings : StringSet.t) ~(declared_paths : Deps.path list)
    ~(body_paths : Deps.path list) =
  let is_required_dependency path =
    let root = Deps.root_name path in
    let is_component_value =
      StringSet.mem root component_scope_bindings
      && not (Deps.is_qualified path)
    in
    let is_stable = StringSet.mem root static_deps in
    is_component_value && not is_stable
  in
  let is_declared path =
    List.exists
      (fun declared -> Deps.is_prefix ~prefix:declared ~path)
      declared_paths
  in
  let uncovered_paths =
    body_paths
    |> List.filter is_required_dependency
    |> List.filter (fun path -> not (is_declared path))
  in
  let missing =
    (* When both a path and one of its prefixes are missing, the prefix covers
       it: report only the shallowest paths ('input' subsumes 'input.page'). *)
    uncovered_paths
    |> List.filter (fun path ->
        not
          (List.exists
             (fun other -> Deps.is_strict_prefix ~prefix:other ~path)
             uncovered_paths))
    |> unique_path_strings
  in
  if missing = [] then []
  else
    let all_deps = unique_path_strings declared_paths @ missing in
    let total_dep_count = List.length all_deps in
    if !enable_corrections_flag then
      register_missing_deps_correction ~hook_info ~fn_loc ~expr_loc ~deps_loc
        ~deps_arg ~callback_arg ~all_deps ~total_dep_count;
    let msg =
      Printf.sprintf
        "exhaustive-deps: Missing %s %s from the dependency array.\n%s"
        (dependency_noun missing) (quoted_list missing)
        (suppress_exhaustive_deps_hint ~is_reason)
    in
    [ Driver.Lint_error.of_string deps_loc msg ]

let check_outer_scope_deps ~is_reason ~deps_loc ~name
    ~(outer_scope_bindings : StringSet.t) ~(declared_paths : Deps.path list) =
  let outer_scope_deps =
    declared_paths
    |> List.filter (fun path ->
        StringSet.mem (Deps.root_name path) outer_scope_bindings)
  in
  let external_module_deps = List.filter Deps.is_qualified declared_paths in
  let all_outer_scope =
    unique_path_strings (outer_scope_deps @ external_module_deps)
  in
  if all_outer_scope = [] then []
  else
    let msg =
      Printf.sprintf
        "exhaustive-deps: %s has %s: %s. Outer scope values like %s aren't \
         valid dependencies because they are constant and never change between \
         renders.\n\
         %s"
        name
        (if List.length all_outer_scope = 1 then "an unnecessary dependency"
         else "unnecessary dependencies")
        (quoted_list all_outer_scope)
        (List.hd all_outer_scope |> quotes)
        (suppress_exhaustive_deps_hint ~is_reason)
    in
    [ Driver.Lint_error.of_string deps_loc msg ]

let find_direct_setter_call ~(setters : StringSet.t)
    (body : Parsetree.expression) : string option =
  let exception Found of string in
  let scanner =
    object
      inherit Ast_traverse.iter as super

      method! expression e =
        match e.pexp_desc with
        | Pexp_function _ -> ()
        | Pexp_apply ({ pexp_desc = Pexp_ident { txt = Lident name; _ }; _ }, _)
          when StringSet.mem name setters ->
            raise (Found name)
        | _ -> super#expression e
    end
  in
  try
    scanner#expression body;
    None
  with Found name -> Some name

let check_no_deps_effect ~(static_deps : StringSet.t) ~name ~loc callback_arg :
    Driver.Lint_error.t list =
  let direct_setter =
    match callback_arg with
    | Some (_, fn_expr) ->
        Option.bind
          (Bindings.function_body fn_expr)
          (find_direct_setter_call ~setters:static_deps)
    | None -> None
  in
  match direct_setter with
  | Some setter ->
      let msg =
        Printf.sprintf
          "exhaustive-deps: This effect contains a call to '%s'. Without a \
           dependency array, this can lead to an infinite chain of updates. \
           Use %s0 or add a dependency array."
          setter name
      in
      [ Driver.Lint_error.of_string loc msg ]
  | None -> []

let no_deps_memo_error ~name ~loc : Driver.Lint_error.t list =
  let msg =
    Printf.sprintf
      "exhaustive-deps: %s does nothing when called without a dependency \
       array. Did you mean %sN with dependencies?"
      name name
  in
  [ Driver.Lint_error.of_string loc msg ]

let check_hook_deps_exhaustiveness (ctx : Expansion_context.Base.t)
    ~(static_deps : StringSet.t) ~(outer_scope_bindings : StringSet.t)
    ~(component_scope_bindings : StringSet.t) (call : Hook.With_deps.call)
    (e : Parsetree.expression) : Driver.Lint_error.t list =
  let { Hook.With_deps.name; info = hook_info; fn_loc; callback_arg; deps_arg }
      =
    call
  in
  let body_deps =
    (match callback_arg with
      | Some (_, fn_expr) -> Bindings.function_body fn_expr
      | _ -> None)
    |> Option.map Deps.of_expression
    |> Option.value ~default:{ Deps.used_paths = []; bound_names = [] }
  in
  let bound_names = StringSet.of_list body_deps.bound_names in
  let body_paths =
    body_deps.used_paths
    |> List.filter (fun path ->
        not (StringSet.mem (Deps.root_name path) bound_names))
  in
  let declared_paths =
    deps_arg
    |> Option.map (fun (_, deps) -> (Deps.of_expression deps).used_paths)
    |> Option.value ~default:[]
  in
  let deps_loc =
    match deps_arg with
    | Some (_, deps_expr) -> deps_expr.pexp_loc
    | None -> e.pexp_loc
  in
  let is_reason = is_reason_file ctx in
  check_duplicate_deps ~is_reason ~deps_loc declared_paths
  @ check_missing_deps ~is_reason ~deps_loc ~hook_info ~fn_loc
      ~expr_loc:e.pexp_loc ~deps_arg ~callback_arg ~static_deps
      ~component_scope_bindings ~declared_paths ~body_paths
  @ check_outer_scope_deps ~is_reason ~deps_loc ~name ~outer_scope_bindings
      ~declared_paths

let check_hook_deps (ctx : Expansion_context.Base.t)
    ~(static_deps : StringSet.t) ~(outer_scope_bindings : StringSet.t)
    ~(component_scope_bindings : StringSet.t) (e : Parsetree.expression) :
    Driver.Lint_error.t list =
  match Hook.With_deps.call e with
  | None -> []
  | Some call -> (
      let disabled_on_call =
        Hook.has_attribute disable_exhaustive_deps_attribute e.pexp_attributes
      in
      let disabled_on_deps_arg =
        match call.deps_arg with
        | Some (_, deps_expr) ->
            Hook.has_attribute disable_exhaustive_deps_attribute
              deps_expr.pexp_attributes
        | None -> false
      in
      let deps_check_disabled = disabled_on_call || disabled_on_deps_arg in
      if deps_check_disabled then []
      else
        match (call.deps_arg, call.info) with
        | ( None,
            {
              base = "useEffect" | "useLayoutEffect" | "useInsertionEffect";
              variant = None;
              _;
            } ) ->
            check_no_deps_effect ~static_deps ~name:call.name ~loc:e.pexp_loc
              call.callback_arg
        | None, { base = "useMemo" | "useCallback"; variant = None; _ } ->
            no_deps_memo_error ~name:call.name ~loc:e.pexp_loc
        | _ ->
            check_hook_deps_exhaustiveness ctx ~static_deps
              ~outer_scope_bindings ~component_scope_bindings call e)

type hook_context = {
  is_inside_component : bool;
  is_inside_custom_hook : bool;
  is_inside_conditional : bool;
  is_inside_jsx : bool;
  is_order_of_hooks_disabled : bool;
  is_exhaustive_deps_disabled : bool;
}

type analysis_state = {
  context : hook_context;
  scope : Scope.t;
  lint_errors_rev : Driver.Lint_error.t list;
  conditional_locations_rev : Location.t list;
  outside_locations_rev : Location.t list;
}

type analysis = {
  lint_errors : Driver.Lint_error.t list;
  conditional_locations : Location.t list;
  outside_locations : Location.t list;
}

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
        is_order_of_hooks_disabled = false;
        is_exhaustive_deps_disabled = false;
      };
    scope = Scope.initial;
    lint_errors_rev = [];
    conditional_locations_rev = [];
    outside_locations_rev = [];
  }

let binding_body_context (kind : Scope.kind) context =
  match kind with
  | Component | Custom_hook ->
      {
        context with
        is_inside_component = kind = Scope.Component;
        is_inside_custom_hook = kind = Scope.Custom_hook;
      }
  | Function ->
      {
        context with
        is_inside_component = false;
        is_inside_custom_hook = false;
      }
  | Value -> context

let is_inside_component_or_hook context =
  context.is_inside_component || context.is_inside_custom_hook

let make_linter ~(ctx : Expansion_context.Base.t) ~check_exhaustive
    ~check_order_of_hooks =
  object (self)
    inherit [analysis_state] Ast_traverse.fold as super

    method! value_binding t state =
      self#binding_with_kind (Scope.classify t) t state

    method private browser_only_binding vb state =
      let wraps_hook_in_function =
        Scope.is_browser_only_hook_wrapper vb
        && Option.is_some (Bindings.function_body vb.pvb_expr)
      in
      if wraps_hook_in_function then
        self#binding_with_kind Scope.Custom_hook vb state
      else self#value_binding vb state

    method private binding_with_kind kind t state =
      let entered =
        Scope.enter_binding kind
          ~in_component_or_hook:(is_inside_component_or_hook state.context)
          t state.scope
      in
      let disabled_for_binding ~attribute ~inherited =
        inherited || Hook.has_attribute attribute t.pvb_attributes
      in
      let body_state =
        {
          state with
          context =
            {
              (binding_body_context kind state.context) with
              is_order_of_hooks_disabled =
                disabled_for_binding ~attribute:disable_order_of_hooks_attribute
                  ~inherited:state.context.is_order_of_hooks_disabled;
              is_exhaustive_deps_disabled =
                disabled_for_binding
                  ~attribute:disable_exhaustive_deps_attribute
                  ~inherited:state.context.is_exhaustive_deps_disabled;
            };
          scope = Scope.binding_body kind t entered;
        }
      in
      let after = super#value_binding t body_state in
      {
        after with
        context = state.context;
        scope = Scope.exit_binding kind ~entered ~traversed:after.scope;
      }

    method! structure_item t state =
      match Platform.browser_only_value_bindings t with
      | Some vbs ->
          let state =
            List.fold_left
              (fun state vb -> self#browser_only_binding vb state)
              state vbs
          in
          {
            state with
            scope = Scope.track_browser_only_wrappers vbs state.scope;
          }
      | None -> super#structure_item t state

    method private collect_exhaustive_deps_errors ~is_disabled expr state =
      let deps_check_skipped = (not check_exhaustive) || is_disabled in
      if deps_check_skipped then state
      else
        match
          check_hook_deps ctx
            ~static_deps:(Scope.static_deps state.scope)
            ~outer_scope_bindings:(Scope.outer_bindings state.scope)
            ~component_scope_bindings:(Scope.component_bindings state.scope)
            expr
        with
        | [] -> state
        | errors ->
            {
              state with
              lint_errors_rev = List.rev_append errors state.lint_errors_rev;
            }

    method private collect_hook_order_errors ~is_disabled ~is_conditional_or_jsx
        ~is_outside_component_or_hook (expr : Parsetree.expression) state =
      let order_check_skipped = (not check_order_of_hooks) || is_disabled in
      if order_check_skipped then state
      else
        match Hook.call_ident expr with
        | Some lident ->
            let is_hook_call =
              Hook.is_hook_ident lident
              || Scope.is_tracked_browser_only_hook state.scope lident
            in
            let opted_out =
              Hook.has_attribute disable_order_of_hooks_attribute
                expr.pexp_attributes
            in
            if (not is_hook_call) || opted_out then state
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
        | None -> state

    method! expression t state =
      let state =
        {
          state with
          context =
            {
              state.context with
              is_inside_jsx =
                state.context.is_inside_jsx || Hook.is_jsx t.pexp_attributes;
            };
        }
      in
      let hook_context = state.context in
      let mark_conditional state =
        {
          state with
          context = { state.context with is_inside_conditional = true };
        }
      in
      let visit_conditionally expr state =
        self#expression expr (mark_conditional state)
      in
      let restore_context original_ctx state =
        { state with context = original_ctx }
      in
      let state =
        match (Platform.match_payload t, Platform.browser_only_payload t) with
        | Some (scrut, cases), _ ->
            let state = self#expression scrut state in
            List.fold_left
              (fun state case -> self#expression case.pc_rhs state)
              state cases
        | None, Some payload -> (
            match payload.pexp_desc with
            | Pexp_let (_, vbs, body) ->
                let saved_browser_only =
                  Scope.browser_only_snapshot state.scope
                in
                let state =
                  List.fold_left
                    (fun state vb -> self#browser_only_binding vb state)
                    state vbs
                in
                let state =
                  {
                    state with
                    scope = Scope.track_browser_only_wrappers vbs state.scope;
                  }
                in
                let state = self#expression body state in
                {
                  state with
                  scope =
                    Scope.restore_browser_only saved_browser_only state.scope;
                }
            | _ -> self#expression payload state)
        | None, None -> (
            match t.pexp_desc with
            | Pexp_match (expr, cases) ->
                let state = self#expression expr state in
                List.fold_left
                  (fun state case -> visit_conditionally case.pc_rhs state)
                  state cases
            | Pexp_try (expr, cases) ->
                let state = visit_conditionally expr state in
                List.fold_left
                  (fun state case -> visit_conditionally case.pc_rhs state)
                  state cases
            | Pexp_while (cond, expr) ->
                let state = self#expression cond state in
                visit_conditionally expr state
            | Pexp_for (_, start_expr, end_expr, _, body) ->
                let state = self#expression start_expr state in
                let state = self#expression end_expr state in
                visit_conditionally body state
            | Pexp_ifthenelse (if_expr, then_expr, else_expr) -> (
                let state = self#expression if_expr state in
                let state = visit_conditionally then_expr state in
                match else_expr with
                | Some expr -> visit_conditionally expr state
                | None -> state)
            | Pexp_lazy expr | Pexp_assert expr ->
                visit_conditionally expr state
            | Pexp_apply
                ( { pexp_desc = Pexp_ident { txt = Lident ("&&" | "||"); _ }; _ },
                  args ) ->
                List.fold_left
                  (fun state (_, arg_expr) ->
                    visit_conditionally arg_expr state)
                  state args
            | Pexp_function (params, _, func_body) ->
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
                      {
                        state.context with
                        is_inside_jsx = hook_context.is_inside_jsx;
                      };
                  }
                in
                begin match func_body with
                | Pfunction_body body -> self#expression body state_for_body
                | Pfunction_cases (cases, _, _) ->
                    List.fold_left
                      (fun state case -> self#case case state)
                      state_for_body cases
                end
            | _ -> (
                match Hook.With_deps.call t with
                | Some { callback_arg; deps_arg; _ } ->
                    let state =
                      match callback_arg with
                      | Some (_, callback_expr) ->
                          visit_conditionally callback_expr state
                      | None -> state
                    in
                    begin match deps_arg with
                    | Some (_, deps_expr) -> self#expression deps_expr state
                    | None -> state
                    end
                | None -> super#expression t state))
      in
      let is_conditional_or_jsx =
        hook_context.is_inside_conditional || hook_context.is_inside_jsx
      in
      state
      |> restore_context hook_context
      |> self#collect_exhaustive_deps_errors
           ~is_disabled:hook_context.is_exhaustive_deps_disabled t
      |> self#collect_hook_order_errors
           ~is_disabled:hook_context.is_order_of_hooks_disabled
           ~is_conditional_or_jsx
           ~is_outside_component_or_hook:
             (not (is_inside_component_or_hook hook_context))
           t
  end

let compute_analysis (ctx : Expansion_context.Base.t)
    (structure : Parsetree.structure) : analysis =
  if not (Hook.structure_has_hook_calls structure) then empty_analysis
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
