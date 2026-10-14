  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~randomProp:(_ : string) =
  >   let show, _setShow = React.useState (fun () -> "sTatE") in
  >   React.useEffect1
  >     (fun () -> Js.log randomProp; None)
  >     [|show|][@disable_exhaustive_deps ];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make ~randomProp:(_ : string) =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    ((React.useEffect1 (fun () -> Js.log randomProp; None) [|show|])
    [@disable_exhaustive_deps ]);
    div[@@react.component ]

Test that the attribute on a let binding disables deps checks for the hooks in that binding:

  $ cat > input2.mlx << 'EOF'
  > let[@react.component] make ~randomProp =
  >   let [@disable_exhaustive_deps] () =
  >     React.useEffect1 (fun () -> Js.log randomProp; None) [||]
  >   in
  >   div
  > EOF

  $ mlx-pp -print-ml input2.mlx > input2.ml

  $ ../src/standalone.exe input2.ml
  let make ~randomProp =
    let () = React.useEffect1 (fun () -> Js.log randomProp; None) [||][@@disable_exhaustive_deps
                                                                      ] in
    div[@@react.component ]

Test that the binding attribute does not leak to the next binding:

  $ cat > input3.mlx << 'EOF'
  > let[@react.component] make ~randomProp =
  >   let[@disable_exhaustive_deps] () =
  >     React.useEffect1 (fun () -> Js.log randomProp; None) [||]
  >   in
  >   let () = React.useEffect1 (fun () -> Js.log randomProp; None) [||] in
  >   div
  > EOF

  $ mlx-pp -print-ml input3.mlx > input3.ml

  $ ../src/standalone.exe input3.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'randomProp' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~randomProp =
    let () = React.useEffect1 (fun () -> Js.log randomProp; None) [||][@@disable_exhaustive_deps
                                                                      ] in
    let () = React.useEffect1 (fun () -> Js.log randomProp; None) [||] in div
    [@@react.component ]

Test that the attribute on both the binding and the hook call is accepted without a warning:

  $ cat > input4.mlx << 'EOF'
  > let[@react.component] make ~randomProp =
  >   let[@disable_exhaustive_deps] () =
  >     (React.useEffect1 (fun () -> Js.log randomProp; None) [||])[@disable_exhaustive_deps]
  >   in
  >   div
  > EOF

  $ mlx-pp -print-ml input4.mlx > input4.ml

  $ ../src/standalone.exe input4.ml
  let make ~randomProp =
    let () = ((React.useEffect1 (fun () -> Js.log randomProp; None) [||])
      [@disable_exhaustive_deps ])[@@disable_exhaustive_deps ] in
    div[@@react.component ]
