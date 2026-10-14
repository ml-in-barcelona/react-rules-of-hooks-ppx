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
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
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
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let useMouseHook () = ()
  let make ~inputType =
    (match inputType with | "mouse" -> useMouseHook () | _ -> ()); ()[@@react.component
                                                                      ]

Test that the attribute on a let binding disables order checks for the hooks in that binding:

  $ cat > input6.mlx << 'EOF'
  > let make () =
  >   let [@disable_order_of_hooks] show, _setShow = React.useState (fun () -> "sTatE") in
  >   print_endline show
  > EOF

  $ mlx-pp -print-ml input6.mlx > input6.ml

  $ ../src/standalone.exe input6.ml
  let make () =
    let (show, _setShow) = React.useState (fun () -> "sTatE")[@@disable_order_of_hooks
                                                               ] in
    print_endline show

Test that the binding attribute covers conditional hook calls inside the binding:

  $ cat > input7.mlx << 'EOF'
  > let useMouseHook () = ()
  > 
  > let[@react.component] make ~randomProp =
  >   let[@disable_order_of_hooks] () = if randomProp = "state" then useMouseHook () in
  >   div
  > EOF

  $ mlx-pp -print-ml input7.mlx > input7.ml

  $ ../src/standalone.exe input7.ml
  let useMouseHook () = ()
  let make ~randomProp =
    let () = if randomProp = "state" then useMouseHook ()[@@disable_order_of_hooks
                                                           ] in
    div[@@react.component ]

Test that the binding attribute does not leak to the next binding:

  $ cat > input8.mlx << 'EOF'
  > let useMouseHook () = ()
  > 
  > let[@react.component] make ~randomProp =
  >   let[@disable_order_of_hooks] () = if randomProp = "state" then useMouseHook () in
  >   let () = if randomProp = "other" then useMouseHook () in
  >   div
  > EOF

  $ mlx-pp -print-ml input8.mlx > input8.ml

  $ ../src/standalone.exe input8.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let useMouseHook () = ()
  let make ~randomProp =
    let () = if randomProp = "state" then useMouseHook ()[@@disable_order_of_hooks
                                                           ] in
    let () = if randomProp = "other" then useMouseHook () in div[@@react.component
                                                                  ]

Test that the attribute on both the binding and the hook call is accepted without a warning:

  $ cat > input9.mlx << 'EOF'
  > let useMouseHook () = ()
  > 
  > let[@react.component] make ~randomProp =
  >   let[@disable_order_of_hooks] () = if randomProp = "state" then (useMouseHook ())[@disable_order_of_hooks] in
  >   div
  > EOF

  $ mlx-pp -print-ml input9.mlx > input9.ml

  $ ../src/standalone.exe input9.ml
  let useMouseHook () = ()
  let make ~randomProp =
    let () =
      if randomProp = "state"
      then ((useMouseHook ())[@disable_order_of_hooks ])[@@disable_order_of_hooks
                                                          ] in
    div[@@react.component ]
