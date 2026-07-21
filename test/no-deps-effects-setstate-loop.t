A DIRECT setter call in a no-deps effect re-renders, re-runs the effect, and
loops forever (eslint's infinite-loop guard).

  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   let _state, setState = React.useState (fun () -> 0) in
  >   React.useEffect (fun () -> setState (fun _ -> 1); None);
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: This effect contains a call to 'setState'. Without a dependency array, this can lead to an infinite chain of updates. Use React.useEffect0 or add a dependency array."]
  let make () =
    let (_state, setState) = React.useState (fun () -> 0) in
    React.useEffect (fun () -> setState (fun _ -> 1); None); div[@@react.component
                                                                  ]

Setters from custom hooks (stable-hook detection) count too:

  $ cat > input2.ml << 'EOF'
  > let useStateValue initial = React.useReducer (fun _ next -> next) initial
  > 
  > let[@react.component] make () =
  >   let _v, update = useStateValue 0 in
  >   React.useEffect (fun () -> update 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: This effect contains a call to 'update'. Without a dependency array, this can lead to an infinite chain of updates. Use React.useEffect0 or add a dependency array."]
  let useStateValue initial = React.useReducer (fun _ next -> next) initial
  let make () =
    let (_v, update) = useStateValue 0 in
    React.useEffect (fun () -> update 1; None); div[@@react.component ]

The suppression attribute still works on the call:

  $ cat > input3.ml << 'EOF'
  > let[@react.component] make () =
  >   let _state, setState = React.useState (fun () -> 0) in
  >   (React.useEffect (fun () -> setState (fun _ -> 1); None))
  >   [@disable_exhaustive_deps];
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  let make () =
    let (_state, setState) = React.useState (fun () -> 0) in
    ((React.useEffect (fun () -> setState (fun _ -> 1); None))
    [@disable_exhaustive_deps ]);
    div[@@react.component ]
