%platform branches are not conditional, but real runtime conditionals nested
inside them (or wrapping them) still are.

A runtime match inside a Client branch with a hook inside still errors
(LandingStickyNavigation shape):

  $ cat > input.ml << 'EOF'
  > let use ~hideTriggerRef =
  >   match%platform Runtime.platform with
  >   | Server -> false
  >   | Client -> (
  >       match hideTriggerRef with
  >       | Some elRef -> UseScrollPercentage.use elRef > 0.
  >       | None -> false)
  > EOF

  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let use ~hideTriggerRef =
    [%platform
      match Runtime.platform with
      | Server -> false
      | Client ->
          (match hideTriggerRef with
           | Some elRef -> (UseScrollPercentage.use elRef) > 0.
           | None -> false)]

A %platform switch nested inside a real conditional stays conditional:

  $ cat > input2.ml << 'EOF'
  > let[@react.component] make ~cond =
  >   (if cond then
  >      match%platform Runtime.platform with
  >      | Server -> ()
  >      | Client -> ignore (React.useState (fun () -> 0)));
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~cond =
    if cond
    then
      [%platform
        (match Runtime.platform with
         | Server -> ()
         | Client -> ignore (React.useState (fun () -> 0)))];
    div[@@react.component ]

A %platform switch inside a useEffect callback stays conditional
(WrapperWithToolSidebar shape):

  $ cat > input3.ml << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect0 (fun () ->
  >       (match%platform Runtime.platform with
  >        | Client -> ignore (React.useState (fun () -> 0))
  >        | Server -> ());
  >       None);
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make () =
    React.useEffect0
      (fun () ->
         [%platform
           (match Runtime.platform with
            | Client -> ignore (React.useState (fun () -> 0))
            | Server -> ())];
         None);
    div[@@react.component ]
