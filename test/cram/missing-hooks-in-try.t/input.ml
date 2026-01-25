let[@react.component] make () =
  try
    let _ = React.useState (fun () -> 0) in
    div
  with _ -> div
