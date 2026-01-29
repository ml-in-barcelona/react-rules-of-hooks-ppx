  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~randomProp:(_ : string) =
  >   let show, _setShow = React.useState (fun () -> "sTatE") in
  >   React.useEffect1
  >     (fun () ->
  >       ((Js.log randomProp;
  >         None)
  >       [@reason.preserve_braces]))
  >     [| show |] [@disable_exhaustive_deps];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make ~randomProp:(_ : string) =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    ((React.useEffect1
        (fun () -> ((Js.log randomProp; None)[@reason.preserve_braces ]))
        [|show|])
    [@disable_exhaustive_deps ]);
    div[@@react.component ]
