An effect without a dependency array runs after every render, so it can
never observe stale values: exhaustive-deps does not apply. Test inputs
migrated from eslint-plugin-react-hooks' ExhaustiveDeps suite.

A local value read inside a no-deps effect is not a missing dependency:

  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   let local = "banana" in
  >   React.useEffect (fun () -> Js.log local; None);
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  let make () =
    let local = "banana" in React.useEffect (fun () -> Js.log local; None); div
    [@@react.component ]

Nested-scope locals in a no-deps effect:

  $ cat > input2.ml << 'EOF'
  > let[@react.component] make () =
  >   let local1 = "a" in
  >   let local2 = "b" in
  >   React.useEffect (fun () -> Js.log local1; Js.log local2; None);
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let make () =
    let local1 = "a" in
    let local2 = "b" in
    React.useEffect (fun () -> Js.log local1; Js.log local2; None); div
    [@@react.component ]

Empty no-deps effects are fine, for the whole effect family:

  $ cat > input3.ml << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect (fun () -> None);
  >   React.useLayoutEffect (fun () -> None);
  >   React.useInsertionEffect (fun () -> None);
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  let make () =
    React.useEffect (fun () -> None);
    React.useLayoutEffect (fun () -> None);
    React.useInsertionEffect (fun () -> None);
    div[@@react.component ]

A setState call inside a NESTED handler of a no-deps effect is valid; only
direct calls in the effect body trigger the infinite-loop guard (eslint's
resize-listener test):

  $ cat > input4.ml << 'EOF'
  > let[@react.component] make () =
  >   let _state, setState = React.useState (fun () -> 0) in
  >   React.useEffect (fun () ->
  >       let handleResize = fun () -> setState (fun _ -> Window.innerWidth) in
  >       Window.addEventListener "resize" handleResize;
  >       Some (fun () -> Window.removeEventListener "resize" handleResize));
  >   div
  > EOF

  $ ../src/standalone.exe input4.ml
  let make () =
    let (_state, setState) = React.useState (fun () -> 0) in
    React.useEffect
      (fun () ->
         let handleResize () = setState (fun _ -> Window.innerWidth) in
         Window.addEventListener "resize" handleResize;
         Some ((fun () -> Window.removeEventListener "resize" handleResize)));
    div[@@react.component ]

The regression that motivated this fix: the usePrevious pattern from the
React docs (ref updated by a no-deps effect) must be accepted:

  $ cat > input5.ml << 'EOF'
  > let usePrevious value =
  >   let valueRef = React.useRef value in
  >   React.useEffect (fun () -> valueRef.current <- value; None);
  >   valueRef.current
  > EOF

  $ ../src/standalone.exe input5.ml
  let usePrevious value =
    let valueRef = React.useRef value in
    React.useEffect (fun () -> valueRef.current <- value; None);
    valueRef.current

Order-of-hooks still sees unsuffixed effects: a conditional
React.useEffect(fn) is still an order violation, and a hook inside its
callback is too:

  $ cat > input6.ml << 'EOF'
  > let[@react.component] make ~cond =
  >   (if cond then React.useEffect (fun () -> None));
  >   div
  > EOF

  $ ../src/standalone.exe input6.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~cond = if cond then React.useEffect (fun () -> None); div[@@react.component
                                                                      ]

  $ cat > input7.ml << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect (fun () -> ignore (React.useState (fun () -> 0)); None);
  >   div
  > EOF

  $ ../src/standalone.exe input7.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make () =
    React.useEffect (fun () -> ignore (React.useState (fun () -> 0)); None);
    div[@@react.component ]
