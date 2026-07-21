When destructuring the result of any hook call, an element named like a
setter (set[A-Z]..., set_..., dispatch...) is treated as stable.

Setter from an external custom hook is exempt; real missing deps still
flagged:

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~title =
  >   let _isHydrated, setIsHydrated = RR.useStateValue false in
  >   React.useEffect0 (fun () -> setIsHydrated true; Js.log title; None);
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'title' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~title =
    let (_isHydrated, setIsHydrated) = RR.useStateValue false in
    React.useEffect0 (fun () -> setIsHydrated true; Js.log title; None); div
    [@@react.component ]

dispatch from a custom reducer hook is exempt:

  $ cat > input2.ml << 'EOF'
  > let[@react.component] make () =
  >   let _state, dispatch = Store.useStore init in
  >   React.useEffect0 (fun () -> dispatch Init; None);
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let make () =
    let (_state, dispatch) = Store.useStore init in
    React.useEffect0 (fun () -> dispatch Init; None); div[@@react.component ]

snake_case setters follow the same convention (the ppx accepts snake_case
hooks since 1.1.0):

  $ cat > input3.ml << 'EOF'
  > let[@react.component] make () =
  >   let _value, set_value = Store.use_store () in
  >   React.useEffect0 (fun () -> set_value 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  let make () =
    let (_value, set_value) = Store.use_store () in
    React.useEffect0 (fun () -> set_value 1; None); div[@@react.component ]

Record destructure: setter-named fields exempt, others still required:

  $ cat > input4.ml << 'EOF'
  > let[@react.component] make () =
  >   let { setSelected; clearAll } = Hooks.useSelectableRows () in
  >   React.useEffect0 (fun () -> setSelected 1; clearAll (); None);
  >   div
  > EOF

  $ ../src/standalone.exe input4.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'clearAll' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    let { setSelected; clearAll } = Hooks.useSelectableRows () in
    React.useEffect0 (fun () -> setSelected 1; clearAll (); None); div[@@react.component
                                                                      ]
