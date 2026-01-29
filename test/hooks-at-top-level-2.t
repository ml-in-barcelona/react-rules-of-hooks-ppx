  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let state, setState = React.useState () in
  >   <div onClick=(fun _evt -> useMouseHook ()) />
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make () =
    let (state, setState) = React.useState () in
    ((div () ~children:[] ~onClick:(fun _evt -> useMouseHook ()))[@JSX ])
    [@@react.component ]
