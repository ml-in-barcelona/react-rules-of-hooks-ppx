let%browser_only bindings whose bodies call hooks are custom hooks by
construction; hook-free bindings keep today's behavior.

Module-level hook wrapper with a non-use* name (SignupCheckout shape):

  $ cat > input.ml << 'EOF'
  > let useScript () = ignore (React.useState (fun () -> 0))
  > 
  > let%browser_only makeChargebee = fun () -> useScript ()
  > 
  > let[@react.component] make () =
  >   let instance = makeChargebee () in
  >   ignore instance;
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  let useScript () = ignore (React.useState (fun () -> 0))
  [%%browser_only let makeChargebee () = useScript ()]
  let make () = let instance = makeChargebee () in ignore instance; div
    [@@react.component ]

Expression-level hook wrapper inside a component:

  $ cat > input2.ml << 'EOF'
  > let useScript () = ignore (React.useState (fun () -> 0))
  > 
  > let[@react.component] make () =
  >   let%browser_only makeStripe = fun () -> useScript () in
  >   let stripe = makeStripe () in
  >   ignore stripe;
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let useScript () = ignore (React.useState (fun () -> 0))
  let make () =
    [%browser_only
      let makeStripe () = useScript () in
      let stripe = makeStripe () in ignore stripe; div][@@react.component ]

A use*-named wrapper is recognized through the extension node:

  $ cat > input3.ml << 'EOF'
  > let%browser_only useChargebee =
  >   fun () -> ignore (React.useState (fun () -> 0))
  > 
  > let[@react.component] make () =
  >   useChargebee ();
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  [%%browser_only let useChargebee () = ignore (React.useState (fun () -> 0))]
  let make () = useChargebee (); div[@@react.component ]

Hook-free bodies keep today's behavior: not hooks, may be called
conditionally. rec bindings and hook-ident aliases are handled:

  $ cat > input4.ml << 'EOF'
  > let%browser_only getHeight = fun () -> 42
  > 
  > let%browser_only rec pump = fun n -> if n > 0 then pump (n - 1) else ()
  > 
  > let%browser_only use = ReasonReactRouter.useUrl
  > 
  > let[@react.component] make ~cond =
  >   let _s = React.useState (fun () -> 0) in
  >   let h = if cond then getHeight () else 0 in
  >   h
  > EOF

  $ ../src/standalone.exe input4.ml
  [%%browser_only let getHeight () = 42]
  [%%browser_only let rec pump n = if n > 0 then pump (n - 1) else ()]
  [%%browser_only let use = ReasonReactRouter.useUrl]
  let make ~cond =
    let _s = React.useState (fun () -> 0) in
    let h = if cond then getHeight () else 0 in h[@@react.component ]
