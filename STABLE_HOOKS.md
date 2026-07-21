# Automatic stable-hook detection for exhaustive-deps

Status: implemented (see `test/stable-hooks-*.t`)
Author: davesnx
Date: 2026-07-21 (revised same day against the shipped platform work)
Baseline: react-rules-of-hooks-ppx 1.3.0 (`PLATFORM_BRANCHES.md`, shipped:
`switch%platform` / `let%browser_only` awareness)
Origin: ahrefs monorepo PR #31653 — repo-wide enforcement of
react-rules-of-hooks-ppx 1.2.0 produced ~1,593 `[@disable_exhaustive_deps]`
suppressions; auditing a 528-site sample showed **~25% exist only because the
ppx cannot see that a custom hook's setter is stable**.

## Problem

The exhaustive-deps check already knows that some values never change identity
across renders and exempts them from dependency arrays
(`extract_static_deps_from_binding`, `src/ppx.ml:434` as of 1.3.0):

- `let (v, setV) = useState(...)` / `React.useState` → `setV` stable
- `let (s, dispatch) = useReducer(...)` / `React.useReducer` → `dispatch` stable
- `let r = useRef(...)` / `React.useRef` → `r` stable

Since 1.3.0 the same function first unwraps the `Client` branch of a
`switch%platform` RHS, so
`let (v, setV) = switch%platform { | Client => useState(...) | Server => ... }`
already gets the builtin exemption. Both layers below slot in *after* that
unwrap and inherit platform awareness for free.

Detection is **syntactic and hardcoded**. Any codebase that wraps these
primitives loses the exemption everywhere. The ahrefs monorepo's standard
state hook is exactly such a wrapper:

```reason
/* RR.re */
let useStateValue = initial => useReducer((_ignored, newState) => newState, initial);
```

The returned setter is literally a `useReducer` dispatch — stable by React's
documented guarantee — but at every use site
(`let (isHydrated, setIsHydrated) = RR.useStateValue(false)`) the ppx treats
`setIsHydrated` as a regular dependency and flags every `useEffect0` that
calls it. Since virtually nothing in that codebase calls `React.useState`
directly, this fires on nearly every state-touching effect. The developer
response is `[@disable_exhaustive_deps]` on the whole call, which is strictly
worse: it silences checking of **all** deps, including real ones.

eslint-plugin-react-hooks has the same limitation for custom hooks; it is the
single biggest source of complaints against that rule. React's eventual answer
is type-aware analysis in the React Compiler. In untyped ppx land we cannot do
that, but we can get most of the value automatically — no flags, no
configuration.

## Design: two automatic layers

### Layer 1 — same-file wrapper inference (sound)

While folding structure items, when a binding defines a `use*`-named function
whose body (through the `fun` chain) **is directly an application of a
known-stable hook**, record the wrapper in a per-file table with the same
stability shape:

```reason
let useStateValue = initial => useReducer((_ignored, next) => next, initial);
/* body is directly a useReducer application → useStateValue : Snd (this file) */
```

Lookups consult the builtin list *and* this table, so chains resolve
(`useCounter` calling `useStateValue` calling `useReducer`). This is sound —
it reads the actual definition — and it makes the *defining* module (e.g.
`RR.re`) need no annotations at all. It cannot help consumers in other files:
ppxlib sees one compilation unit, untyped.

Implementation constraints, learned from the 1.3.0 work:

- **The table lives in `analysis_state`, not a global `Hashtbl`.** Everything
  else in the fold threads immutable state with save/restore scoping; 1.3.0's
  `browser_only_hooks : StringSet.t` is the exact precedent (module-level
  entries persist for the rest of the module, a plain rebinding shadows).
  A `stable_hooks : stable_shape StringMap.t` field follows the same
  discipline and needs no per-file reset bookkeeping.
- **Local-wrapper lookup is `Lident`-only.** A qualified call like
  `Other.useStateValue(...)` must not match a *local* `useStateValue`; a
  last-segment fallback would be cross-module guessing inside the layer whose
  point is soundness. Same call 1.3.0 made for `browser_only_hooks` call
  sites.
- **`body_of_fun_chain` reuses the `get_function_body` unwrapping**
  (`Pexp_constraint`, `Pexp_newtype`) and additionally unwraps the `Client`
  branch of a `switch%platform` body, so a per-target wrapper like
  `let use = switch%platform () { | Server => stub | Client => useReducer(...) }`
  infers from the branch that survives in the JS bundle
  (`platform_client_case`, shipped in 1.3.0).
