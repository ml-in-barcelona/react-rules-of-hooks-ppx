# Design

How react-rules-of-hooks-ppx works: what it checks, how each rule is
specified, and how the implementation is put together. This document
consolidates the original design notes for platform branches, stable-hook
detection, member-path dependency tracking, and effects without a
dependency array.

## Overview

The ppx is a linter, not a rewriter. It registers a `Driver.V2`
whole-structure transformation named `react-rules-of-hooks` with two
channels:

- `~impl` prepends `[%%ocaml.error ...]` structure items for rules-of-hooks
  violations (conditional hook calls). These break the build.
- `~lint_impl` returns `Driver.Lint_error.t` values for exhaustive-deps
  findings and hooks called outside components. ppxlib emits these as
  `[@@@ocaml.ppwarning]` (warning 22), so they warn by default and break the
  build only under warnings-as-errors.

Both channels consume one analysis: a single fold over the AST, memoized per
input file in a `Hashtbl` keyed by filename, so the traversal runs once even
though ppxlib calls both hooks. Files with no hook calls at all skip the
fold entirely (an early-exit scan raises on the first `use*` application).

The ppx lints the source as written, before server-reason-react's
`browser_ppx` eliminates platform branches. That is the useful order: one
pass covers both build targets and diagnostics point at the code the user
wrote.

### Flags and escape hatches

| Mechanism | Effect |
|---|---|
| `-disable-exhaustive-deps` | turns off all exhaustive-deps checks |
| `-disable-order-of-hooks` | turns off rules-of-hooks checks (scope tracking still runs, so exhaustive-deps is unaffected) |
| `-corrections` | writes `.ppx-corrected` files with suggested dependency arrays |
| `[@disable_exhaustive_deps]` | on a hook call or its deps argument: skips deps checks for that call |
| `[@disable_order_of_hooks]` | on a hook call: skips order checks for that call |
| `REACT_HOOKS_PPX_TIMING=1` | prints per-file analysis timing to stderr |

## Module map

The implementation is split into modules with `.mli` interfaces; `ppx.ml`
keeps the fold, the check functions, and the driver wiring.

| Module | Owns |
|---|---|
| `Platform` | recognition of `[%platform match ...]` and `[%browser_only ...]`; the rule that analysis follows the `Client` branch |
| `Hook` | hook identity: the `use*` naming rule, call detection (JSX excluded), the deps-taking hook table, hook scanners |
| `Bindings` | names introduced by patterns and parameters; function-body views through constraints, `%browser_only`, and platform branches |
| `Deps` | member-path extraction: which paths a callback uses and which names it binds |
| `Stable` | inference of referentially-stable values (setters, dispatch, refs) |
| `Scope` | binding-scope tracking: component vs outer scope, static deps, stable wrappers, browser-only hooks, and the enter/exit protocol |
| `Ppx` | the `Ast_traverse.fold`, the diagnostic checks, caching, driver registration |

## Hook detection

A name is a hook when it is `use`, or `use` followed by an uppercase
letter, `_`, `'`, or a digit. This matches eslint-plugin-react-hooks and
accepts `useState`, `use_state`, `use'`, and `use1239`, while rejecting
`user` and `useful`. For a qualified call (`Mod.useThing`) the last path
component decides.

A hook *call* is a function application whose callee is an identifier,
except JSX elements: reason-react tags applications with a `[@JSX]`
attribute, and an SVG `<use>` element must not count as a hook call.

Hooks that take a dependency array are `useEffect`, `useLayoutEffect`,
`useInsertionEffect`, `useMemo`, and `useCallback`, bare or under the
`React.` prefix, with an optional arity-variant suffix `0`..`7`
(`useEffect2` takes a 2-tuple of dependencies). One decoder produces
`{ prefix; base; variant }`; membership, message text, and correction
renaming all derive from it.

## Binding classification

Every value binding classifies as one of:

- **Component**: a function binding carrying `[@react.component]`,
  `[@react.client.component]`, or `[@react.async.component]` (all three
  server-reason-react component markers; client components hydrate in the
  browser, so every hook rule applies to them in full).
- **Custom hook**: a function binding whose name is a hook name.
- **Function**: any other function binding.
- **Value**: everything else.

Classification sees through platform branches: `let x = switch%platform ...`
is a function if *any* branch has a function body ("any", not "all", because
one side may be a stub constant). This matters for per-target hook
implementations:

```reason
let use =
  switch%platform () {
  | Server => Context.use
  | Client => ReasonReactRouter.useUrl
  };
```

Without it, fixing the conditional-hook false positive would just trade it
for an "outside component" lint.

## Rules of hooks

### Conditional calls (hard error)

While folding, the traversal marks a conditional context when it descends
into:

