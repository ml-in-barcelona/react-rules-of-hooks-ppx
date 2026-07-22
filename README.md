# react-rules-of-hooks-ppx

A ppx that validates React's [Rules of Hooks](https://react.dev/reference/rules/rules-of-hooks) at compile time.

- Exhaustive dependencies in `useEffect`, `useMemo`, `useCallback`, etc.
- Order of hooks: no conditional calls, top level only, and only inside
  component functions or custom hooks. Recognized component attributes:
  `[@react.component]`, `[@react.client.component]`, and
  `[@react.async.component]`.

## Exhaustive dependencies

```reason
[@react.component]
let make = (~randomProp) => {
  let (show, setShow) = React.useState(() => false);

  React.useEffect1(
    () => {
      /* reads randomProp, but only [|show|] is declared */
      if (randomProp) {
        setShow(prevShow => !prevShow);
      };
      None;
    },
    [|show|],
  );

  <div />;
};
```

```bash
15 |     [|show|],
         ^^^^^^^^
         Error (warning 22): exhaustive-deps: Missing 'randomProp' in the dependency array.
         To suppress this warning, add [@disable_exhaustive_deps] before the expression
```

Dependencies are tracked at member-path granularity, like
eslint-plugin-react-hooks. `input.page` and `input.limit` are distinct
dependencies. A declared `input.page` covers deeper uses such as
`input.page.size`, but not `input.limit` and not the whole `input`; passing
the whole record somewhere requires `input` itself. Duplicate detection,
missing and unnecessary reports, and `-corrections` output all use the full
member path.

Effects without a dependency array (`React.useEffect(fn)`) run after every
render and can never observe stale values, so they get no exhaustiveness
checking, same as eslint-plugin-react-hooks. A direct `useState`/`useReducer`
setter call in such an effect warns about an infinite update chain, and
unsuffixed `useMemo`/`useCallback` warn that the memoization does nothing.

Stable values are exempt from dependency arrays, with no configuration:

- `useState`/`useReducer` setters and `useRef` results.
- Same-file `use*` wrappers around them, transitively:
  `let useStateValue = initial => useReducer((_, next) => next, initial);`
  makes setters returned by `useStateValue` exempt in that file.
- By naming convention, a second tuple element or record field named
  `set[A-Z]...`, `set_...`, or `dispatch...` destructured from any hook
  call. This one is a heuristic; plain closures (`let setLocal = ...`),
  whole-return bindings (`let setAll = Hook.use()`), and other names are
  still checked.

## Order of hooks

Calling hooks inside conditionals, loops, or nested functions fails the
build:

```reason
[@react.component]
let make = (~condition) => {
  if (condition) {
    let (state, _) = React.useState(() => 0); /* That's wrong */
    ();
  };
  <div />;
};
```

```bash
4 |     let (state, _) = React.useState(() => 0);
                         ^^^^^^^^^^^^^^^^^^^^^^^^
Error: Hooks can't be called conditionally and must be called at the top-level of your component. Move this hook call outside of conditionals, loops, or nested functions.
```

## Platform branches (server-reason-react)

[server-reason-react](https://github.com/ml-in-barcelona/server-reason-react)'s
`switch%platform` and `let%browser_only` / `[%browser_only ...]` are resolved
at compile time, one branch per build target, so the ppx does not treat them
as runtime conditionals:

- Hooks may be called in `| Server` and `| Client` branches. Real runtime
  conditionals nested inside a branch (or wrapping the switch) still error.
- `let%browser_only` functions that call hooks count as custom hooks
  whatever their name, and calls to them are linted like hook calls.
- Exhaustive-deps reads only the `Client` branch, where dependency arrays
  matter.

## Install

```bash
opam install react-rules-of-hooks-ppx
```

```clojure
(preprocess (pps reason-react react-rules-of-hooks-ppx))
```

## Suppress locally

Attach the attribute to the hook call:

```reason
[@disable_exhaustive_deps]
React.useEffect1(() => {...}, [|dep|]);

if (condition) {
  [@disable_order_of_hooks]
  useMyHook();
};
```

In OCaml syntax the attribute goes after the expression:
`(useMyHook ())[@disable_order_of_hooks]`.

`[@disable_order_of_hooks]` remains the escape hatch for genuinely
conditional hooks.

## Flags

Append to the `pps` line:

- `-disable-exhaustive-deps` turns off dependency checking.
- `-disable-order-of-hooks` turns off order-of-hooks checking.
- `-corrections` writes `.ppx-corrected` files with suggested fixes for
  missing dependencies; review and accept them with `dune promote`:

  ```diff
  -  React.useEffect0(() => {
  +  React.useEffect1(() => {
      Js.log(dep1);
      None;
  -  });
  +  }, [| dep1 |]);
  ```

## Issues

Report any unexpected behaviour in the [bug tracker](https://github.com/ml-in-barcelona/react-rules-of-hooks-ppx/issues)

## Acknowledgements

Thanks to [@jchavarri](https://github.com/jchavarri)
