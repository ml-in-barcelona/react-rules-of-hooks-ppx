Test that the -disable-order-of-hooks flag disables order of hooks checking

  $ cat > input.ml << 'EOF'
  > let useMouseHook () = ()
  > 
  > let[@react.component] make ~randomProp =
  >   if randomProp = "state" then ((useMouseHook ())[@reason.preserve_braces ]);
  >   div
  > EOF

Without the flag, the conditional hooks error should appear:

  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let useMouseHook () = ()
  let make ~randomProp =
    if randomProp = "state" then ((useMouseHook ())[@reason.preserve_braces ]);
    div[@@react.component ]

With the -disable-order-of-hooks flag, no error should appear:

  $ ../src/standalone.exe -disable-order-of-hooks input.ml 2>&1 || true
  let useMouseHook () = ()
  let make ~randomProp =
    if randomProp = "state" then ((useMouseHook ())[@reason.preserve_braces ]);
    div[@@react.component ]
