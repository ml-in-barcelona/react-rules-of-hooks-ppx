Hooks inside && or || short-circuit should be detected
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error "Hooks can't be called conditionally"]
  let make ~condition =
    let _ = condition && (let _ = React.useState (fun () -> 0) in true) in div
    [@@react.component ]
