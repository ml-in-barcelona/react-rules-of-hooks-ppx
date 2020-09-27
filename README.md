# react-rules-of-hooks-ppx

This ppx validates the rules of React hooks.

### Install
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

### Demo

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

The ppx produces the following error:

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

### Issues

This ppx is in an early stage ⚠️. Feel free to use it and report any unexpected behaviour https://github.com/reason-in-barcelona/react-rules-of-hooks-ppx/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc

### Acknowledgements
[@jchavarri](https://github.com/jchavarri)