Hooks inside functions passed to useEffect should be detected as conditional
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  let make ~value =
    React.useEffect1 (fun () -> let _ = React.useState (fun () -> 0) in None)
      [||];
    div[@@react.component ]
