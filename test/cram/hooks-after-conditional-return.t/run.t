Hooks after conditional return (in else branch) should be detected as conditional
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally. Hooks must be called at the top level of your component, before any early returns. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~condition =
    if condition then div else (let _ = React.useState (fun () -> 0) in div)
    [@@react.component ]
