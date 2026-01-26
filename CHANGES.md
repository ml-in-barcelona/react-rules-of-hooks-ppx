# Changes

## 1.0.0

- Detect hooks called conditionally, in loops, or in nested functions
- Detect hooks called outside of `[@react.component]` functions or custom hooks
- Check exhaustive dependencies in `useEffect`, `useMemo`, `useCallback`, `useLayoutEffect`, and `useInsertionEffect`
- Disable order of hooks check globally with `-order-of-hooks` ppx flag
- Disable exhaustive deps check globally with `-exhaustive-deps` ppx flag
- Suppress exhaustive deps warning locally with `[@disable_exhaustive_deps]` attribute
