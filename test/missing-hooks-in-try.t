  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   try
  >     let _ = React.useState (fun () -> 0) in
  >     div
  >   with _ -> div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Hooks inside try/catch should be detected as conditional
  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make () = try let _ = React.useState (fun () -> 0) in div with | _ -> div
    [@@react.component ]
