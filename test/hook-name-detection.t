Hook name detection patterns - comprehensive tests

=== VALID HOOK PATTERNS ===

1. "use" exactly (React 19 use hook)
  $ cat > input.ml << 'EOF'
  > let result = use somePromise
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let result = use somePromise

2. "use[A-Z]..." camelCase hooks (useState, useEffect, useCustomHook)
  $ cat > input.ml << 'EOF'
  > let _ = useState (fun () -> 0)
  > let _ = useEffect (fun () -> None)
  > let _ = useCustomHook ()
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let _ = useState (fun () -> 0)
  let _ = useEffect (fun () -> None)
  let _ = useCustomHook ()

3. "use_..." snake_case hooks (use_state, use_effect, use_custom_hook)
  $ cat > input.ml << 'EOF'
  > let _ = use_state (fun () -> 0)
  > let _ = use_effect (fun () -> None)
  > let _ = use_custom_hook ()
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let _ = use_state (fun () -> 0)
  let _ = use_effect (fun () -> None)
  let _ = use_custom_hook ()

=== INVALID HOOK PATTERNS (should NOT be detected as hooks) ===

4. "user", "used", "uses" - words starting with "use" but not hooks
  $ cat > input.ml << 'EOF'
  > let _ = user ()
  > let _ = used ()
  > let _ = uses ()
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let _ = user ()
  let _ = used ()
  let _ = uses ()

5. "useless", "useful" - longer words starting with "use" but no uppercase/underscore at position 4
  $ cat > input.ml << 'EOF'
  > let _ = useless ()
  > let _ = useful ()
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let _ = useless ()
  let _ = useful ()

6. "_useHook" - underscore prefix means not a hook
  $ cat > input.ml << 'EOF'
  > let _ = _useHook ()
  > let _ = _use_hook ()
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let _ = _useHook ()
  let _ = _use_hook ()

7. JSX elements named "use" (SVG <use>) - excluded via [@JSX] attribute
  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   (use () ~children:[] ~href:"#icon")[@JSX]
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let make () = ((use () ~children:[] ~href:"#icon")[@JSX ])[@@react.component
                                                              ]

=== VALID HOOK DEFINITIONS ===

8. Custom hook definitions (camelCase)
  $ cat > input.ml << 'EOF'
  > let useCustomHook () =
  >   let state, setState = React.useState (fun () -> 0) in
  >   (state, setState)
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let useCustomHook () =
    let (state, setState) = React.useState (fun () -> 0) in (state, setState)

9. Custom hook definitions (snake_case)
  $ cat > input.ml << 'EOF'
  > let use_custom_hook () =
  >   let state, set_state = React.useState (fun () -> 0) in
  >   (state, set_state)
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let use_custom_hook () =
    let (state, set_state) = React.useState (fun () -> 0) in (state, set_state)
