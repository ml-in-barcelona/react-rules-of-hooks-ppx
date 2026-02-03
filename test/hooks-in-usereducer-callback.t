  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~initialValue =
  >   let _state, _dispatch = React.useReducer (fun state action ->
  >     let _ = React.useState (fun () -> 0) in
  >     state
  >   ) initialValue in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make ~initialValue  =
    let (_state, _dispatch) =
      React.useReducer
        (fun state ->
           fun action -> let _ = React.useState (fun () -> 0) in state)
        initialValue in
    div[@@react.component ]
