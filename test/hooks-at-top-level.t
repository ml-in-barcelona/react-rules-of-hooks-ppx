  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   (div ~onClick:(fun _evt -> useMouseHook ()) ())[@JSX]
  > EOF

  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error "Hooks can't be called conditionally"]
  let make () = ((div ~onClick:(fun _evt -> useMouseHook ()) ())[@JSX ])
    [@@react.component ]
