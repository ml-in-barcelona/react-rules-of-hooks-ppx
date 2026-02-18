Test that the -disable-exhaustive-deps flag disables exhaustive deps checking

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~randomProp:(_ : string) =
  >   let show, _setShow = React.useState (fun () -> "sTatE") in
  >   React.useEffect1
  >     (fun () -> Js.log randomProp; None)
  >     [|show|];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Without the flag, the exhaustive deps warning should appear:

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing 'randomProp' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~randomProp:(_ : string)  =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    React.useEffect1 (fun () -> Js.log randomProp; None) [|show|]; div[@@react.component
                                                                      ]

With the -disable-exhaustive-deps flag, no warning should appear:

  $ ../src/standalone.exe -disable-exhaustive-deps input.ml 2>&1 || true
  let make ~randomProp:(_ : string)  =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    React.useEffect1 (fun () -> Js.log randomProp; None) [|show|]; div[@@react.component
                                                                      ]
