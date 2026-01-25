  $ ../../../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error "Hooks can't be called conditionally"]
  let make () =
    ((div ~onClick:((fun _evt -> useMouseHook ())[@reason.preserve_braces ]) ())
    [@JSX ])[@@react.component ]
