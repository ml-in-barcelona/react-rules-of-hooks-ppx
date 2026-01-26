let[@react.component] make ~value =
  let _memoized =
    React.useMemo1
      (fun () ->
        let _ = React.useState (fun () -> 0) in
        value + 1)
      [||]
  in
  div
