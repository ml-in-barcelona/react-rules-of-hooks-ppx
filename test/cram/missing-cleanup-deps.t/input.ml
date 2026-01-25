let[@react.component] make ~handler =
  React.useEffect1
    (fun () -> Some (fun () -> handler ()))
    [||];
  div
