[%browser_only e] is transparent: it adds no conditionality, and
exhaustive-deps sees idents inside the payload.

Missing dependency inside a %browser_only effect callback is reported:

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~media =
  >   React.useEffect1 [%browser_only fun () -> Js.log media; None] [||];
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'media' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~media =
    React.useEffect1 ([%browser_only fun () -> Js.log media; None]) [||]; div
    [@@react.component ]

With the dependency listed, no warning:

  $ cat > input2.ml << 'EOF'
  > let[@react.component] make ~media =
  >   React.useEffect1 [%browser_only fun () -> Js.log media; None] [| media |];
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let make ~media =
    React.useEffect1 ([%browser_only fun () -> Js.log media; None]) [|media|];
    div[@@react.component ]

A hook called inside a %browser_only effect callback is still an error
(effect-callback rules apply to the contents):

  $ cat > input3.ml << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect0
  >     [%browser_only fun () -> ignore (React.useState (fun () -> 0)); None];
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make () =
    React.useEffect0
      ([%browser_only fun () -> ignore (React.useState (fun () -> 0)); None]);
    div[@@react.component ]
