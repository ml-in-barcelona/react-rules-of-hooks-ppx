Unsuffixed useMemo/useCallback recompute or reallocate every render, so the
memoization does nothing (ported from eslint's one-argument warning).

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~value =
  >   let _memoized = React.useMemo (fun () -> value + 1) in
  >   let _callback = React.useCallback (fun x -> x + value) in
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: React.useMemo does nothing when called without a dependency array. Did you mean React.useMemoN with dependencies?"]
  [@@@ocaml.ppwarning
    "exhaustive-deps: React.useCallback does nothing when called without a dependency array. Did you mean React.useCallbackN with dependencies?"]
  let make ~value =
    let _memoized = React.useMemo (fun () -> value + 1) in
    let _callback = React.useCallback (fun x -> x + value) in div[@@react.component
                                                                   ]

No missing-deps warning accompanies it (exhaustiveness does not apply
without an array), and suffixed calls keep full checking:

  $ cat > input2.ml << 'EOF'
  > let[@react.component] make ~value =
  >   let _memoized = React.useMemo1 (fun () -> value + 1) [||] in
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'value' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value =
    let _memoized = React.useMemo1 (fun () -> value + 1) [||] in div[@@react.component
                                                                      ]
