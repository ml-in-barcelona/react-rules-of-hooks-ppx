  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~items =
  >   let _ = List.map (fun _ -> React.useState (fun () -> 0)) items in
  >   div
  > EOF

Hooks inside callbacks like List.map should be detected (variable execution count)
NOTE: This is a known limitation - detecting hooks in arbitrary callbacks requires
more sophisticated analysis. For v0.1, only JSX callbacks are detected.
  $ ../src/standalone.exe input.ml 2>&1 || true
  let make ~items =
    let _ = List.map (fun _ -> React.useState (fun () -> 0)) items in div
    [@@react.component ]
