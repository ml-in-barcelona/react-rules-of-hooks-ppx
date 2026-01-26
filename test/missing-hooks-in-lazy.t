  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   let _ = lazy (React.useState (fun () -> 0)) in
  >   div
  > EOF

Hooks inside lazy expressions should be detected (deferred execution)
  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component. Move this hook call outside of conditionals, loops, or nested functions."]
  let make () = let _ = lazy (React.useState (fun () -> 0)) in div[@@react.component
                                                                    ]
