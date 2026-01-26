  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~value =
  >   let _callback = React.useCallback1 (fun () -> Js.log value) [||] in
  >   div
  > EOF

useCallback should check exhaustive deps
  $ ../src/standalone.exe input.ml 2>&1 || true
  [@@@ocaml.ppwarning
    "ExhaustiveDeps: Missing 'value' in the dependency array. To suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value =
    let _callback = React.useCallback1 (fun () -> Js.log value) [||] in div
    [@@react.component ]
