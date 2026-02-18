  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~value =
  >   let _memoized = React.useMemo1 (fun () -> 
  >     let _ = React.useState (fun () -> 0) in
  >     value + 1
  >   ) [||] in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'value' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~value  =
    let _memoized =
      React.useMemo1
        (fun () -> let _ = React.useState (fun () -> 0) in value + 1) [||] in
    div[@@react.component ]
