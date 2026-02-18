  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~value =
  >   React.useEffect1 (fun () ->
  >     Js.log "effect 1";
  >     None
  >   ) [||];
  >   React.useEffect2 (fun () ->
  >     Js.log "effect 2";
  >     None
  >   ) (value, ());
  >   let (state, _) = React.useState (fun () -> 0) in
  >   React.useEffect1 (fun () ->
  >     Js.log state;
  >     None
  >   ) [||];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Multiple hooks in sequence at top level should all be valid (no conditional error)
  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'state' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value  =
    React.useEffect1 (fun () -> Js.log "effect 1"; None) [||];
    React.useEffect2 (fun () -> Js.log "effect 2"; None) (value, ());
    (let (state, _) = React.useState (fun () -> 0) in
     React.useEffect1 (fun () -> Js.log state; None) [||]; div)[@@react.component
                                                                 ]
