  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   let state, setState = React.useState () in
  >   (div ~onClick:(fun _evt -> useMouseHook ()) ())[@JSX]
  > EOF

  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error "Hooks can't be called conditionally"]
  let make () =
    let (state, setState) = React.useState () in
    ((div ~onClick:(fun _evt -> useMouseHook ()) ())[@JSX ])[@@react.component
                                                              ]
