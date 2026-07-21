Calls to tracked let%browser_only hook wrappers are linted exactly like hook
calls.

A conditional call to a hook wrapper is a hard error:

  $ cat > input.ml << 'EOF'
  > let useScript () = ignore (React.useState (fun () -> 0))
  > 
  > let%browser_only makeChargebee = fun () -> useScript ()
  > 
  > let[@react.component] make ~cond =
  >   let c = if cond then Some (makeChargebee ()) else None in
  >   ignore c;
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let useScript () = ignore (React.useState (fun () -> 0))
  [%%browser_only let makeChargebee () = useScript ()]
  let make ~cond =
    let c = if cond then Some (makeChargebee ()) else None in ignore c; div
    [@@react.component ]

Same for the expression-level form:

  $ cat > input2.ml << 'EOF'
  > let useScript () = ignore (React.useState (fun () -> 0))
  > 
  > let[@react.component] make ~cond =
  >   let%browser_only makeStripe = fun () -> useScript () in
  >   let s = if cond then Some (makeStripe ()) else None in
  >   ignore s;
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let useScript () = ignore (React.useState (fun () -> 0))
  let make ~cond =
    [%browser_only
      let makeStripe () = useScript () in
      let s = if cond then Some (makeStripe ()) else None in ignore s; div]
    [@@react.component ]

A call outside any component or custom hook gets the same lint as a hook:

  $ cat > input3.ml << 'EOF'
  > let useScript () = ignore (React.useState (fun () -> 0))
  > 
  > let%browser_only makeChargebee = fun () -> useScript ()
  > 
  > let _instance = makeChargebee ()
  > EOF

  $ ../src/standalone.exe input3.ml
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let useScript () = ignore (React.useState (fun () -> 0))
  [%%browser_only let makeChargebee () = useScript ()]
  let _instance = makeChargebee ()

A plain rebinding shadows the tracked name: no error afterwards:

  $ cat > input4.ml << 'EOF'
  > let useScript () = ignore (React.useState (fun () -> 0))
  > 
  > let%browser_only makeThing = fun () -> useScript ()
  > 
  > let makeThing () = 42
  > 
  > let[@react.component] make ~cond =
  >   let v = if cond then makeThing () else 0 in
  >   v
  > EOF

  $ ../src/standalone.exe input4.ml
  let useScript () = ignore (React.useState (fun () -> 0))
  [%%browser_only let makeThing () = useScript ()]
  let makeThing () = 42
  let make ~cond = let v = if cond then makeThing () else 0 in v[@@react.component
                                                                  ]

Conditional calls to hook-free %browser_only utilities stay legal:

  $ cat > input5.ml << 'EOF'
  > let%browser_only getHeight = fun () -> 42
  > 
  > let[@react.component] make ~cond =
  >   ignore (React.useState (fun () -> 0));
  >   (if cond then ignore (getHeight ()));
  >   div
  > EOF

  $ ../src/standalone.exe input5.ml
  [%%browser_only let getHeight () = 42]
  let make ~cond =
    ignore (React.useState (fun () -> 0));
    if cond then ignore (getHeight ());
    div[@@react.component ]
