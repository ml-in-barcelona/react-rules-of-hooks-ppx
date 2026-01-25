  $ ../../../src/standalone.exe input.ml 2>&1 || true
  let make ~randomProp:(_ : string) =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    [%ocaml.error
      "ExhaustiveDeps: Missing 'randomProp' in the dependency array"];
    div[@@react.component ]
