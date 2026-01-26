let[@react.component] make ~value =
  React.useEffect1
    (fun () ->
      let _ = React.useState (fun () -> 0) in
      None)
    [||];
  div
