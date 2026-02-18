  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~value =
  >   let _memoized = React.useMemo1 (fun () -> value + 1) [||] in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

useMemo should check exhaustive deps
  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'value' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value  =
    let _memoized = React.useMemo1 (fun () -> value + 1) [||] in div[@@react.component
                                                                      ]
