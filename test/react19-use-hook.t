React 19 "use" hook should be detected as a hook

  $ cat > input.ml << 'EOF'
  > let result = use somePromise
  > EOF

"use" called outside component/custom hook should error
  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let result = use somePromise

"use" inside a component should be valid
  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~promise =
  >   let data = use promise in
  >   data
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let make ~promise = let data = use promise in data[@@react.component ]
