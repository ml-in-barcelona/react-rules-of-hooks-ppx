  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect1
  >     (fun () ->
  >       List.iter (fun item -> Js.log item) [];
  >       None)
  >     [||];
  >   div
  > EOF

Nested callback parameters should NOT trigger missing deps (item is local to callback)
  $ ../src/standalone.exe input.ml 2>&1
  let make () =
    React.useEffect1 (fun () -> List.iter (fun item -> Js.log item) []; None)
      [||];
    div[@@react.component ]