- `match` / `try` case bodies (and the `try` scrutinee, which only runs to
  the extent the handler may fire)
- `while` and `for` bodies
- `if` branches
- `lazy` and `assert` payloads
- arguments of `&&` and `||`
- the callback of a deps-taking hook (`useEffect(() => useState(...))` is
  an error: the callback runs at effect time, not render time)

A hook call in a conditional context, or inside JSX (an element body only
renders when the element does), produces:

```
Hooks can't be called conditionally and must be called at the top level of
your component or custom hook. Move this hook call outside of conditionals,
loops, or nested functions.
```

### Calls outside components (lint warning)

A hook call while inside neither a Component nor a Custom_hook binding
warns:

```
React hooks can only be called from [@react.component] functions or custom hooks.
```

Both checks share one predicate site, so anything recognized as a hook call
(including tracked browser-only wrappers, below) is subject to both.

## Platform branches

server-reason-react compiles universal components to two targets. Its
`browser_ppx` statically eliminates one branch per target:

- `switch%platform (Runtime.platform) { | Server => a | Client => b }`
  becomes `a` on native and `b` on Melange. No runtime branch exists in
  either bundle.
- `let%browser_only f = ...` keeps the body on Melange; on native the
  binding becomes a stub. `[%browser_only e]` is the expression form.

These constructs look conditional in the parsetree but are not, so the ppx
treats them specially. The recognized extension names are hardcoded
(`platform`, `browser_only`); any payload not matching the expected shape
falls back to default traversal silently, since `browser_ppx` is the
authority on payload validity.

### `%platform` branches are not conditional

The traversal descends into the scrutinee and every case body without
marking a conditional context, and never *clears* an already-set flag.
Consequences:

```reason
let use = () => {
  switch%platform (Runtime.platform) {
  | Server => Screen.Desktop
  | Client =>
    let (media, setMedia) = RR.useStateValue(getMedia());  /* legal */
    React.useEffect0(...);                                  /* legal */
    media->Screen.fromMedia;
  };
};
```

- Hooks in `Client` *and* `Server` branches are legal (server components may
  call `React.useRef`).
- A real runtime conditional nested inside a branch still errors:

  ```reason
  switch%platform (Runtime.platform) {
  | Server => false
  | Client =>
    switch (hideTriggerRef) {   /* real runtime conditional */
    | Some(r) => useScrollPercentage(~elRef=r, ()) > 0.  /* still an error */
    | None => false
    }
  };
  ```

- A `%platform` switch nested inside a real conditional, or inside an effect
  callback, stays conditional.

### `let%browser_only` hook wrappers

Of the hundreds of `let%browser_only` bindings surveyed in a large
production codebase, almost none wrap hooks; they are plain browser
utilities, several deliberately called conditionally. So the hook treatment
is gated: a `%browser_only` binding gets it only when its body contains a
hook call, or its RHS is itself a hook identifier (alias form).

When gated in:

- The binding classifies as a custom hook regardless of name, so
  `let%browser_only makeChargebee = () => Chargebee.useScript()` stops
  reporting "outside a component".
- The bound name is tracked, with shadowing, and its call sites are linted
  exactly like hook calls: a conditional call is a hard error,
  `[@disable_order_of_hooks]` on the call is the opt-out. This verifies the
  define-then-call-immediately pattern instead of assuming it.
- Only unqualified call sites are looked up. Cross-module calls are
  invisible, the same limitation as custom hooks defined in other files.

When gated out, behavior is unchanged: hook-free browser utilities may be
called conditionally, as they always could.

`[%browser_only e]` expressions are transparent: the payload is traversed
with no added conditionality, and dependency extraction sees inside it. A
hook called inside `useEffect([%browser_only () => ...])` is still an
error.

`[@platform native]` / `[@platform js]` structure-item attributes need no
support: they drop whole items per target and cannot introduce
conditionality.

## Exhaustive dependencies

For every call to a deps-taking hook, the callback body and the dependency
array are compared as **member paths**.

### Member paths

A path is a chain of record-field accesses over a possibly-qualified
identifier: `input.page.size` is root `input` with fields `["page";
"size"]`. Module qualification is part of the root, never a field step
(`Pexp_field` vs `Ldot` distinguishes these syntactically). The rules:

1. **Extraction.** A path is a `Pexp_field` chain over a `Pexp_ident`,
   through type constraints. Anything else (application results, computed
   access) degrades to the paths of its sub-expressions.
2. **Coverage.** A body use is satisfied when some declared path is a
   prefix of it, comparing roots by name. Declared `input.page` covers
   `input.page.size` but not `input.limit` and not bare `input`; using the
   whole record requires declaring the root.
3. **Duplicates.** Two declared entries are duplicates only when their
   paths are identical. `(input.page, input.limit)` is fine;
   `(input.page, input.page)` is reported.
