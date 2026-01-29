  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~randomProp =
  >   let (show, _setShow) = React.useState (fun () -> false) in
  >   React.useInsertionEffect1
  >     (fun () -> Js.log randomProp; None)
  >     [|show|];
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

useInsertionEffect should check exhaustive deps like useEffect
  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing 'randomProp' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~randomProp =
    let (show, _setShow) = React.useState (fun () -> false) in
    React.useInsertionEffect1 (fun () -> Js.log randomProp; None) [|show|]; div
    [@@react.component ]
