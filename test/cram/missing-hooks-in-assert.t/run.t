Hooks inside assert should be detected
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error "Hooks can't be called conditionally"]
  let make () = assert ((let _ = React.useState (fun () -> 0) in true)); div
    [@@react.component ]
