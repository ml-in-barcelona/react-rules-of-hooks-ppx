  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~condition =
  >   if condition then div
  >   else (
  >     let _ = React.useState (fun () -> 0) in
  >     div
  >   )
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~condition  =
    if condition then div else (let _ = React.useState (fun () -> 0) in div)
    [@@react.component ]
