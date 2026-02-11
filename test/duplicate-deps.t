  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~someProp =
  >   React.useEffect2
  >     (fun () -> Js.log someProp; None)
  >     (someProp, someProp);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Duplicate dependencies should warn (same dep listed twice)
  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "exhaustive-deps: Duplicate dependency 'someProp' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~someProp =
    React.useEffect2 (fun () -> Js.log someProp; None) (someProp, someProp);
    div[@@react.component ]

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~someProp =
  >   React.useEffect1
  >     (fun () -> Js.log someProp; None)
  >     [| someProp; someProp |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Array syntax with duplicates
  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "exhaustive-deps: Duplicate dependency 'someProp' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~someProp =
    React.useEffect1 (fun () -> Js.log someProp; None) [|someProp;someProp|];
    div[@@react.component ]