- `extract_static_deps_from_binding` grows a parameter for the table; it is
  called from `binding_with_kind`, which already has the state in hand.

Sketch (names refer to existing code in `src/ppx.ml`):

```ocaml
type stable_shape = Snd | All

let rec body_of_fun_chain (e : Parsetree.expression) =
  match e.pexp_desc with
  | Pexp_function (_, _, Pfunction_body body) -> body_of_fun_chain body
  | Pexp_constraint (e, _) | Pexp_newtype (_, e) -> body_of_fun_chain e
  | _ -> (
      match platform_client_case e with
      | Some case -> body_of_fun_chain case.pc_rhs
      | None -> e)

let stable_shape_of_call ~(stable_hooks : stable_shape StringMap.t)
    (expr : Parsetree.expression) : stable_shape option =
  match expr.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, _) -> (
      match Longident.name txt with
      | "useState" | "React.useState" | "useReducer" | "React.useReducer" ->
          Some Snd
      | "useRef" | "React.useRef" -> Some All
      | _ -> (
          (* local wrappers: Lident only, no cross-module guessing *)
          match txt with
          | Lident name -> StringMap.find_opt name stable_hooks
          | _ -> None))
  | _ -> None

(* in binding_with_kind: *)
let record_stable_wrapper (vb : Parsetree.value_binding) state =
  match vb.pvb_pat.ppat_desc with
  | Ppat_var { txt = name; _ } when is_a_hook_name name -> (
      match
        stable_shape_of_call ~stable_hooks:state.stable_hooks
          (body_of_fun_chain vb.pvb_expr)
      with
      | Some shape ->
          { state with stable_hooks = StringMap.add name shape state.stable_hooks }
      | None -> state)
  | _ -> state
```

### Layer 2 — setter naming convention at the use site (heuristic)

For consumers of wrappers defined elsewhere, the only information available is
the binding shape. Encode the ecosystem convention: **when destructuring the
result of any hook call, an element named like a setter is treated as
stable**:

- pair destructure: the *second* element, if named `set[A-Z]...`,
  `dispatch`, or `dispatch[A-Z]...`;
- record destructure: any element whose *field name* matches the same
  convention (the field carries the API author's intent; the exempted name is
  the *bound* variable, so `let { setSelected = s } = ...` exempts `s`; with
  punning they coincide).

This slots into `extract_static_deps_from_binding` as the final fallback,
*after* the existing `switch%platform` Client-branch unwrap (1.3.0), so
`let (v, setV) = switch%platform { | Client => RR.useStateValue(...) | ... }`
gets the convention exemption with no extra code.

```ocaml
let looks_like_stable_setter name =
  starts_with "dispatch" name
  || (starts_with "set" name
      && String.length name > 3
      && name.[3] >= 'A'
      && name.[3] <= 'Z')

let is_any_hook_call (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_apply ({ pexp_desc = Pexp_ident { txt; _ }; _ }, _) ->
      is_a_hook txt
  | _ -> false

(* final fallback in extract_static_deps_from_binding, after the
   %platform unwrap: *)
| None when is_any_hook_call expr ->
    (get_second_tuple_element_names vb.pvb_pat
     @ record_setter_bound_names vb.pvb_pat)
    |> List.filter looks_like_stable_setter
```

Resolved: the character class is `'A'..'Z'` **or `'_'`**, so `set_value`
matches alongside `setValue`. This ppx accepts snake_case hooks
(`use_state`, since 1.1.0), and the setter convention follows the same rule.
`set2` and `settings` do not match; both are pinned with tests.

The gates are deliberate:

| Gate | Excludes |
|---|---|
| callee must be a `use*` call | `let setLocal = x => ...` plain closures — still checked |
| pair-`snd` / record-field position only | `let setAll = Hook.use()` whole-return bindings — still checked |
| `set[A-Z]` / `dispatch*` names only | `let (v, callback) = Hook.use()` — `callback` still checked |

### Soundness, stated honestly

Layer 2 is unsound in theory: a hook returning a genuinely render-unstable
function *named* `setX` in setter position would no longer be flagged, hiding
a potential stale-closure bug. The trade is justified because the observed
alternative is worse: developers suppress the whole call with
`[@disable_exhaustive_deps]`, disabling checking of every dep. The heuristic's
worst case (one conventionally-named dep exempted) is strictly better than
the status quo's certain outcome (all deps exempted), and mixed sites — setter
plus real missing deps — go from fully suppressed to properly checked.

