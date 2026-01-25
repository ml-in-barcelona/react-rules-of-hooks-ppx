let[@react.component] make () =
  assert (let _ = React.useState (fun () -> 0) in true);
  div
