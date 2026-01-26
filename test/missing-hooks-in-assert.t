  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   assert (let _ = React.useState (fun () -> 0) in true);
  >   div
  > EOF

Hooks inside assert should be detected
  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make () = assert ((let _ = React.useState (fun () -> 0) in true)); div
    [@@react.component ]
