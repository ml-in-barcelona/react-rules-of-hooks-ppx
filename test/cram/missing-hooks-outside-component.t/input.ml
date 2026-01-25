let _ = React.useState (fun () -> 0)

let regularFunction () =
  let _ = React.useState (fun () -> 0) in
  ()

let[@react.component] make () = div
