  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~randomProp:(_ : string) =
  >   let show, _setShow = React.useState (fun () -> "sTatE") in
  >   (React.useEffect1
  >     (fun () -> ((Js.log randomProp; None)[@reason.preserve_braces ]))
  >     [|show|])[@disable_exhaustive_deps ];
  >   div
  > EOF

  $ ../src/standalone.exe input.ml 2>&1 || true
  let make ~randomProp:(_ : string) =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    ((React.useEffect1
        (fun () -> ((Js.log randomProp; None)[@reason.preserve_braces ]))
        [|show|])
    [@disable_exhaustive_deps ]);
    div[@@react.component ]
