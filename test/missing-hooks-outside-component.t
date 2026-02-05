  $ cat > input.mlx << 'EOF'
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

  $ mlx-pp -print-ml input.mlx > input.ml

Hooks outside components or custom hooks should be detected
  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let _ = React.useState (fun () -> 0)
  let regularFunction () = let _ = React.useState (fun () -> 0) in ()
  let useMyCustomHook () =
    let (state, setState) = React.useState (fun () -> 0) in (state, setState)
  let make () = let _ = React.useState (fun () -> 0) in div[@@react.component ]
