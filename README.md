# react-rules-of-hooks-ppx

A ppx that validates React's [Rules of Hooks](https://react.dev/reference/rules/rules-of-hooks) at compile time.

### **Features**
- Exhaustive dependencies in useEffect, useCallback, useMemo, etc.
- Order of Hooks validation:
  - Hooks can't be called conditionally
  - Hooks must be called at the top level
  - Hooks can only be called from `[@react.component]` functions or custom hooks

## How it works

### Exhaustive dependencies

Here we have a dummy react component:

```re
[@react.component]
/* Recives a "randomProp" prop */
let make = (~randomProp) => {
  let (show, setShow) = React.useState(() => false);

  /* We have a useEffect that re-runs each time the state "show" changes it's value, and we only want to trigger the `setShow` when `randomProp` is true. */
  React.useEffect1(
    () => {
      /* Since this effect relies on "randomProp" and is not present on the dependency array... it will re-run only when show changes, and not when randomProp changes and may cause undesired behaviour */
      if (randomProp) {
        setShow(prevShow => !prevShow);
      }
      None;
    },
    [|show|],
  );

  <div />;
};
```

With this ppx, it will produce the following warning:

```bash
 6 |   React.useEffect1(
 7 |     () => {
 8 |       if (randomProp) {
 9 |         setShow(_ => !show);
10 |       }
...
13 |       None;
14 |     },
15 |     [|show|],
         ^^^^^^^^
         Error (warning 22): exhaustive-deps: Missing 'randomProp' in the dependency array.
         To suppress this warning, add [@disable_exhaustive_deps] before the expression
16 |   ).
```

### Order of hooks

Hooks must be called at the top level of your component. Calling hooks inside conditionals, loops, or nested functions will produce an error that fails the build:

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

This will produce the following error:

```bash
3 |   if (condition) {
4 |     let (state, _) = React.useState(() => 0);
                         ^^^^^^^^^^^^^^^^^^^^^^^^
Error: Hooks can't be called conditionally and must be called at the top-level of your component. Move this hook call outside of conditionals, loops, or nested functions.
```

### Platform branches (server-reason-react)

[server-reason-react](https://github.com/ml-in-barcelona/server-reason-react)'s
`switch%platform` and `let%browser_only` / `[%browser_only ...]` constructs
are resolved at compile time, per build target: exactly one branch survives
in each emitted bundle. The ppx understands this and does **not** treat them
as runtime conditionals:

```reason
let use = () => {
  switch%platform (Runtime.platform) {
  | Server => Screen.Desktop
  | Client =>
    /* Not conditional: this is the whole function body in the JS bundle */
    let (media, setMedia) = React.useState(() => getMedia());
    media->Screen.fromMedia;
  };
};
```

- Hooks may be called in `| Server` and `| Client` branches of
  `switch%platform`. Real runtime conditionals nested *inside* a branch (or
  wrapping the switch) still error.
- `let%browser_only`-bound functions whose bodies call hooks are treated as
  custom hooks regardless of their name, and calls to them are linted like
  hook calls. Hook-free `%browser_only` utilities are unaffected.
- Exhaustive-deps analysis inside a `switch%platform` considers the `Client`
  branch only — dependency arrays only drive behavior in the client bundle.
- `[@platform native]` / `[@platform js]` item attributes need no special
  handling and are linted as ordinary code.

`[@disable_order_of_hooks]` remains the escape hatch for genuinely
conditional hooks, e.g. a runtime `switch` nested inside a `| Client`
branch.

## Install

```bash
opam install react-rules-of-hooks-ppx
```

Add the ppx into the dune files

```clojure
(preprocess (pps reason-react react-rules-of-hooks-ppx))
```

#### Suppress warnings locally

If you need to suppress an exhaustive deps warning for a specific case (e.g., you intentionally want to omit a dependency), use the `[@disable_exhaustive_deps]` attribute.

**In Reason (.re files):**
```reason
[@disable_exhaustive_deps]
React.useEffect1(() => {
  /* ... */
  None
}, [|dep|]);
```

**In OCaml (.ml files):**
```ocaml
(React.useEffect1 (fun () ->
  (* ... *)
  None
) [|dep|])[@disable_exhaustive_deps]
```

#### Disable "Exhaustive dependencies in useEffect" on the library

```clojure
(preprocess (pps reason-react react-rules-of-hooks-ppx -disable-exhaustive-deps))
```

#### Suppress order-of-hooks warnings locally

If you need to suppress an order-of-hooks warning for a specific case (e.g., test utilities, switch%platform or intentional dynamic hook usage), use the `[@disable_order_of_hooks]` attribute.

**In Reason (.re files):**
```reason
if (condition) {
  [@disable_order_of_hooks]
  useMyHook();
};
```

**In OCaml (.ml files):**
```ocaml
if condition then
  (useMyHook ())[@disable_order_of_hooks]
```

##### Disable "Order of Hooks" on the library

```clojure
(preprocess (pps reason-react react-rules-of-hooks-ppx -disable-order-of-hooks))
```

#### Enable automatic corrections for missing dependencies

This ppx can generate `.ppx-corrected` files with suggested fixes for missing dependencies. This integrates with dune's promotion workflow, allowing you to review and accept the suggested changes.

```clojure
(preprocess (pps reason-react react-rules-of-hooks-ppx -corrections))
```
When enabled, running the build will show a diff with the suggested fix:

```reason
[@react.component]
let make = (~dep1) => {
  React.useEffect0(() => {
    Js.log(dep1);
    None;
  });
  <span />;
};
```

```diff
-  React.useEffect0(() => {
+  React.useEffect1(() => {
    Js.log(dep1);
    None;
-  });
+  }, [| dep1 |]);
```

You can then run `dune promote` to accept the corrections.

## Issues

Feel free to use it and report any unexpected behaviour in the [bug tracker](https://github.com/ml-in-barcelona/react-rules-of-hooks-ppx/issues)

## Acknowledgements

Thanks to [@jchavarri](https://github.com/jchavarri)
