  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~value =
  >   let _memoized = React.useMemo1 (fun () -> value + 1) [||] in
  >   div
  > EOF

useMemo should check exhaustive deps
  $ ../src/standalone.exe input.ml 2>&1 || true
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing 'value' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value =
    let _memoized = React.useMemo1 (fun () -> value + 1) [||] in div[@@react.component
                                                                      ]
