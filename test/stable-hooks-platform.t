Stable-hook detection composes with the switch%platform support: both layers
sit behind the Client-branch unwrap.

A convention-named setter bound through a switch%platform Client branch is
exempt (extends platform-switch-deps.t case 4, which pins the builtin
useState path):

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~init =
  >   let _v, setV =
  >     match%platform Runtime.platform with
  >     | Server -> (init, fun _ -> ())
  >     | Client -> RR.useStateValue init
  >   in
  >   React.useEffect0 (fun () -> setV 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  let make ~init =
    let (_v, setV) =
      [%platform
        match Runtime.platform with
        | Server -> (init, ((fun _ -> ())))
        | Client -> RR.useStateValue init] in
    React.useEffect0 (fun () -> setV 1; None); div[@@react.component ]

A same-file wrapper defined per target via switch%platform infers from the
Client branch (Layer 1):

  $ cat > input2.ml << 'EOF'
  > let useStateValue =
  >   match%platform () with
  >   | Server -> (fun initial -> (initial, fun _ -> ()))
  >   | Client -> (fun initial -> React.useReducer (fun _ next -> next) initial)
  > 
  > let[@react.component] make () =
  >   let _v, update = useStateValue 0 in
  >   React.useEffect0 (fun () -> update 1; None);
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let useStateValue =
    [%platform
      match () with
      | Server -> (fun initial -> (initial, (fun _ -> ())))
      | Client ->
          (fun initial -> React.useReducer (fun _ next -> next) initial)]
  let make () =
    let (_v, update) = useStateValue 0 in
    React.useEffect0 (fun () -> update 1; None); div[@@react.component ]
