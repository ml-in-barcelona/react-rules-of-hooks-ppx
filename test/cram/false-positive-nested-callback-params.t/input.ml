let[@react.component] make () =
  React.useEffect1
    (fun () ->
      List.iter (fun item -> Js.log item) [];
      None)
    [||];
  div
