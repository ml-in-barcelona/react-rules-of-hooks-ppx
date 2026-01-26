  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~condition =
  >   let _ = condition && (let _ = React.useState (fun () -> 0) in true) in
  >   div
  > EOF

Hooks inside && or || short-circuit should be detected
  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~condition =
    let _ = condition && (let _ = React.useState (fun () -> 0) in true) in div
    [@@react.component ]
