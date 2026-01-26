let[@react.component] make ~condition =
  let i = ref 0 in
  while !i < 10 do
    let _ = React.useState (fun () -> 0) in
    i := !i + 1
  done;
  div
