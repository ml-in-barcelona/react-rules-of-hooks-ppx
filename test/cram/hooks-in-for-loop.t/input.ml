let[@react.component] make ~items =
  for i = 0 to Array.length items - 1 do
    let _ = React.useState (fun () -> 0) in
    ()
  done;
  div
