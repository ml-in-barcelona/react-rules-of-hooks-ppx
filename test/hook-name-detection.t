Hook name detection patterns 

  $ cat > input.ml << 'EOF'
  > let result = use somePromise
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "React hooks can only be called from [@react.component] functions or custom hooks."]
  let result = use somePromise

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

4. "user", "used", "uses" - words starting with "use" but not hooks
  $ cat > input.ml << 'EOF'
  > let _ = user ()
  > let _ = used ()
  > let _ = uses ()
  > let _ = useless ()
  > let _ = useful ()
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let _ = user ()
  let _ = used ()
  let _ = uses ()
  let _ = useless ()
  let _ = useful ()

"_useHook" - underscore prefix means not a hook
  $ cat > input.ml << 'EOF'
  > let _ = _useHook ()
  > let _ = _use_hook ()
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let _ = _useHook ()
  let _ = _use_hook ()

JSX elements named "use" (SVG <use>)
  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   <use href="#icon" />
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml 2>&1
  let make () = ((use () ~children:[] ~href:"#icon")[@JSX ])[@@react.component
                                                              ]

Custom hook with camelCase name
  $ cat > input.ml << 'EOF'
  > let useCustomHook () =
  >   let state, setState = React.useState (fun () -> 0) in
  >   (state, setState)
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let useCustomHook () =
    let (state, setState) = React.useState (fun () -> 0) in (state, setState)

Custom hook with snake_case name
  $ cat > input.ml << 'EOF'
  > let use_custom_hook () =
  >   let state, set_state = React.useState (fun () -> 0) in
  >   (state, set_state)
  > EOF

  $ ../src/standalone.exe input.ml 2>&1
  let use_custom_hook () =
    let (state, set_state) = React.useState (fun () -> 0) in (state, set_state)
