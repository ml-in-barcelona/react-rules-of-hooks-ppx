Hooks inside try/catch should be detected as conditional
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error "Hooks can't be called conditionally"]
  let make () = try let _ = React.useState (fun () -> 0) in div with | _ -> div
    [@@react.component ]
