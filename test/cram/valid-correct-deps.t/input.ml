let[@react.component] make ~someProp =
  let (state, _) = React.useState (fun () -> 0) in
  React.useEffect2
    (fun () -> Js.log someProp; Js.log state; None)
    (someProp, state);
  div
