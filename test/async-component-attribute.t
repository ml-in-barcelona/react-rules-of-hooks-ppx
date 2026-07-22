  $ cat > input.mlx << 'EOF'
  > let[@react.async.component] make () =
  >   let _ = React.useState (fun () -> 0) in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Hooks inside [@react.async.component] functions are valid
  $ ../src/standalone.exe input.ml
  let make () = let _ = React.useState (fun () -> 0) in div[@@react.async.component
                                                             ]

  $ cat > input.mlx << 'EOF'
  > let[@react.async.component] make ~condition =
  >   let _ =
  >     if condition then Some (React.useState (fun () -> 0)) else None
  >   in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Rules of hooks still apply inside [@react.async.component] functions
  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~condition =
    let _ = if condition then Some (React.useState (fun () -> 0)) else None in
    div[@@react.async.component ]
