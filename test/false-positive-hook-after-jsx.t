A hook called after a JSX element in a sequence is at the top level, not inside JSX:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   ignore <div />;
  >   let x, _ = React.useState (fun () -> 0) in
  >   x
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make () =
    ignore ((div () ~children:[])[@JSX ]);
    (let (x, _) = React.useState (fun () -> 0) in x)[@@react.component ]
