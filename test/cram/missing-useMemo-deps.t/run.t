useMemo should check exhaustive deps
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  let make ~value =
    let _memoized =
      [%ocaml.error "ExhaustiveDeps: Missing 'value' in the dependency array"] in
    div[@@react.component ]
