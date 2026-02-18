  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~value =
  >   let _callback = React.useCallback1 (fun () -> Js.log value) [||] in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

useCallback should check exhaustive deps
  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing 'value' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value  =
    let _callback = React.useCallback1 (fun () -> Js.log value) [||] in div
    [@@react.component ]