4. **Missing deps** are reported at path granularity
   (`Missing dependency 'input.page'`), and when both a path and its prefix
   are missing, only the shallowest is reported (`input` subsumes
   `input.page`).
5. **Stability.** A stable root exempts every path under it: `ref.current`
   is exempt because `ref` is.
6. **Writes.** `r.x <- e` counts as a use of `r.x` (so stable roots exempt
   writes through them) plus the uses of `e`.
7. **Call position.** `input.callback()` counts as a use of
   `input.callback`. A callee that is not a plain path,
   `(getHandlers()).onClick()`, degrades to its sub-expressions, so
   `getHandlers` is tracked. Operator callees are never collected.
8. **Shadowing.** Names bound inside the callback (parameters, `let`, case
   patterns, `for` loop variables, `let+`/`and+` operators) shadow whole
   path families by root.

Root-only tracking, the pre-1.3 behavior, had two failure modes worth
remembering: five distinct `input.*` entries in one array reported as five
duplicates of `input` (the single largest false-positive class in a
production audit), and deps `[|input.limit|]` silently "covered" a body
reading `input.page`, accepting a genuinely stale effect.

### What is exempt from missing-deps

A body path is only reported when its root is a component-scope binding,
i.e. bound inside the current component or custom hook (parameters
included). Exempt:

- **Outer-scope roots**: module-level values are constant between renders.
- **Module-qualified roots** (`Mod.value`): same reasoning.
- **Static deps**: values known referentially stable (next section).
- **Locally-bound names**: shadowed inside the callback.

### Unnecessary dependencies

Declared paths whose root is an outer-scope binding, or is module-qualified,
are reported the other way around:

```
exhaustive-deps: useEffect1 has an unnecessary dependency: 'Mod.value'.
Outer scope values like 'Mod.value' aren't valid dependencies because they
are constant and never change between renders.
```

### Effects without a dependency array

`useEffect(fn)` with no array runs after every render, so it can never
observe stale values and there is nothing to be exhaustive about.
eslint-plugin-react-hooks does the same: when the declared-dependencies
node is absent, `ExhaustiveDeps.ts` returns before any exhaustiveness
analysis. reason-react even makes the distinction syntactic:

- `React.useEffect(fn)`: no dependency array, runs every render;
- `React.useEffect0(fn)`: `[||]`, runs once;
- `React.useEffectN(fn, deps)`: explicit deps.

An unsuffixed effect call *cannot* take a deps array, so a missing-deps
report on one demands an impossible fix. Before 1.3.0 the ppx analyzed
these calls as if the declared deps were empty, and the message pushed
users toward the worst outcome: deleting the effect. Two textbook-correct
hooks were broken exactly that way in production, including the
`usePrevious` pattern from the React docs:

```reason
let use = value => {
  let valueRef = React.useRef(value);

  React.useEffect(() => {   /* deleted to silence the ppx */
    valueRef.current = value;
    None;
  });

  valueRef.current;          /* without the effect: initial value, forever */
};
```

The skip is not blanket. Two targeted diagnostics replace exhaustiveness,
both ported from eslint:

- A *direct* call to a known-stable setter inside a no-array effect warns
  about an infinite chain of updates (each run schedules a rerender, which
  reruns the effect):

  ```
  exhaustive-deps: This effect contains a call to 'setState'. Without a
  dependency array, this can lead to an infinite chain of updates. Use
  React.useEffect0 or add a dependency array.
  ```

  The setter set is the same static-deps machinery used for exemptions, so
  Layer 1/Layer 2 stable setters trigger it too. A setter called inside a
  nested function (event handler, promise callback) is fine.
- No-array `useMemo`/`useCallback` recompute every render, so the
  memoization does nothing; they warn and suggest the `N`-suffixed variant.

Implementation note: the deps-taking hook table keeps the unsuffixed names.
Dropping them would also stop the traversal from marking effect callbacks
as conditional contexts, and a hook called inside `React.useEffect(fn)`
must stay an order violation. The skip is a dispatch inside the deps check
(`deps_arg = None` on an unsuffixed effect base), leaving traversal
untouched; both properties are pinned by `test/no-deps-*.t`.

### Inside platform branches

Dependency extraction follows only the `Client` case of a `%platform`
switch; if no `Client` case exists the switch contributes nothing. Deps
arrays only drive behavior in the client bundle: effect callbacks never run
during SSR, and server-side memo results live for one render pass, so
staleness across rerenders cannot exist on native. Requiring server-branch
identifiers in a shared array would manufacture unsatisfiable warnings.

### Corrections

