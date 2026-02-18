  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~randomProp =
  >   let (show, _setShow) = React.useState (fun () -> false) in
  >   React.useLayoutEffect1
  >     (fun () -> Js.log randomProp; None)
  >     [|show|];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

useLayoutEffect should check exhaustive deps like useEffect
  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'randomProp' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~randomProp =
    let (show, _setShow) = React.useState (fun () -> false) in
    React.useLayoutEffect1 (fun () -> Js.log randomProp; None) [|show|]; div
    [@@react.component ]