### Interaction with `-corrections`

Generated `.ppx-corrected` dep arrays must **not** include values exempted by
either layer, or the fix-it output reintroduces what the lint exempts. In the
current code this comes free: corrections are built from the `missing` list
inside `check_missing_deps`, which is already filtered through `static_deps`,
so anything the layers exempt never reaches the generated array. The
corrections test below pins the property rather than requiring new code.

### Out of scope

Cross-module *sound* inference requires typed whole-project analysis
(`.cmt`-based, reanalyze-style) — a separate binary, not a ppx. With Layers 1
and 2 the residual gap is hooks that return stable values under
non-conventional names from another module; those keep working via
`[@disable_exhaustive_deps]` as today.

## Cram tests

Drop-in files for `test/`, in the repository's existing style
(`input.mlx` → `mlx-pp` → `standalone.exe`; the 1.3.0 platform tests write
plain `input.ml` directly, which also works since extension nodes need no
JSX). Expected outputs below are the **specification**; exact pretty-printer
layout should be settled with `dune promote` once implemented — normative is
which `ocaml.ppwarning` attributes appear and which do not.

### `test/stable-hooks-setter-convention.t` (Layer 2)

```cram
Setter from an external custom hook is exempt; real missing deps still flagged:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~title =
  >   let _isHydrated, setIsHydrated = RR.useStateValue false in
  >   React.useEffect0 (fun () -> setIsHydrated true; Js.log title; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'title' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~title =
    let (_isHydrated, setIsHydrated) = RR.useStateValue false in
    React.useEffect0 (fun () -> setIsHydrated true; Js.log title; None); div
  [@@react.component]

dispatch from a custom reducer hook is exempt:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let _state, dispatch = Store.useStore init in
  >   React.useEffect0 (fun () -> dispatch Init; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make () =
    let (_state, dispatch) = Store.useStore init in
    React.useEffect0 (fun () -> dispatch Init; None); div[@@react.component]

Record destructure: setter-named fields exempt, others still required:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let { setSelected; clearAll } = Hooks.useSelectableRows () in
  >   React.useEffect0 (fun () -> setSelected 1; clearAll (); None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'clearAll' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let { setSelected; clearAll } = Hooks.useSelectableRows () in
    React.useEffect0 (fun () -> setSelected 1; clearAll (); None); div
  [@@react.component]
```

### `test/stable-hooks-setter-convention-negative.t` (Layer 2 gates)

```cram
Second element NOT named like a setter is still checked:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let _value, callback = SomeHook.use () in
  >   React.useEffect0 (fun () -> callback (); None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'callback' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let (_value, callback) = SomeHook.use () in
    React.useEffect0 (fun () -> callback (); None); div[@@react.component]

A set*-named plain closure (not a hook result) is still checked:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let setLocal = fun x -> Js.log x in
  >   React.useEffect0 (fun () -> setLocal 1; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'setLocal' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let setLocal x = Js.log x in
    React.useEffect0 (fun () -> setLocal 1; None); div[@@react.component]

Whole-return binding (not a destructure) is still checked, even if set*-named:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let setAll = Hooks.useSetter () in
  >   React.useEffect0 (fun () -> setAll 1; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'setAll' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let setAll = Hooks.useSetter () in
    React.useEffect0 (fun () -> setAll 1; None); div[@@react.component]
```

### `test/stable-hooks-local-wrappers.t` (Layer 1)

