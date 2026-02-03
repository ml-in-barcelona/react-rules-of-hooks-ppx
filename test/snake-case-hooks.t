Snake case hooks (use_*) should be recognized as hooks

use_state outside component should error
  $ cat > input.ml << 'EOF'
  > let result = use_state (fun () -> 0)
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let result = use_state (fun () -> 0)

use_state inside component should be valid
  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   let state, _set_state = use_state (fun () -> 0) in
  >   state
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let make () = let (state, _set_state) = use_state (fun () -> 0) in state
    [@@react.component ]

Custom snake_case hook definition should be valid
  $ cat > input.ml << 'EOF'
  > let use_custom_hook () =
  >   let state, set_state = React.useState (fun () -> 0) in
  >   (state, set_state)
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let use_custom_hook () =
    let (state, set_state) = React.useState (fun () -> 0) in (state, set_state)
