Dependencies used in cleanup function should be tracked
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  let make ~handler =
    [%ocaml.error "ExhaustiveDeps: Missing 'handler' in the dependency array"];
    div[@@react.component ]
