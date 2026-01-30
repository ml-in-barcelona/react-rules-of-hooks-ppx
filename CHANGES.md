# Changes

## Unreleased

- [FIX] Fix static deps scope leaking between components (useState setters, useReducer dispatchers, useRef results now properly scoped per component)
- [FIX] JSX context reset bug where multiple hooks in the same JSX element weren't all flagged as violations
- [FEAT] Add `Pexp_letop` support for monadic `let+`/`and+` syntax in exhaustive deps checking
- [TEST] Add test cases inspired by Facebook's eslint-plugin-react-hooks
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
