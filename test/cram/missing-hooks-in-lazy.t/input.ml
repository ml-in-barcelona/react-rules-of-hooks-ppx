let[@react.component] make () =
  let _ = lazy (React.useState (fun () -> 0)) in
  div
