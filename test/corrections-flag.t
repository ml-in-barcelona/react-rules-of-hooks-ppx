  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~value =
  >   let _memoized = React.useMemo1 (fun () -> value + 1) [||] in
  >   div
  > EOF

Without the -corrections flag, only the warning should appear (no diff):
  $ ../src/standalone.exe input.ml 2>&1 || true
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing 'value' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value =
    let _memoized = React.useMemo1 (fun () -> value + 1) [||] in div[@@react.component
                                                                      ]

With the -corrections flag, the diff should appear with properly formatted deps array:
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*\[" | head -2
  -  let _memoized = React.useMemo1 (fun () -> value + 1) [||] in
  +  let _memoized = React.useMemo1 (fun () -> value + 1) [| value |] in

0 -> 1 deps: useEffect0 becomes useEffect1 with deps argument
  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~dep1 =
  >   React.useEffect0 (fun () -> Js.log dep1; None);
  >   div
  > EOF
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect0 (fun () -> Js.log dep1; None);
  +  React.useEffect1 (fun () -> Js.log dep1; None) [| dep1 |];

0 -> 1 deps: empty array becomes single-element array
  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~dep1 =
  >   React.useEffect1 (fun () -> Js.log dep1; None) [||];
  >   div
  > EOF
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect1 (fun () -> Js.log dep1; None) [||];
  +  React.useEffect1 (fun () -> Js.log dep1; None) [| dep1 |];

1 -> 2 deps: useEffect1 renamed to useEffect2, array becomes tuple
  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~dep1 ~dep2 =
  >   React.useEffect1 (fun () -> Js.log dep1; Js.log dep2; None) [|dep1|];
  >   div
  > EOF
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect1 (fun () -> Js.log dep1; Js.log dep2; None) [|dep1|];
  +  React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; None) (dep1, dep2);

0 -> 2 deps: hook name stays the same, empty tuple becomes filled tuple
  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~dep1 ~dep2 =
  >   React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; None) ((), ());
  >   div
  > EOF
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; None) ((), ());
  +  React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; None) (dep1, dep2);

2 -> 3 deps: useEffect2 renamed to useEffect3
  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~dep1 ~dep2 ~dep3 =
  >   React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; Js.log dep3; None) (dep1, dep2);
  >   div
  > EOF
  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect2 (fun () -> Js.log dep1; Js.log dep2; Js.log dep3; None) (dep1, dep2);
  +  React.useEffect3 (fun () -> Js.log dep1; Js.log dep2; Js.log dep3; None) (dep1, dep2, dep3);
