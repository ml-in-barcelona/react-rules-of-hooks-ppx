Hooks inside lazy expressions should be detected (deferred execution)
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error "Hooks can't be called conditionally"]
  let make () = let _ = lazy (React.useState (fun () -> 0)) in div[@@react.component
                                                                    ]
