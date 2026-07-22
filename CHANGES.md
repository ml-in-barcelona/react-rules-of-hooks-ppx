# Changes

## 1.3.0

### Exhaustive dependencies

- [FEAT] Member-path dependency tracking, as in eslint-plugin-react-hooks. Dependencies and body uses are compared as full member paths, so `(input.page, input.limit)` is no longer reported as a duplicate, and deps `[|input.limit|]` over a body reading `input.page` now report a missing `input.page`. A declared `input.page` covers deeper uses (`input.page.size`) but not the whole record. Stable roots (setters, refs) keep every path under them exempt (`ref.current`). Diagnostics and `-corrections` output emit member paths.
- [FEAT] Automatic stable-hook detection: a same-file `use*` wrapper whose body is directly a `useState`/`useReducer`/`useRef` application inherits its stability (chains resolve transitively), so `let useStateValue = initial => useReducer(...)` setters stop triggering missing-deps warnings at every use site.
- [FEAT] Setter naming convention: when destructuring any hook call result, a second tuple element or record field named `set[A-Z]...`, `set_...`, or `dispatch...` is treated as stable. Plain closures, whole-return bindings, and non-conventional names are still checked. Generated `-corrections` never include exempted values.
- [FIX] Effects without a dependency array (`React.useEffect(fn)`, `useLayoutEffect`, `useInsertionEffect`) no longer report missing dependencies: they run after every render, so nothing can be stale. Matches eslint-plugin-react-hooks. Order-of-hooks checks still apply to these calls and their callbacks.
- [FIX] Identifiers in `when` guards of `match`/`try` cases inside a hook callback now count as dependency uses: `match v with Some x when x > limit -> ...` reports a missing `limit`. Previously only `function` case guards were collected.
- [FIX] Member paths in call position now count as dependency uses: `input.callback ()` reports a missing `input.callback`, matching eslint-plugin-react-hooks. Callees that are not plain paths (e.g. `(getHandlers ()).onClick ()`) degrade to their sub-expressions, so `getHandlers` is tracked. Previously only bare-identifier callees were collected.
- [FIX] `-disable-order-of-hooks` no longer silently degrades exhaustive-deps: binding scope tracking (component-scope bindings, outer-scope bindings, stable hooks) now runs regardless of the flag, so missing-dependency and outer-scope warnings are still reported when only order-of-hooks checking is disabled.

### New diagnostics

- [FEAT] A direct `useState`/`useReducer` setter call inside a no-deps effect warns about an infinite chain of updates (setters inside nested functions are fine).
- [FEAT] Unsuffixed `useMemo`/`useCallback` warn that the memoization does nothing without a dependency array, instead of demanding deps the call cannot take. Both diagnostics can appear at previously silent sites, which matters when bumping under warnings-as-errors.

### Compatibility with server-reason-react

- [FEAT] `[@react.client.component]` bindings are recognized as components.
- [FEAT] `[@react.async.component]` bindings are recognized as components, same as `[@react.component]`.
- [FEAT] Understand server-reason-react platform branches: hooks inside `switch%platform` / `match%platform` branches are no longer flagged as conditional (branches are resolved at compile time, one per build target). Runtime conditionals nested inside a branch, or wrapping the switch, still error.
- [FEAT] `let x = switch%platform ...` bindings whose branches are functions classify as components/custom hooks/functions by the usual name and attribute rules (per-target hook implementations, e.g. `let use = switch%platform () { | Server => Context.use | Client => ReasonReactRouter.useUrl }`).
- [FEAT] `let%browser_only`-bound functions whose bodies call hooks are treated as custom hooks regardless of name, and their call sites are linted like hook calls (conditional call = error, with `[@disable_order_of_hooks]` as the opt-out). Hook-free `%browser_only` utilities are unaffected and may still be called conditionally.
- [FEAT] Exhaustive-deps sees through `[%browser_only ...]` payloads. This can surface new missing-deps lint warnings in code deps analysis could not see before.
- [FEAT] Exhaustive-deps considers only the `Client` branch of `switch%platform` (dependency arrays only drive behavior in the client bundle); `useState`/`useReducer`/`useRef` results bound through a `Client` branch register as stable deps.

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
