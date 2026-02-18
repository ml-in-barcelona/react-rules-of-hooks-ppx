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
