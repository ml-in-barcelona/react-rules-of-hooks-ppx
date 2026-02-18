  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~handler =
  >   React.useEffect1
  >     (fun () -> Some (fun () -> handler ()))
  >     [||];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Dependencies used in cleanup function should be tracked
  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'handler' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~handler  =
    React.useEffect1 (fun () -> Some (fun () -> handler ())) [||]; div[@@react.component
                                                                      ]
