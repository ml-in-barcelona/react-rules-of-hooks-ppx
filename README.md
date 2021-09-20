# react-rules-of-hooks-ppx

> STATUS: This project isn't complete and might give false-positives. [Read more](https://github.com/reason-in-barcelona/react-rules-of-hooks-ppx#status)

This package is a no-op ppx rewriter. It is used as a 'lint' to
enforce React's [Rules of Hooks](https://en.reactjs.org/docs/hooks-rules.html).

- [x] Exhaustive dependencies in useEffect
- [x] Order of Hooks
  - [x] Hooks shoudn't be called in different order
  - [x] Only Call Hooks at the Top Level

## Why

One of the points of using [Reason](https://reasonml.github.io) or [ReScript](https://rescript-lang.org) is to have a compiler that warns about issues with your code, where functions expect different types from the given ones. That's Type-checking and works amazingly well, but there are some cases where even with the right types, the runtime of your program can cause issues. Very commonly in side-effects. I found this case while working with ReasonReact.

ReasonReact and useEffect hooks is one of those cases, where types ensures that the functions are called correctly, but they have certain rules that aren't cacheable at the type-system. Not following those rules might cause some unexpected bug or even a run-time error.

This package solves this problem, lints the `use(Layout)Effect` from your react.components based on the [React's Rules of Hooks](https://en.reactjs.org/docs/hooks-rules.html)

## Status

It's a proof of concept on re-creating the ESLint plugin, and it's very restrictive and not always useful in the Reason/ReScript context. Values are immutable by default, so functions or Modules from the exterior of a useEffect will not change at anytime during runtime. The only benefit is where state/props values are missing, which is a great addition to check your useEffects.

## Install

```bash
npm install react-rules-of-hooks-ppx --save-dev
# or
yarn add react-rules-of-hooks-ppx --dev
```

Add the ppx on the BuckleScript config (`bsconfig.json`)

```json
"ppx-flags": [
  "react-rules-of-hooks-ppx/Bin.exe"
]
```

You can disable globally both rules passing parameters to the ppx:

### Disable "Exhaustive dependencies in useEffect"

```json
"ppx-flags": [
  ["react-rules-of-hooks-ppx/Bin.exe", "-exhaustive-deps"]
]
```

### Disable "Order of Hooks"

```json
"ppx-flags": [
  ["react-rules-of-hooks-ppx/Bin.exe", "-order-of-hooks"]
]
```

## Issues

Feel free to use it and report any unexpected behaviour in the [issue section](https://github.com/reason-in-barcelona/react-rules-of-hooks-ppx/issues)

## Demo

Here we have a dummy react component:

```re
[@react.component]
/* Recives a prop called "randomProp" */
let make = (~randomProp) => {
  let (show, setShow) = React.useState(() => false);

  /* We have a useEffect that re-runs each time that "show" changes it's value, and we want to update "show" when randomProp is true. */
  React.useEffect1(
    () => {
      /* Since this effect relies on "randomProp" and misses ont the dependency array, will cause undesired behaviour. */
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

Produces the following error:

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
