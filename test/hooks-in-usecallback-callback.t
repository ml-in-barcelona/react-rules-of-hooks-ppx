  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let _ = React.useCallback (fun () ->
  >     let _ = React.useState (fun () -> 0) in
  >     ()
  >   ) [||] in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Hooks inside useCallback callback should error
  $ ../src/standalone.exe input.ml 2>&1
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make () =
    let _ =
      React.useCallback (fun () -> let _ = React.useState (fun () -> 0) in ())
        [||] in
    div[@@react.component ]
