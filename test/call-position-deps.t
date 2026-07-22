A member path in call position counts as a use:

  $ cat > input.mlx << 'EOF'
  > type input = { callback : unit -> unit }
  > let[@react.component] make ~(input : input) =
  >   React.useEffect0 (fun () -> input.callback (); None) [||];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'input.callback' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  type input = {
    callback: unit -> unit }
  let make ~input:(input : input) =
    React.useEffect0 (fun () -> input.callback (); None) [||]; div[@@react.component
                                                                    ]

Declaring the called path covers it:

  $ cat > input.mlx << 'EOF'
  > type input = { callback : unit -> unit }
  > let[@react.component] make ~(input : input) =
  >   React.useEffect1 (fun () -> input.callback (); None) [| input.callback |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  type input = {
    callback: unit -> unit }
  let make ~input:(input : input) =
    React.useEffect1 (fun () -> input.callback (); None) [|(input.callback)|];
    div[@@react.component ]

Deeper call paths report the full path, and a declared prefix covers them:

  $ cat > input.mlx << 'EOF'
  > type handlers = { onClick : unit -> unit }
  > type input = { handlers : handlers }
  > let[@react.component] make ~(input : input) =
  >   React.useEffect0 (fun () -> input.handlers.onClick (); None) [||];
  >   React.useEffect1 (fun () -> input.handlers.onClick (); None) [| input.handlers |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'input.handlers.onClick' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  type handlers = {
    onClick: unit -> unit }
  type input = {
    handlers: handlers }
  let make ~input:(input : input) =
    React.useEffect0 (fun () -> (input.handlers).onClick (); None) [||];
    React.useEffect1 (fun () -> (input.handlers).onClick (); None)
      [|(input.handlers)|];
    div[@@react.component ]

A callee that is not a plain path degrades to its sub-expressions:

  $ cat > input.mlx << 'EOF'
  > type handlers = { onClick : unit -> unit }
  > let[@react.component] make ~(getHandlers : unit -> handlers) =
  >   React.useEffect0 (fun () -> (getHandlers ()).onClick (); None) [||];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'getHandlers' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  type handlers = {
    onClick: unit -> unit }
  let make ~getHandlers:(getHandlers : unit -> handlers) =
    React.useEffect0 (fun () -> (getHandlers ()).onClick (); None) [||]; div
    [@@react.component ]

Module-qualified callees are outer scope and never reported as missing:

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect0 (fun () -> Js.log 1; None) [||];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make () = React.useEffect0 (fun () -> Js.log 1; None) [||]; div[@@react.component
                                                                      ]
