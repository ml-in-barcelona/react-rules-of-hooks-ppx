A use*-named binding whose body (through the fun chain) is directly an
application of a known-stable hook inherits its stability shape. This layer
is sound: it reads the definition, so conventions don't matter.

A same-file use* wrapper around useReducer is inferred as stable, even when
the setter name does NOT follow the convention:

  $ cat > input.ml << 'EOF'
  > let useStateValue initial = React.useReducer (fun _ next -> next) initial
  > 
  > let[@react.component] make () =
  >   let value, update = useStateValue 0 in
  >   React.useEffect0 (fun () -> update 1; None);
  >   Js.log value;
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  let useStateValue initial = React.useReducer (fun _ next -> next) initial
  let make () =
    let (value, update) = useStateValue 0 in
    React.useEffect0 (fun () -> update 1; None); Js.log value; div[@@react.component
                                                                    ]

Chained wrappers resolve transitively:

  $ cat > input2.ml << 'EOF'
  > let useStateValue initial = React.useReducer (fun _ next -> next) initial
  > let useCounter () = useStateValue 0
  > 
  > let[@react.component] make () =
  >   let _n, bump = useCounter () in
  >   React.useEffect0 (fun () -> bump 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let useStateValue initial = React.useReducer (fun _ next -> next) initial
  let useCounter () = useStateValue 0
  let make () =
    let (_n, bump) = useCounter () in
    React.useEffect0 (fun () -> bump 1; None); div[@@react.component ]

A useRef wrapper marks the whole binding stable:

  $ cat > input3.ml << 'EOF'
  > let useMyRef initial = React.useRef initial
  > 
  > let[@react.component] make () =
  >   let r = useMyRef 0 in
  >   React.useEffect0 (fun () -> r.current <- 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  let useMyRef initial = React.useRef initial
  let make () =
    let r = useMyRef 0 in
    React.useEffect0 (fun () -> r.current <- 1; None); div[@@react.component ]

A wrapper whose body is NOT directly a stable hook application is not
inferred; a non-conventional name in snd position stays checked:

  $ cat > input4.ml << 'EOF'
  > let useWeird () =
  >   let v, s = React.useState (fun () -> 0) in
  >   (v, (fun x -> s (fun _ -> x)))
  > 
  > let[@react.component] make () =
  >   let _v, apply = useWeird () in
  >   React.useEffect0 (fun () -> apply 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input4.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'apply' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let useWeird () =
    let (v, s) = React.useState (fun () -> 0) in (v, (fun x -> s (fun _ -> x)))
  let make () =
    let (_v, apply) = useWeird () in
    React.useEffect0 (fun () -> apply 1; None); div[@@react.component ]

A plain rebinding of the wrapper name drops the inference:

  $ cat > input5.ml << 'EOF'
  > let useStateValue initial = React.useReducer (fun _ next -> next) initial
  > let useStateValue x = SomeOther.thing x
  > 
  > let[@react.component] make () =
  >   let _v, update = useStateValue 0 in
  >   React.useEffect0 (fun () -> update 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input5.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'update' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let useStateValue initial = React.useReducer (fun _ next -> next) initial
  let useStateValue x = SomeOther.thing x
  let make () =
    let (_v, update) = useStateValue 0 in
    React.useEffect0 (fun () -> update 1; None); div[@@react.component ]

A wrapper defined inside a component or custom hook does not leak to the
rest of the file (a later same-named call cannot refer to it):

  $ cat > input6.ml << 'IN'
  > let useHelper () =
  >   let useStateValue initial = React.useReducer (fun _ next -> next) initial in
  >   useStateValue 0
  > 
  > let[@react.component] make () =
  >   let _v, update = useStateValue 0 in
  >   React.useEffect0 (fun () -> update 1; None);
  >   div
  > IN

  $ ../src/standalone.exe input6.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'update' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let useHelper () =
    let useStateValue initial = React.useReducer (fun _ next -> next) initial in
    useStateValue 0
  let make () =
    let (_v, update) = useStateValue 0 in
    React.useEffect0 (fun () -> update 1; None); div[@@react.component ]

function-syntax wrappers (single case) are inferred like fun-syntax ones:

  $ cat > input7.ml << 'IN'
  > let useStateValue = function
  >   | initial -> React.useReducer (fun _ next -> next) initial
  > 
  > let[@react.component] make () =
  >   let _v, update = useStateValue 0 in
  >   React.useEffect0 (fun () -> update 1; None);
  >   div
  > IN

  $ ../src/standalone.exe input7.ml
  let useStateValue =
    function | initial -> React.useReducer (fun _ next -> next) initial
  let make () =
    let (_v, update) = useStateValue 0 in
    React.useEffect0 (fun () -> update 1; None); div[@@react.component ]
