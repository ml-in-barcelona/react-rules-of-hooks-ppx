let useMyCustomHook () =
  let (state, setState) = React.useState (fun () -> 0) in
  (state, setState)

let[@react.component] make () =
  let _ = useMyCustomHook () in
  div
