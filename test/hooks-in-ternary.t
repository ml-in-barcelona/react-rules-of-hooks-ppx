  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~condition =
  >   let _ = if condition then React.useState (fun () -> 0) else (0, fun _ -> ()) in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Hooks in ternary/if-else expression should error (conditional call)
  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~condition  =
    let _ =
      if condition then React.useState (fun () -> 0) else (0, ((fun _ -> ()))) in
    div[@@react.component ]

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~condition =
  >   let _ = (if condition then useTernaryHook () else ()) in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Simple ternary with hook call
  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~condition  =
    let _ = if condition then useTernaryHook () else () in div[@@react.component
                                                                ]
