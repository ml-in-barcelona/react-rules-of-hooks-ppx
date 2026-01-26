module React = {
  let useState = init => (init(), _ => ());
  let useEffect = (fn, deps) => ignore((fn, deps));
  let useEffect1 = (fn, deps) => ignore((fn, deps));
  let useMemo1 = (fn, _deps) => fn();
  let useEffect2 = (fn, deps) => ignore((fn, deps));
  let useMemo = (fn, deps) => (fn(), deps);
  let useCallback = (fn, deps) => (fn, deps);
};

[@react.component]
let valid_component = (~name) => {
  let (state, _setState) = React.useState(() => 0);
  React.useEffect1(
    () => {
      Js.log(state);
      None;
    },
    [|state|],
  );
  Js.log(name);
  ();
};

[@react.component]
let missing_dep_component = (~name) => {
  let (state, _setState) = React.useState(() => 0);
  React.useEffect1(
    () => {
      Js.log(state);
      None;
    },
    [|name|],
  );
  let _expensive = React.useMemo1(() => {45 + 45 + name}, [||]);
  let _expensive_but_ignored =
    [@disable_exhaustive_deps] React.useMemo1(() => {45 + 45 + name}, [||]);
  ();
};

[@react.component]
let conditional_hook_component = (~condition) => {
  if (condition) {
    let (_state, _) = React.useState(() => 0);
    ();
  };
  ();
};
