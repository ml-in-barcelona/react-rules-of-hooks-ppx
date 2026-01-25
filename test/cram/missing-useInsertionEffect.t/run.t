useInsertionEffect should check exhaustive deps like useEffect
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  let make ~randomProp =
    let (show, _setShow) = React.useState (fun () -> false) in
    [%ocaml.error
      "ExhaustiveDeps: Missing 'randomProp' in the dependency array"];
    div[@@react.component ]
