let[@react.component] make () =
  Js.log "starting component";
  let (state, _) = React.useState (fun () -> 0) in
  Js.log state;
  div
