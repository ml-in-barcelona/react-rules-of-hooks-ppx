let[@react.component] make ~value =
  let _memoized = React.useMemo1 (fun () -> value + 1) [||] in
  div
