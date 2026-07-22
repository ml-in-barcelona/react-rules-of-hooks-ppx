Test that the -disable-order-of-hooks flag disables order of hooks checking

  $ cat > input.mlx << 'EOF'
  > let useMouseHook () = ()
  > 
  > let[@react.component] make ~randomProp =
  >   if randomProp = "state" then useMouseHook ();
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Without the flag, the conditional hooks error should appear:

  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let useMouseHook () = ()
  let make ~randomProp = if randomProp = "state" then useMouseHook (); div
    [@@react.component ]

With the -disable-order-of-hooks flag, no error should appear:

  $ ../src/standalone.exe -disable-order-of-hooks input.ml 2>&1 || true
  let useMouseHook () = ()
  let make ~randomProp = if randomProp = "state" then useMouseHook (); div
    [@@react.component ]

The flag must not degrade exhaustive-deps: scope tracking still runs, so a
missing dependency is still reported.

  $ cat > deps.mlx << 'EOF'
  > let[@react.component] make ~randomProp:(_ : string) =
  >   let show, _setShow = React.useState (fun () -> "sTatE") in
  >   React.useEffect1
  >     (fun () -> Js.log randomProp; None)
  >     [|show|];
  >   div
  > EOF

  $ mlx-pp -print-ml deps.mlx > deps.ml

  $ ../src/standalone.exe -disable-order-of-hooks deps.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'randomProp' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~randomProp:(_ : string) =
    let (show, _setShow) = React.useState (fun () -> "sTatE") in
    React.useEffect1 (fun () -> Js.log randomProp; None) [|show|]; div[@@react.component
                                                                      ]
