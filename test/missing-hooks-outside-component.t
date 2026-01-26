  $ cat > input.ml << 'EOF'
  > let _ = React.useState (fun () -> 0)
  > 
  > let regularFunction () =
  >   let _ = React.useState (fun () -> 0) in
  >   ()
  > 
  > let useMyCustomHook () =
  >   let (state, setState) = React.useState (fun () -> 0) in
  >   (state, setState)
  > 
  > let[@react.component] make () =
  >   let _ = React.useState (fun () -> 0) in
  >   div
  > EOF

Hooks outside components or custom hooks should be detected
  $ ../src/standalone.exe input.ml 2>&1 || true
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks. To suppress this warning, add [@@warning \"-22\"] to the expression"]
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks. To suppress this warning, add [@@warning \"-22\"] to the expression"]
  let _ = React.useState (fun () -> 0)
  let regularFunction () = let _ = React.useState (fun () -> 0) in ()
  let useMyCustomHook () =
    let (state, setState) = React.useState (fun () -> 0) in (state, setState)
  let make () = let _ = React.useState (fun () -> 0) in div[@@react.component ]
