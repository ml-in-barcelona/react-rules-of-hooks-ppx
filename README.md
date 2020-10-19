# react-rules-of-hooks-ppx
This package is a no-op ppx rewriter. It is used as a 'lint' to
enforce React's [Rules of Hooks](https://en.reactjs.org/docs/hooks-rules.html).

- [x] Exhaustive dependencies in useEffect
- [x] Order of Hooks
  - [x] Hooks shoudn't be called in different order
  - [x] Only Call Hooks at the Top Level

## Why
One of the points of using [Reason](https://reasonml.github.io) or [ReScript](https://rescript-lang.org) is to have a compiler that warns about issues with your code, where functions expect different structures from the given ones and any sort of missmatch between interfaces. This works amazingly well, but I found a case where the compiler can't validate that your code works as expected.

Using ReasonReact and writting hooks, which have certain rules that aren't catchable by the compiler. Not following one of the rules, might cause some unexpected bug or a run-time error.

This package solves this problem, brings those run-time errors to compile errors.

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

#### Disable "Exhaustive dependencies in useEffect"
```json
"ppx-flags": [
  ["react-rules-of-hooks-ppx/Bin.exe", "-exhaustive-deps"]
]
```

#### Disable "Order of Hooks"
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