  $ cat > input.mlx << 'EOF'
  > let _ = React.useState (fun () -> 0)
  > 
  > let[@react.component] make () = div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

Namespace hooks (React.useState) at top level should error
  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let _ = React.useState (fun () -> 0)
  let make () = div[@@react.component ]

  $ cat > input.mlx << 'EOF'
  > let _ = React.useEffect (fun () -> None) [||]
  > 
  > let[@react.component] make () = div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

React.useEffect at top level should error
  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let _ = React.useEffect (fun () -> None) [||]
  let make () = div[@@react.component ]
