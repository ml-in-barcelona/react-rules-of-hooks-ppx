let[@react.component] make ~condition =
  let _ = condition && (let _ = React.useState (fun () -> 0) in true) in
  div
