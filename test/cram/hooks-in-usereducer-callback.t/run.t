Hooks inside reducer functions passed to useReducer should be detected as conditional
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  let make ~initialValue =
    let (_state, _dispatch) =
      React.useReducer
        (fun state action -> let _ = React.useState (fun () -> 0) in state)
        initialValue in
    div[@@react.component ]
