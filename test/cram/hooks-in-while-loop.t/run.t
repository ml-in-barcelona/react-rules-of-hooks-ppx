Hooks inside while loops should be detected as conditional
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally. Hooks must be called at the top level of your component, before any early returns. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~condition =
    let i = ref 0 in
    while (!i) < 10 do
      (let _ = React.useState (fun () -> 0) in i := ((!i) + 1)) done;
    div[@@react.component ]
