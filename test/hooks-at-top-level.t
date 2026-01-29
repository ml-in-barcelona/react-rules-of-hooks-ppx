  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   <div onClick=(fun _evt -> useMouseHook ()) />
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make () = ((div () ~children:[] ~onClick:(fun _evt -> useMouseHook ()))
    [@JSX ])[@@react.component ]
