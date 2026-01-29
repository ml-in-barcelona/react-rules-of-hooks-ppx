Test that the -disable-order-of-hooks flag disables hooks-outside-component checking

  $ cat > input.mlx << 'EOF'
  > let make () =
  >   let show, _setShow = React.useState (fun () -> "sTatE") in
  >   print_endline show
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Without the flag, the hooks-outside-component warning should appear:

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let make () =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    print_endline show

With the -disable-order-of-hooks flag, no warning should appear:

  $ ../src/standalone.exe -disable-order-of-hooks input.ml 2>&1 || true
  let make () =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    print_endline show
