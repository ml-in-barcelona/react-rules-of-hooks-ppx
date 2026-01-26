Hooks inside functions passed to useMemo should be detected as conditional
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  [@@@ocaml.ppwarning
    "ExhaustiveDeps: Missing 'value' in the dependency array. To suppress this warning, add [@@warning \"-22\"] to the expression"]
  let make ~value =
    let _memoized =
      React.useMemo1
        (fun () -> let _ = React.useState (fun () -> 0) in value + 1) [||] in
    div[@@react.component ]
