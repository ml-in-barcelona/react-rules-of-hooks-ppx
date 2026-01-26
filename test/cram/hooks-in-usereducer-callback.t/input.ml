let[@react.component] make ~initialValue =
  let _state, _dispatch =
    React.useReducer
      (fun state action ->
        let _ = React.useState (fun () -> 0) in
        state)
      initialValue
  in
  div
