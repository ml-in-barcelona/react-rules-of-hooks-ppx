let[@react.component] make ~value =
  let _callback = React.useCallback1 (fun () -> Js.log value) [||] in
  div
