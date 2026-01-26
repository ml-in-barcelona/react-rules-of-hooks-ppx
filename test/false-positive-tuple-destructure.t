  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect1
  >     (fun () ->
  >       let (a, b) = (1, 2) in
  >       Js.log a;
  >       Js.log b;
  >       None)
  >     [||];
  >   div
  > EOF

Tuple destructuring inside effect should NOT trigger missing deps (a, b are local)
  $ ../src/standalone.exe input.ml 2>&1
  let make () =
    React.useEffect1
      (fun () -> let (a, b) = (1, 2) in Js.log a; Js.log b; None) [||];
    div[@@react.component ]
