  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~randomProp =
  >   let (show, _setShow) = React.useState (fun () -> false) in
  >   React.useLayoutEffect1
  >     (fun () -> Js.log randomProp; None)
  >     [|show|];
  >   div
  > EOF

useLayoutEffect should check exhaustive deps like useEffect
  $ ../src/standalone.exe input.ml 2>&1 || true
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing 'randomProp' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~randomProp =
    let (show, _setShow) = React.useState (fun () -> false) in
    React.useLayoutEffect1 (fun () -> Js.log randomProp; None) [|show|]; div
    [@@react.component ]
