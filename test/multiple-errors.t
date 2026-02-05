This test showcases that multiple errors can be reported at once
(instead of stopping at the first one when using raise_errorf)

  $ cat > input.mlx << 'EOF'
  > let useMouseHook () = ()
  > let useFoo () = ()
  > 
  > let[@react.component] make ~randomProp =
  >   if randomProp = "state" then useMouseHook ();
  >   if randomProp = "other" then useFoo ();
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let useMouseHook () = ()
  let useFoo () = ()
  let make ~randomProp  =
    if randomProp = "state" then useMouseHook ();
    if randomProp = "other" then useFoo ();
    div[@@react.component ]
