  $ cat > input.mlx << 'EOF'
  > let globalValue = 42
  > 
  > let[@react.component] make () =
  >   React.useEffect1
  >     (fun () -> Js.log globalValue; None)
  >     [| globalValue |];
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

Module-level values in deps should warn as unnecessary
(outer scope values don't trigger re-renders when mutated)
  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "exhaustive-deps: React Hook React.useEffect1 has an unnecessary dependency: 'globalValue'. Outer scope values like 'globalValue' aren't valid dependencies because mutating them doesn't re-render the component.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let globalValue = 42
  let make () =
    React.useEffect1 (fun () -> Js.log globalValue; None) [|globalValue|]; div
    [@@react.component ]

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect1
  >     (fun () -> Js.log Js.log; None)
  >     [| Js.log |];
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

External module values (like Js.log) in deps are unnecessary
  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "exhaustive-deps: React Hook React.useEffect1 has an unnecessary dependency: 'Js.log'. Outer scope values like 'Js.log' aren't valid dependencies because mutating them doesn't re-render the component.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    React.useEffect1 (fun () -> Js.log Js.log; None) [|Js.log|]; div[@@react.component
                                                                      ]
