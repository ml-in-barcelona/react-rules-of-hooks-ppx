let[@react.component] make ~condition =
  if condition then div
  else
    let _ = React.useState (fun () -> 0) in
    div
