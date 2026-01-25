let[@react.component] make () =
  React.useEffect1
    (fun () ->
      let helper x = x + 1 in
      Js.log (helper 1);
      None)
    [||];
  div
