# react-rules-of-hooks-ppx

> STATUS: This project isn't complete and might give false-positives. [Read more](https://github.com/reason-in-barcelona/react-rules-of-hooks-ppx#status)

This package is a no-op ppx rewriter. It is used as a 'lint' to
enforce React's [Rules of Hooks](https://react.dev/reference/rules/rules-of-hooks).

- [x] Exhaustive dependencies in useEffect
- [x] Order of Hooks
  - [x] Hooks shoudn't be called in different order
  - [x] Only call Hooks at the Top Level
  - [x] Only call Hooks from [@react.components] or custom hook functions

## Why

One of the points of using [Reason](https://reasonml.github.io) or [ReScript](https://rescript-lang.org) is to have a compiler that warns about issues with your code, where functions expect different types from the given ones. That's Type-checking and works amazingly well, but there are some cases where even with the right types, the runtime of your program can cause issues. Very commonly in side-effects. I found this case while working with ReasonReact.

ReasonReact and useEffect hooks is one of those cases, where types ensures that the functions are called correctly, but they have certain rules that aren't cacheable at the type-system. Not following those rules might cause some unexpected bug or even a run-time error.

This package solves this problem based on the [React's Rules of Hooks](https://react.dev/reference/rules/rules-of-hooks).

## Install

```bash
opam install react-rules-of-hooks-ppx --save-dev
```

Add the ppx into the dune files

```clojure
(preprocess (pps reason-react react-rules-of-hooks-ppx))
```

### Disable "Exhaustive dependencies in useEffect"

```clojure
(preprocess (pps reason-react react-rules-of-hooks-ppx -exhaustive-deps))
```

### Disable "Order of Hooks"

```clojure
(preprocess (pps reason-react react-rules-of-hooks-ppx -order-of-hooks))
```

### Suppress warnings locally

If you need to suppress an exhaustive deps warning for a specific case (e.g., you intentionally want to omit a dependency), use the `[@disable_exhaustive_deps]` attribute.

**In Reason (.re files):**
```re
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

## Issues

Feel free to use it and report any unexpected behaviour in the [issue section](https://github.com/reason-in-barcelona/react-rules-of-hooks-ppx/issues)

## Demo

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

With this ppx, it will produce the following error:

```bash
 6 | ..React.useEffect1(
 7 |     () => {
 8 |       if (randomProp) {
 9 |         setShow(_ => !show);
10 |       }
...
13 |       None;
14 |     },
15 |     [|show|],
16 |   ).

Error: ExhaustiveDeps: Missing 'randomProp' in the dependency array
```

## Acknowledgements

Thanks to [@jchavarri](https://github.com/jchavarri)
