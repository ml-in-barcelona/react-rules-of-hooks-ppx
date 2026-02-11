  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~maybeValue =
  >   let _ = match maybeValue with
  >     | Some x -> x
  >     | None -> 
  >       let (state, _) = React.useState (fun () -> 0) in
  >       state
  >   in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Hook in Option.None branch (similar to JS nullish coalescing) should error
  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~maybeValue =
    let _ =
      match maybeValue with
      | Some x -> x
      | None -> let (state, _) = React.useState (fun () -> 0) in state in
    div[@@react.component ]

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~maybeValue =
  >   let _ = Option.value maybeValue ~default:(
  >     let (state, _) = React.useState (fun () -> 0) in
  >     state
  >   ) in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Hook in Option.value default (lazy evaluation means conditional)
This might not be caught since Option.value eagerly evaluates default in OCaml
  $ ../src/standalone.exe input.ml 2>&1
  let make ~maybeValue =
    let _ =
      Option.value maybeValue
        ~default:(let (state, _) = React.useState (fun () -> 0) in state) in
    div[@@react.component ]

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~maybeCallback =
  >   let _ = match maybeCallback with
  >     | Some callback -> callback ()
  >     | None -> useDefaultHook ()
  >   in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Hook call in pattern match branch should error
  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~maybeCallback =
    let _ =
      match maybeCallback with
      | Some callback -> callback ()
      | None -> useDefaultHook () in
    div[@@react.component ]
