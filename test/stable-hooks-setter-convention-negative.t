The setter-convention gates: only destructured hook results with
conventionally named elements are exempted.

Second element NOT named like a setter is still checked:

  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   let _value, callback = SomeHook.use () in
  >   React.useEffect0 (fun () -> callback (); None);
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'callback' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let (_value, callback) = SomeHook.use () in
    React.useEffect0 (fun () -> callback (); None); div[@@react.component ]

A set*-named plain closure (not a hook result) is still checked:

  $ cat > input2.ml << 'EOF'
  > let[@react.component] make () =
  >   let setLocal = fun x -> Js.log x in
  >   ignore (React.useState (fun () -> 0));
  >   React.useEffect0 (fun () -> setLocal 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'setLocal' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let setLocal x = Js.log x in
    ignore (React.useState (fun () -> 0));
    React.useEffect0 (fun () -> setLocal 1; None);
    div[@@react.component ]

Whole-return binding (not a destructure) is still checked, even if
set*-named:

  $ cat > input3.ml << 'EOF'
  > let[@react.component] make () =
  >   let setAll = Hooks.useSetter () in
  >   React.useEffect0 (fun () -> setAll 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'setAll' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let setAll = Hooks.useSetter () in
    React.useEffect0 (fun () -> setAll 1; None); div[@@react.component ]

A set-prefixed word that is not the convention (settings) is still checked:

  $ cat > input4.ml << 'EOF'
  > let[@react.component] make () =
  >   let _v, settings = SomeHook.use () in
  >   React.useEffect0 (fun () -> settings (); None);
  >   div
  > EOF

  $ ../src/standalone.exe input4.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'settings' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let (_v, settings) = SomeHook.use () in
    React.useEffect0 (fun () -> settings (); None); div[@@react.component ]

First tuple element is never exempted, even if setter-named:

  $ cat > input5.ml << 'EOF'
  > let[@react.component] make () =
  >   let setFirst, _v = SomeHook.use () in
  >   React.useEffect0 (fun () -> setFirst 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input5.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'setFirst' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let (setFirst, _v) = SomeHook.use () in
    React.useEffect0 (fun () -> setFirst 1; None); div[@@react.component ]
