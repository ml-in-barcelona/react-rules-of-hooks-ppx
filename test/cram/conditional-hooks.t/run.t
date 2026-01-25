  $ ../../../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error "Hooks can't be called conditionally"]
  let useMouseHook () = ()
  let make ~randomProp =
    if randomProp = "state" then ((useMouseHook ())[@reason.preserve_braces ]);
    div[@@react.component ]
