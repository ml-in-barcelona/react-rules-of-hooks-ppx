Exhaustive-deps considers only the Client branch of switch%platform: deps
arrays only drive behavior in the client bundle.

An ident used in the Client branch is required; one used only in the Server
branch is not:

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~a ~b =
  >   React.useEffect1
  >     (fun () ->
  >       (match%platform Runtime.platform with
  >        | Server -> Js.log b
  >        | Client -> Js.log a);
  >       None)
  >     [||];
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'a' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~a ~b =
    React.useEffect1
      (fun () ->
         [%platform
           (match Runtime.platform with
            | Server -> Js.log b
            | Client -> Js.log a)];
         None) [||];
    div[@@react.component ]

With the Client-branch ident listed, no warning:

  $ cat > input2.ml << 'EOF'
  > let[@react.component] make ~a ~b =
  >   React.useEffect1
  >     (fun () ->
  >       (match%platform Runtime.platform with
  >        | Server -> Js.log b
  >        | Client -> Js.log a);
  >       None)
  >     [| a |];
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let make ~a ~b =
    React.useEffect1
      (fun () ->
         [%platform
           (match Runtime.platform with
            | Server -> Js.log b
            | Client -> Js.log a)];
         None) [|a|];
    div[@@react.component ]

A switch with no Client case contributes nothing:

  $ cat > input3.ml << 'EOF'
  > let[@react.component] make ~b =
  >   React.useEffect1
  >     (fun () ->
  >       (match%platform Runtime.platform with
  >        | Server -> Js.log b);
  >       None)
  >     [||];
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  let make ~b =
    React.useEffect1
      (fun () ->
         [%platform (match Runtime.platform with | Server -> Js.log b)]; None)
      [||];
    div[@@react.component ]

A useState setter bound through a %platform switch registers as a stable
dep (CustomizableNavigationBar shape):

  $ cat > input4.ml << 'EOF'
  > let[@react.component] make ~init =
  >   let v, setV =
  >     match%platform Runtime.platform with
  >     | Server -> (init, fun _ -> ())
  >     | Client -> React.useState (fun () -> init)
  >   in
  >   React.useEffect1 (fun () -> setV (fun _ -> v); None) [| v |];
  >   div
  > EOF

  $ ../src/standalone.exe input4.ml
  let make ~init =
    let (v, setV) =
      [%platform
        match Runtime.platform with
        | Server -> (init, ((fun _ -> ())))
        | Client -> React.useState (fun () -> init)] in
    React.useEffect1 (fun () -> setV (fun _ -> v); None) [|v|]; div[@@react.component
                                                                     ]
