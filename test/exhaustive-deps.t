  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~randomProp:(_ : string) =
  >   let show, _setShow = React.useState (fun () -> "sTatE") in
  >   React.useEffect1
  >     (fun () -> ((Js.log randomProp; None)[@reason.preserve_braces ]))
  >     [|show|];
  >   div
  > EOF

  $ ../src/standalone.exe input.ml 2>&1 || true
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing 'randomProp' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~randomProp:(_ : string) =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    React.useEffect1
      (fun () -> ((Js.log randomProp; None)[@reason.preserve_braces ]))
      [|show|];
    div[@@react.component ]
