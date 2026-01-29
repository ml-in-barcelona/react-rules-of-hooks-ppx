  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~someProp =
  >   let (state, _) = React.useState (fun () -> 0) in
  >   React.useEffect2
  >     (fun () -> Js.log someProp; Js.log state; None)
  >     (someProp, state);
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

Correct dependencies should not trigger any error
  $ ../src/standalone.exe input.ml 2>&1
  let make ~someProp =
    let (state, _) = React.useState (fun () -> 0) in
    React.useEffect2 (fun () -> Js.log someProp; Js.log state; None)
      (someProp, state);
    div[@@react.component ]
