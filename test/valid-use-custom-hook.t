  $ cat > input.ml << 'EOF'
  > let useCustom () =
  >   let (state, setState) = React.useState (fun () -> false) in
  >   let ref = React.useRef None in
  >   React.useEffect1 (fun () -> None) [||];
  >   (ref, state)
  > EOF

Custom hook named "useCustom" should be recognized as a valid hook definition
  $ ../src/standalone.exe input.ml 2>&1
  let useCustom () =
    let (state, setState) = React.useState (fun () -> false) in
    let ref = React.useRef None in
    React.useEffect1 (fun () -> None) [||]; (ref, state)
