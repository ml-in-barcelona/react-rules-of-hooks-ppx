switch%platform / match%platform branches are resolved at compile time (one
branch per build target), so hooks inside them are not conditional.

Hooks in the Client branch of a custom hook (UseMediaScreen shape):

  $ cat > input.ml << 'EOF'
  > let use () =
  >   match%platform Runtime.platform with
  >   | Server -> Screen.desktop
  >   | Client ->
  >       let media, _setMedia = React.useState (fun () -> getMedia ()) in
  >       React.useEffect0 (fun () -> None);
  >       media
  > EOF

  $ ../src/standalone.exe input.ml
  let use () =
    [%platform
      match Runtime.platform with
      | Server -> Screen.desktop
      | Client ->
          let (media, _setMedia) = React.useState (fun () -> getMedia ()) in
          (React.useEffect0 (fun () -> None); media)]

A hook in the Server branch is legal too (MainMenu shape):

  $ cat > input2.ml << 'EOF'
  > let[@react.component] make ~onOutsideClick =
  >   let modalRef =
  >     match%platform Runtime.platform with
  >     | Server -> React.useRef Js.Nullable.null
  >     | Client -> UseOutsideClick.use onOutsideClick
  >   in
  >   ignore modalRef;
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let make ~onOutsideClick =
    let modalRef =
      [%platform
        match Runtime.platform with
        | Server -> React.useRef Js.Nullable.null
        | Client -> UseOutsideClick.use onOutsideClick] in
    ignore modalRef; div[@@react.component ]

Hook call as the whole branch expression, tuple-destructured
(CustomizableNavigationBar shape):

  $ cat > input3.ml << 'EOF'
  > let[@react.component] make () =
  >   let state, setState =
  >     match%platform Runtime.platform with
  >     | Client -> React.useState (fun () -> 0)
  >     | Server -> (0, fun _ -> ())
  >   in
  >   ignore setState;
  >   state
  > EOF

  $ ../src/standalone.exe input3.ml
  let make () =
    let (state, setState) =
      [%platform
        match Runtime.platform with
        | Client -> React.useState (fun () -> 0)
        | Server -> (0, ((fun _ -> ())))] in
    ignore setState; state[@@react.component ]

Unconditional hooks before and after the switch in the same component
(Header shape), plus a structure-level bare switch%platform (Toast shape):

  $ cat > input4.ml << 'EOF'
  > let () =
  >   match%platform Runtime.platform with
  >   | Client -> print_endline "client"
  >   | Server -> ()
  > 
  > let[@react.component] make ~isHomePage =
  >   let scroll = React.useState (fun () -> 0) in
  >   let offset =
  >     match%platform Runtime.platform with
  >     | Server -> 0
  >     | Client -> UseScroll.use isHomePage
  >   in
  >   let memo = React.useMemo1 (fun () -> offset) [| offset |] in
  >   ignore scroll;
  >   memo
  > EOF

  $ ../src/standalone.exe input4.ml
  let () =
    [%platform
      match Runtime.platform with
      | Client -> print_endline "client"
      | Server -> ()]
  let make ~isHomePage =
    let scroll = React.useState (fun () -> 0) in
    let offset =
      [%platform
        match Runtime.platform with
        | Server -> 0
        | Client -> UseScroll.use isHomePage] in
    let memo = React.useMemo1 (fun () -> offset) [|offset|] in
    ignore scroll; memo[@@react.component ]
