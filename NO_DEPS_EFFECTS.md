# exhaustive-deps must not fire on effects without a dependency array

Status: implemented (see `test/no-deps-*.t`)
Author: davesnx
Date: 2026-07-21
Companions: `PLATFORM_BRANCHES.md`, `STABLE_HOOKS.md`
Origin: ahrefs monorepo PR #31653 — this false positive caused **real
production breakage** (see "Casualties" below).

## Claim, verified against upstream

> eslint's `exhaustive-deps` does not report missing dependencies for
> `useEffect` calls that have no dependency array.

**True**, verified against `facebook/react@main`,
`packages/eslint-plugin-react-hooks/src/rules/ExhaustiveDeps.ts`. When
`declaredDependenciesNode` is absent the rule **returns before any
exhaustiveness analysis** (`ExhaustiveDeps.ts:678-743`). The semantics are
deliberate: an effect with no dependency array runs after *every* render, so
it can never observe stale values — there is nothing to be exhaustive about.

Two nuances, for accuracy (the skip is not a blanket one):

1. **Infinite-loop guard** (`ExhaustiveDeps.ts:682-741`): before returning,
   the rule checks whether the no-deps effect calls a `useState` setter
   **directly in the effect's own function scope**. If so it reports:
   > React Hook useEffect contains a call to 'setState'. Without a list of
   > dependencies, this can lead to an infinite chain of updates. To fix
   > this, pass [...] as a second argument to the useEffect Hook.
   A setter called inside a *nested* function (event handler, promise
   callback) is fine — see migrated test `valid-4` below.
2. **Pointless-memo warning** (`ExhaustiveDeps.ts:1381-1394`): `useMemo` /
   `useCallback` called with only one argument get
   > React Hook useMemo does nothing when called with only one argument.
   > Did you forget to pass an array of dependencies?
   This is a usefulness warning, not an exhaustiveness one, and it does not
   apply to effects.

## What this ppx does today (1.2.0), and why it's wrong

`hooks_with_deps` (`src/ppx.ml:376`) is generated with the variant list
`[ ""; "0"; ...; "7" ]` — the empty variant puts the **unsuffixed**
`useEffect` / `React.useEffect` into the checked set. When the deps argument
is absent (`deps_arg = None`), the analysis proceeds as if the declared deps
were empty, producing:

```
Error (warning 22 [preprocessor]): exhaustive-deps: Missing dependency 'value' from the dependency array.
```

This is doubly wrong in the Reason/Melange ecosystem, because reason-react
makes the distinction **syntactic**:

- `React.useEffect(fn)` — no dependency array, runs every render;
- `React.useEffect0(fn)` — `[||]`, runs once;
- `React.useEffectN(fn, deps)` — explicit deps.

An unsuffixed effect call *cannot* have a deps array. Flagging it demands an
impossible fix.

## Casualties (ahrefs monorepo)

The error message offers two ways out: add deps (impossible — there is no
array) or suppress. A third path is the one actually taken in commit
`a4561733c791`: **delete the effect**. Two hooks were broken this way:

```reason
/* toolkit/src/hooks/UsePrevious.re — the deleted effect IS the hook */
let use = value => {
  let valueRef = React.useRef(value);

  React.useEffect(() => {   // ← deleted to silence the ppx
    valueRef.current = value;
    None;
  });

  valueRef.current;          // without the effect: initial value, forever
};
```

```reason
/* toolkit/src/widgets/ModalBase.re — snapshot must refresh every render */
React.useEffect(() => {      // ← deleted to silence the ppx
  storeChildrenSnapshot();
  None;
});
/* without it, a programmatic close (isOpen prop flip) animates with stale
   children from an earlier open */
```

Both are textbook-correct no-deps effects (`UsePrevious` is literally the
pattern from the React docs). eslint accepts both silently — the ref
assignment and the helper call are not direct setState calls, so even the
infinite-loop guard stays quiet.

## Spec

### Core fix (required)

In `check_hook_deps`: when the hook name is an **unsuffixed** effect-family
hook (`useEffect`, `useLayoutEffect`, `useInsertionEffect`, with or without
`React.` prefix) and there is no deps argument, produce **no
exhaustive-deps diagnostics**.

Implementation note: the originally suggested "drop the `""` variant from
`hooks_with_deps`" is wrong. That set also drives the order-of-hooks
marking of effect callbacks, so removing unsuffixed effects from it would
stop flagging hooks called *inside* `React.useEffect(fn)` callbacks. The
shipped fix dispatches inside `check_hook_deps` on
`deps_arg = None` + `decode_hook_name` returning no suffix, leaving the
traversal set untouched (pinned by `no-deps-effects-valid.t` cases 6-7).

### Ports of the two auxiliary eslint checks (recommended, separate)

1. Effects without deps that call a known `useState`/`useReducer` setter
   directly in the effect body → the "infinite chain of updates" warning.
   The setter set is exactly the `static_deps` machinery that exists today
   (and its extension in `STABLE_HOOKS.md`). Calls inside nested `fun`s do
   not count.
2. Unsuffixed `useMemo` / `useCallback` (which in reason-react recompute /
   reallocate every render) → the "does nothing when called with only one
   argument" warning.

