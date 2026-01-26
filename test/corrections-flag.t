  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~value =
  >   let _memoized = React.useMemo1 (fun () -> value + 1) [||] in
  >   div
  > EOF

Without the -corrections flag, only the warning should appear (no diff):
  $ ../src/standalone.exe input.ml 2>&1 || true
  [@@@ocaml.ppwarning
    "ExhaustiveDeps: Missing 'value' in the dependency array. To suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value =
    let _memoized = React.useMemo1 (fun () -> value + 1) [||] in div[@@react.component
                                                                      ]

With the -corrections flag, the diff should appear with properly formatted deps array:
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^\+.*\[|^\-.*\[" | head -2
  -  let _memoized = React.useMemo1 (fun () -> value + 1) [||] in
  +  let _memoized = React.useMemo1 (fun () -> value + 1) [| value |] in
