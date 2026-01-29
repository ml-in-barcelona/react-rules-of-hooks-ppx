  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~condition =
  >   let _ = condition && (let _ = React.useState (fun () -> 0) in true) in
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

Hooks inside && or || short-circuit should be detected
  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~condition =
    let _ = condition && (let _ = React.useState (fun () -> 0) in true) in div
    [@@react.component ]