## Cram tests

Migrated from `facebook/react@main`
`packages/eslint-plugin-react-hooks/__tests__/ESLintRuleExhaustiveDeps-test.js`,
translated to the mlx style used by `test/*.t`. Expected outputs are the
specification; settle exact pretty-printer layout with `dune promote` —
normative is which `ocaml.ppwarning` attributes appear.

### `test/no-deps-effects-valid.t` (core fix)

```cram
Migrated from eslint valid test: "useEffect(() => { console.log(local); });"
A local value read inside a no-deps effect is not a missing dependency:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let local = "banana" in
  >   React.useEffect (fun () -> Js.log local; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make () =
    let local = "banana" in React.useEffect (fun () -> Js.log local; None); div
  [@@react.component]

Migrated from eslint valid test: nested-scope locals in a no-deps effect:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let local1 = "a" in
  >   let local2 = "b" in
  >   React.useEffect (fun () -> Js.log local1; Js.log local2; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make () =
    let local1 = "a" in
    let local2 = "b" in
    React.useEffect (fun () -> Js.log local1; Js.log local2; None); div
  [@@react.component]

Migrated from eslint valid test: "useEffect(() => {}); useLayoutEffect(() => {});"
Empty no-deps effects are fine:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect (fun () -> None);
  >   React.useLayoutEffect (fun () -> None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make () =
    React.useEffect (fun () -> None);
    React.useLayoutEffect (fun () -> None);
    div[@@react.component]

Migrated from eslint valid test (the resize-listener "Hello" component):
a setState call inside a NESTED handler of a no-deps effect is valid — only
direct calls in the effect body trigger the infinite-loop guard:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let _state, setState = React.useState (fun () -> 0) in
  >   React.useEffect (fun () ->
  >     let handleResize = fun () -> setState (fun _ -> Window.innerWidth) in
  >     Window.addEventListener "resize" handleResize;
  >     Some (fun () -> Window.removeEventListener "resize" handleResize));
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make () =
    let (_state, setState) = React.useState (fun () -> 0) in
    React.useEffect
      (fun () ->
         let handleResize () = setState (fun _ -> Window.innerWidth) in
         Window.addEventListener "resize" handleResize;
         Some (fun () -> Window.removeEventListener "resize" handleResize));
    div[@@react.component]

The regression that motivated this fix: the usePrevious pattern from the
React docs (ref updated by a no-deps effect) must be accepted:

  $ cat > input.mlx << 'EOF'
  > let usePrevious value =
  >   let valueRef = React.useRef value in
  >   React.useEffect (fun () -> valueRef.current <- value; None);
  >   valueRef.current
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let usePrevious value =
    let valueRef = React.useRef value in
    React.useEffect (fun () -> valueRef.current <- value; None);
    valueRef.current
```

### `test/no-deps-effects-setstate-loop.t` (auxiliary check 1)

```cram
Migrated from eslint invalid test: a DIRECT setState call in a no-deps
effect is an infinite update loop:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let _state, setState = React.useState (fun () -> 0) in
  >   React.useEffect (fun () -> setState (fun _ -> 1); None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: This effect contains a call to 'setState'. Without a dependency array, this can lead to an infinite chain of updates. Use React.useEffect0 or add a dependency array."]
  let make () =
    let (_state, setState) = React.useState (fun () -> 0) in
    React.useEffect (fun () -> setState (fun _ -> 1); None); div
  [@@react.component]
```

### `test/no-deps-memo-does-nothing.t` (auxiliary check 2)

```cram
Ported from ExhaustiveDeps.ts:1381-1394: unsuffixed useMemo/useCallback
recompute every render — the memoization does nothing:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~value =
  >   let _memoized = React.useMemo (fun () -> value + 1) in
  >   let _callback = React.useCallback (fun x -> x + value) in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: React.useMemo does nothing when called without a dependency array. Did you mean React.useMemoN with dependencies?"]
  [@@@ocaml.ppwarning
    "exhaustive-deps: React.useCallback does nothing when called without a dependency array. Did you mean React.useCallbackN with dependencies?"]
  let make ~value =
    let _memoized = React.useMemo (fun () -> value + 1) in
    let _callback = React.useCallback (fun x -> x + value) in div
  [@@react.component]
```

### Regression guards

- `test/exhaustive-deps.t` and every suffixed-hook test must be unchanged:
  `useEffect0`..`useEffect7`, `useMemoN`, `useCallbackN` keep full
  exhaustiveness checking.
- Order-of-hooks checks must still see unsuffixed effects (a conditional
  `React.useEffect(fn)` is still an order violation).

## Acceptance criteria

1. `no-deps-effects-valid.t` passes with zero warnings; existing tests green.
2. In the ahrefs monorepo, the two restored hooks
   (`toolkit/src/hooks/UsePrevious.re`, `toolkit/src/widgets/ModalBase.re`,
   commit `bb45260f94dd`) compile without their `[@disable_exhaustive_deps]`
   annotations.
3. Auxiliary checks (1) and (2) ship behind no flag but as *new* diagnostics
   with their own wording, so they can be reviewed independently of the core
   fix.
