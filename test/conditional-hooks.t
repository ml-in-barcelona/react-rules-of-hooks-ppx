  $ cat > input.ml << 'EOF'
  > let useMouseHook () = ()
  > 
  > let[@react.component] make ~randomProp =
  >   if randomProp = "state" then useMouseHook ();
  >   div
  > EOF

  $ ../src/standalone.exe input.ml 2>&1 || true
  [%%ocaml.error "Hooks can't be called conditionally"]
  let useMouseHook () = ()
  let make ~randomProp = if randomProp = "state" then useMouseHook (); div
    [@@react.component ]
