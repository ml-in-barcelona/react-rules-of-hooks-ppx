let[@react.component] make () =
  React.useEffect1
    (fun () ->
      let (a, b) = (1, 2) in
      Js.log a;
      Js.log b;
      None)
    [||];
  div
