Test that the [@disable_order_of_hooks] attribute disables order of hooks checking

  $ cat > input.mlx << 'EOF'
  > let useMouseHook () = ()
  > 
  > let[@react.component] make ~randomProp =
  >   if randomProp = "state" then (useMouseHook ())[@disable_order_of_hooks];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let useMouseHook () = ()
  let make ~randomProp =
    if randomProp = "state" then ((useMouseHook ())[@disable_order_of_hooks ]);
    div[@@react.component ]

Test that hook outside component can be disabled with attribute:

  $ cat > input2.mlx << 'EOF'
  > let make () =
  >   let show, _setShow = (React.useState (fun () -> "sTatE"))[@disable_order_of_hooks] in
  >   print_endline show
  > EOF

  $ mlx-pp -print-ml input2.mlx > input2.ml

  $ ../src/standalone.exe input2.ml
  let make () =
    let (show, _setShow) = ((React.useState (fun () -> "sTatE"))
      [@disable_order_of_hooks ]) in
    print_endline show

Test that without the attribute, the error still appears:

  $ cat > input3.mlx << 'EOF'
  > let useMouseHook () = ()
  > 
  > let[@react.component] make ~randomProp =
  >   if randomProp = "state" then useMouseHook ();
  >   div
  > EOF

  $ mlx-pp -print-ml input3.mlx > input3.ml

  $ ../src/standalone.exe input3.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let useMouseHook () = ()
  let make ~randomProp = if randomProp = "state" then useMouseHook (); div
    [@@react.component ]

Test that the attribute works in switch/match expressions:

  $ cat > input4.ml << 'EOF'
  > let useMouseHook () = ()
  > let useKeyboardHook () = ()
  > 
  > let make ~inputType =
  >   (match inputType with
  >   | "mouse" -> (useMouseHook ())[@disable_order_of_hooks]
  >   | "keyboard" -> (useKeyboardHook ())[@disable_order_of_hooks]
  >   | _ -> ());
  >   ()
  >   [@@react.component]
  > EOF

  $ ../src/standalone.exe input4.ml
  let useMouseHook () = ()
  let useKeyboardHook () = ()
  let make ~inputType =
    (match inputType with
     | "mouse" -> ((useMouseHook ())[@disable_order_of_hooks ])
     | "keyboard" -> ((useKeyboardHook ())[@disable_order_of_hooks ])
     | _ -> ());
    ()[@@react.component ]

Test that without the attribute in switch, the error appears:

  $ cat > input5.ml << 'EOF'
  > let useMouseHook () = ()
  > 
  > let make ~inputType =
  >   (match inputType with
  >   | "mouse" -> useMouseHook ()
  >   | _ -> ());
  >   ()
  >   [@@react.component]
  > EOF

  $ ../src/standalone.exe input5.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let useMouseHook () = ()
  let make ~inputType =
    (match inputType with | "mouse" -> useMouseHook () | _ -> ()); ()[@@react.component
                                                                      ]
