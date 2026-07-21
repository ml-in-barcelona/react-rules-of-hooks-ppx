# Changes

## 1.3.0

- [FEAT] Understand server-reason-react platform branches: hooks inside
  `switch%platform` / `match%platform` branches are no longer flagged as
  conditional (branches are resolved at compile time, one per build target).
  Runtime conditionals nested inside a branch, or wrapping the switch, still
  error.
- [FEAT] `let x = switch%platform ...` bindings whose branches are functions
  classify as components/custom hooks/functions by the usual name and
  attribute rules (per-target hook implementations, e.g.
  `let use = switch%platform () { | Server => Context.use | Client => ReasonReactRouter.useUrl }`).
- [FEAT] `let%browser_only`-bound functions whose bodies call hooks are
  treated as custom hooks regardless of name, and their call sites are
  linted like hook calls (conditional call = error, with
  `[@disable_order_of_hooks]` as the opt-out). Hook-free `%browser_only`
  utilities are unaffected and may still be called conditionally.
- [FEAT] Exhaustive-deps sees through `[%browser_only ...]` payloads. Note:
  this can surface new missing-deps lint warnings in code that was
  previously invisible to deps analysis.
- [FEAT] Exhaustive-deps considers only the `Client` branch of
  `switch%platform` (dependency arrays only drive behavior in the client
  bundle); `useState`/`useReducer`/`useRef` results bound through a
  `Client` branch register as stable deps.
- [FEAT] Automatic stable-hook detection: a same-file `use*` wrapper whose
  body is directly a `useState`/`useReducer`/`useRef` application inherits
  its stability (chains resolve transitively), so
  `let useStateValue = initial => useReducer(...)` setters stop triggering
  missing-deps warnings at every use site.
- [FEAT] Setter naming convention: when destructuring any hook call result,
  a second tuple element or record field named `set[A-Z]...`, `set_...`, or
  `dispatch...` is treated as stable. Plain closures, whole-return bindings,
  and non-conventional names are still checked. Generated `-corrections`
  never include exempted values.

## 1.2.0

- [FEAT] Support `use` + numbers as a valid hook name
- [FIX] Outer scope bindings (module-level values and functions) no longer trigger missing dependency warnings in exhaustive deps checks

## 1.1.0

- [FEAT] Disable order of hooks attribute `[@disable_order_of_hooks]`
- [CHORE] Add mlx as `:with-test` and `:with-dev-setup` (previously only `:with-dev-setup`)
- [FIX] Add support for snake_case hooks (`use_state`, `use_effect`, `use_custom_hook`)
- [FIX] SVG `<use>` element no longer incorrectly flagged as a hook (JSX elements excluded from hook detection)
- [FIX] False positive when multiple hooks are defined
- [FIX] Hooks name can be "use"
- [FIX] Fix static deps scope leaking between components (useState setters, useReducer dispatchers, useRef results now properly scoped per component)
- [FIX] JSX context reset bug where multiple hooks in the same JSX element weren't all flagged as violations
- [FEAT] Add `Pexp_letop` support for monadic `let+`/`and+` syntax in exhaustive deps checking
- [TEST] Add test cases inspired by React's eslint-plugin-react-hooks
- [FEAT] Add `REACT_HOOKS_PPX_TIMING` env var to print timing diagnostics
- [FIX] Use Set for O(log n) lookups, single-pass AST analysis, caching
- [FIX] Simplify diff function
- [FIX] Replace `List.length > 0` with `<> []`
- [FIX] Optimize `find_duplicates` to deduplicate during traversal

## 1.0.0

- [FEAT] Detect hooks called conditionally, in loops, or in nested functions
- [FEAT] Detect hooks called outside of `[@react.component]` functions or custom hooks
- [FEAT] Check exhaustive dependencies in `useEffect`, `useMemo`, `useCallback`, `useLayoutEffect`, and `useInsertionEffect`
- [FEAT] Disable order of hooks check globally with `-order-of-hooks` ppx flag
- [FEAT] Disable exhaustive deps check globally with `-exhaustive-deps` ppx flag
- [FEAT] Suppress exhaustive deps warning locally with `[@disable_exhaustive_deps]` attribute
- [FEAT] `-corrections` flag to generate `.ppx-corrected` files with suggested fixes for missing dependencies
- [FIX] Improve `-corrections` according to the reason-react interface
