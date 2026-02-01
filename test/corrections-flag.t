  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~value =
  >   let _memoized = React.useMemo1 (fun () -> value + 1) [||] in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Without the -corrections flag, only the warning should appear (no diff):
  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing 'value' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value =
    let _memoized = React.useMemo1 (fun () -> value + 1) [||] in div[@@react.component
                                                                      ]

With the -corrections flag, the diff should appear with properly formatted deps array:
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*\[" | head -2
  -  let _memoized = React.useMemo1 (fun () -> value + 1) [||] in div[@@react.component
  +  let _memoized = React.useMemo1 (fun () -> value + 1) [| value |] in div[@@react.component

0 -> 1 deps: useEffect0 becomes useEffect1 with deps argument
  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~dep1 =
  >   React.useEffect0 (fun () -> Js.log dep1; None);
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect" | sed 's/  / /g; s/\[@@react.component$//'
  -let make ~dep1 = React.useEffect0 (fun () -> Js.log dep1; None); div
  +let make ~dep1 = React.useEffect1 (fun () -> Js.log dep1; None) [| dep1 |]; div

0 -> 1 deps: empty array becomes single-element array
  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~dep1 =
  >   React.useEffect1 (fun () -> Js.log dep1; None) [||];
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect" | sed 's/  / /g; s/\[@@react.component$//'
  -let make ~dep1 = React.useEffect1 (fun () -> Js.log dep1; None) [||]; div
  +let make ~dep1 = React.useEffect1 (fun () -> Js.log dep1; None) [| dep1 |]; div

1 -> 2 deps: useEffect1 renamed to useEffect2, array becomes tuple
  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~dep1 ~dep2 =
  >   React.useEffect1 (fun () -> Js.log dep1; Js.log dep2; None) [|dep1|];
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect1 (fun () -> Js.log dep1; Js.log dep2; None) [|dep1|]; div
  +  React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; None) (dep1, dep2); div

0 -> 2 deps: hook name stays the same, empty tuple becomes filled tuple
  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~dep1 ~dep2 =
  >   React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; None) ((), ());
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; None) ((), ()); div
  +  React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; None) (dep1, dep2); div

2 -> 3 deps: useEffect2 renamed to useEffect3
  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~dep1 ~dep2 ~dep3 =
  >   React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; Js.log dep3; None) (dep1, dep2);
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; Js.log dep3; None)
  +  React.useEffect3 (fun () -> Js.log dep1; Js.log dep2; Js.log dep3; None)
