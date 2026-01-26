  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~value =
  >   React.useEffect1 (fun () ->
  >     let _ = React.useState (fun () -> 0) in
  >     None
  >   ) [||];
  >   div
  > EOF

  $ ../src/standalone.exe input.ml 2>&1 || true
  let make ~value =
    React.useEffect1 (fun () -> let _ = React.useState (fun () -> 0) in None)
      [||];
    div[@@react.component ]
