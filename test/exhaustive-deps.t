  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~randomProp:(_ : string) =
  >   let show, _setShow = React.useState (fun () -> "sTatE") in
  >   React.useEffect1
  >     (fun () -> Js.log randomProp; None)
  >     [|show|];
  >   div
  > EOF

  $ ../src/standalone.exe input.ml 2>&1 || true
  let make ~randomProp:(_ : string) =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    [%ocaml.error
      "ExhaustiveDeps: Missing 'randomProp' in the dependency array"];
    div[@@react.component ]
