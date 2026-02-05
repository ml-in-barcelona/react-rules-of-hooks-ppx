  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect1
  >     (fun () ->
  >       let helper x = x + 1 in
  >       Js.log (helper 1);
  >       None)
  >     [||];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Function parameters inside effect should NOT trigger missing deps (x is local to helper)
  $ ../src/standalone.exe input.ml 2>&1
  let make () =
    React.useEffect1
      (fun () -> let helper x = x + 1 in Js.log (helper 1); None) [||];
    div[@@react.component ]
