  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~items =
  >   for i = 0 to Array.length items - 1 do
  >     let _ = React.useState (fun () -> 0) in
  >     ()
  >   done;
  >   div
  > EOF

  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~items =
    for i = 0 to (Array.length items) - 1 do
      (let _ = React.useState (fun () -> 0) in ())
    done;
    div[@@react.component ]
