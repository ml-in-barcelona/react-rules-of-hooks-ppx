let[@react.component] make ~randomProp:(_ : string) =
  let show, _setShow = React.useState (fun () -> "sTatE") in
  React.useEffect1
    (fun () -> ((Js.log randomProp; None)[@reason.preserve_braces ]))
    [|show|];
  div