```cram
A same-file use* wrapper around useReducer is inferred as stable — even when
the setter name does NOT follow the convention (this is the sound layer):

  $ cat > input.mlx << 'EOF'
  > let useStateValue initial = React.useReducer (fun _ next -> next) initial
  >
  > let[@react.component] make () =
  >   let value, update = useStateValue 0 in
  >   React.useEffect0 (fun () -> update 1; None);
  >   Js.log value;
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let useStateValue initial = React.useReducer (fun _ next -> next) initial
  let make () =
    let (value, update) = useStateValue 0 in
    React.useEffect0 (fun () -> update 1; None); Js.log value; div
  [@@react.component]

Chained wrappers resolve transitively:

  $ cat > input.mlx << 'EOF'
  > let useStateValue initial = React.useReducer (fun _ next -> next) initial
  > let useCounter () = useStateValue 0
  >
  > let[@react.component] make () =
  >   let _n, bump = useCounter () in
  >   React.useEffect0 (fun () -> bump 1; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let useStateValue initial = React.useReducer (fun _ next -> next) initial
  let useCounter () = useStateValue 0
  let make () =
    let (_n, bump) = useCounter () in
    React.useEffect0 (fun () -> bump 1; None); div[@@react.component]

A wrapper whose body is NOT directly a stable hook application is not
inferred; a non-conventional name in snd position stays checked:

  $ cat > input.mlx << 'EOF'
  > let useWeird () =
  >   let v, s = React.useState (fun () -> 0) in
  >   (v, (fun x -> s (fun _ -> x)))
  >
  > let[@react.component] make () =
  >   let _v, apply = useWeird () in
  >   React.useEffect0 (fun () -> apply 1; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'apply' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let useWeird () =
    let (v, s) = React.useState (fun () -> 0) in (v, (fun x -> s (fun _ -> x)))
  let make () =
    let (_v, apply) = useWeird () in
    React.useEffect0 (fun () -> apply 1; None); div[@@react.component]
```

### `test/stable-hooks-platform.t` (interaction with 1.3.0 platform branches)

```cram
A convention-named setter bound through a switch%platform Client branch is
exempt (extends test/platform-switch-deps.t case 4, which pins the builtin
useState path):

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~init =
  >   let _v, setV =
  >     match%platform Runtime.platform with
  >     | Server -> (init, fun _ -> ())
  >     | Client -> RR.useStateValue init
  >   in
  >   React.useEffect0 (fun () -> setV 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  let make ~init =
    let (_v, setV) =
      [%platform
        match Runtime.platform with
        | Server -> (init, (fun _ -> ()))
        | Client -> RR.useStateValue init]
    in
    React.useEffect0 (fun () -> setV 1; None); div[@@react.component]

A same-file wrapper defined per target via switch%platform infers from the
Client branch (Layer 1):

  $ cat > input2.ml << 'EOF'
  > let useStateValue =
  >   match%platform () with
  >   | Server -> (fun initial -> (initial, fun _ -> ()))
  >   | Client -> (fun initial -> React.useReducer (fun _ next -> next) initial)
  > 
  > let[@react.component] make () =
  >   let _v, update = useStateValue 0 in
  >   React.useEffect0 (fun () -> update 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let useStateValue =
    [%platform
      match () with
      | Server -> (fun initial -> (initial, (fun _ -> ())))
      | Client -> (fun initial -> React.useReducer (fun _ next -> next) initial)]
  let make () =
    let (_v, update) = useStateValue 0 in
    React.useEffect0 (fun () -> update 1; None); div[@@react.component]
```

Note the second case needs `body_of_fun_chain` to unwrap `%platform` *before*
the `fun` chain as well as after: the binding RHS is a `%platform` match whose
Client branch is a lambda whose body is the stable application. The sketch
above handles the post-`fun` position; recording must apply it at both ends.

### `test/stable-hooks-corrections.t` (fix-it interaction)

```cram
Corrections must not add convention-stable setters to the generated deps:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~value =
  >   let _st, setSt = RR.useStateValue 0 in
  >   React.useEffect0 (fun () -> setSt value; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect0 (fun () -> setSt value; None); div[@@react.component]
  +  React.useEffect1 (fun () -> setSt value; None) [| value |]; div[@@react.component]
```

## Acceptance criteria

1. All five test files pass; all 63 existing `test/*.t` stay green. Two are
   load-bearing: the builtin `useState`/`useReducer`/`useRef` exemptions
   become a special case of the new shape table and must behave identically
   (a stated refactor of `is_use_state_call`/`is_use_reducer_call`/
   `is_use_ref_call` into `stable_shape_of_call`, pinned by the existing deps
   tests), and `platform-switch-deps.t` case 4 pins the Client-branch unwrap
   the new fallback sits behind.
2. In the ahrefs monorepo, the `[@disable_exhaustive_deps]` annotations whose
   errors named only `set*`/`dispatch` dependencies (81 of a 528-site sample,
   ~15%; plus partial credit on 54 mixed sites) become removable with the
   frontend build staying green.
3. No new flags, no configuration files: both layers are on by default.