With `-corrections`, missing-deps findings also register fix-its: the
dependency array is rewritten with the union of declared and missing paths
(member paths, not roots), and the hook is renamed to the matching arity
variant (`useEffect` to `useEffect2`, and so on). When there is no deps
argument at all, the whole call is rewritten. Values exempted by stability
never reach the generated array, because corrections are built from the
same filtered missing list as the diagnostic.

## Stable-hook detection

React guarantees identity stability for `useState`'s setter, `useReducer`'s
dispatch, and the `useRef` box. Destructuring one of these registers the
stable names, keyed by shape: `Snd` (second tuple element) for
`useState`/`useReducer`, `All` for `useRef`.

Hardcoded detection breaks down the moment a codebase wraps the primitives:

```reason
/* RR.re */
let useStateValue = initial => useReducer((_ignored, next) => next, initial);
```

The returned setter is literally a `useReducer` dispatch, but a syntactic
check keyed on `useState`/`useReducer` cannot see that, and every
state-touching effect in a codebase standardized on such a wrapper gets a
false missing-dep. The observed developer response is
`[@disable_exhaustive_deps]` on the whole call, which silences the real
deps too. Two automatic layers close the gap; no flags, no configuration.

### Layer 1: same-file wrapper inference (sound)

A binding defining a `use*`-named function whose body, through the `fun`
chain, constraints, and the platform `Client` branch, is directly an
application of a known-stable hook records the wrapper with the same shape.
Lookups consult the builtins and this table, so chains resolve
transitively (`useCounter` calling `useStateValue` calling `useReducer`).
The table lives in the scope state with shadowing and save/restore
discipline, not in a global. Lookup is by unqualified name only: a
qualified `Other.useStateValue(...)` never matches a local wrapper, because
cross-module guessing would break the layer's soundness.

This makes the defining module need no annotations. It cannot help
consumers in other files; ppxlib sees one compilation unit, untyped.

### Layer 2: setter naming convention (heuristic)

For wrappers defined elsewhere, the only information is the binding shape.
When destructuring the result of *any* hook call:

- the second tuple element, if named `set[A-Z]...`, `set_...`, or
  `dispatch...`, is treated as stable;
- in a record destructure, any field whose *field name* matches the
  convention exempts the *bound* variable (`let { setSelected = s } = ...`
  exempts `s`).

The gates are deliberate:

| Gate | Keeps checked |
|---|---|
| callee must be a hook call | `let setLocal = x => ...` plain closures |
| tuple-snd / record-field position only | `let setAll = Hook.use()` whole-return bindings |
| `set[A-Z_]` / `dispatch` names only | `let (v, callback) = Hook.use()` |

`set2` and `settings` do not match; both are pinned with tests.

Layer 2 is unsound in theory: a hook returning a render-unstable function
*named* `setX` in setter position slips through. The trade is justified
because the alternative observed in practice is worse: suppressing the
whole call disables checking of every dep, while the heuristic's worst case
exempts one conventionally-named value and keeps the rest checked.

Cross-module *sound* inference needs typed whole-project analysis
(`.cmt`-based), a separate tool, not a ppx. The residual gap, stable values
under non-conventional names from another module, keeps working via
`[@disable_exhaustive_deps]`.

## Scope tracking

The fold threads immutable state. The scope portion tracks:

- **component bindings**: names bound inside the current component or
  custom hook, the candidate dependencies (parameters and labelled
  arguments seed the set);
- **outer bindings**: module-level names, never valid dependencies;
- **static deps**: stable names from the section above;
- **stable wrappers**: the Layer 1 table;
- **browser-only hooks**: tracked `%browser_only` wrapper names.

The protocol around each value binding: on *enter*, the bound names shadow
any stale stable/browser-only facts, plain bindings route to component or
outer scope depending on context, and stability facts are recorded. The
body of a Component or Custom_hook then traverses with a fresh scope (its
parameters become the component bindings, static deps reset). On *exit*, a
Component/Custom_hook discards the scope it opened, restoring the
enter-time state; other binding kinds keep the traversed state. Outer
bindings and browser-only hook names always persist: module-level facts are
visible for the rest of the file.

This state is what makes the checks compositional: two components in one
file cannot leak setters or scope into each other (a 1.1.0 bug class), and
a rebinding of a wrapper name drops its recorded stability.

## Known limitations

- Cross-module knowledge is out of reach: custom hooks, stable wrappers,
  and browser-only wrappers defined in another file are invisible except
  through the naming conventions.
- The Layer 2 setter convention is a heuristic (see above).
- Non-`use*` helper functions that call hooks legitimately (render helpers
  called unconditionally) still report "outside component"; the honest fix
  is renaming them to `use*`, and `[@disable_order_of_hooks]` remains the
  escape hatch when that is not.
- Genuine violations inside platform branches are still caught on purpose:
  platform support must never whitelist a nested runtime conditional.
