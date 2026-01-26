  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~handler =
  >   React.useEffect1
  >     (fun () -> Some (fun () -> handler ()))
  >     [||];
  >   div
  > EOF

Dependencies used in cleanup function should be tracked
  $ ../src/standalone.exe input.ml 2>&1 || true
  [@@@ocaml.ppwarning
    "ExhaustiveDeps: Missing 'handler' in the dependency array. To suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~handler =
    React.useEffect1 (fun () -> Some (fun () -> handler ())) [||]; div[@@react.component
                                                                      ]
