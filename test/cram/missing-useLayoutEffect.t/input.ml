let[@react.component] make ~randomProp =
  let (show, _setShow) = React.useState (fun () -> false) in
  React.useLayoutEffect1
    (fun () -> Js.log randomProp; None)
    [|show|];
  div
