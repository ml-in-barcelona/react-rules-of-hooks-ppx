Distinct member paths of the same record are not duplicates:

  $ cat > input.mlx << 'EOF'
  > type params = { page : int; limit : int }
  > let[@react.component] make ~(input : params) =
  >   React.useEffect2
  >     (fun () -> Js.log2 input.page input.limit; None)
  >     (input.page, input.limit);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  type params = {
    page: int ;
    limit: int }
  let make ~input:(input : params) =
    React.useEffect2 (fun () -> Js.log2 input.page input.limit; None)
      ((input.page), (input.limit));
    div[@@react.component ]

Identical paths are still duplicates:

  $ cat > input.mlx << 'EOF'
  > type params = { page : int; limit : int }
  > let[@react.component] make ~(input : params) =
  >   React.useEffect2 (fun () -> Js.log input.page; None) (input.page, input.page);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Duplicate dependency 'input.page' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  type params = {
    page: int ;
    limit: int }
  let make ~input:(input : params) =
    React.useEffect2 (fun () -> Js.log input.page; None)
      ((input.page), (input.page));
    div[@@react.component ]

Root-flattening false negative is fixed - a sibling field is missing:

  $ cat > input.mlx << 'EOF'
  > type params = { page : int; limit : int }
  > let[@react.component] make ~(input : params) =
  >   React.useEffect1 (fun () -> Js.log input.page; None) [| input.limit |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'input.page' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  type params = {
    page: int ;
    limit: int }
  let make ~input:(input : params) =
    React.useEffect1 (fun () -> Js.log input.page; None) [|(input.limit)|]; div
    [@@react.component ]

A declared prefix covers deeper uses; whole-record use requires the root:

  $ cat > input.mlx << 'EOF'
  > type inner = { size : int }
  > type params = { page : inner }
  > let[@react.component] make ~(input : params) ~send =
  >   React.useEffect1 (fun () -> Js.log input.page.size; None) [| input.page |];
  >   React.useEffect2 (fun () -> send input; None) (send, input);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  type inner = {
    size: int }
  type params = {
    page: inner }
  let make ~input:(input : params) ~send =
    React.useEffect1 (fun () -> Js.log (input.page).size; None)
      [|(input.page)|];
    React.useEffect2 (fun () -> send input; None) (send, input);
    div[@@react.component ]

Declaring the whole record covers member uses:

  $ cat > input.mlx << 'EOF'
  > type params = { page : int; limit : int }
  > let[@react.component] make ~(input : params) =
  >   React.useEffect1 (fun () -> Js.log2 input.page input.limit; None) [| input |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  type params = {
    page: int ;
    limit: int }
  let make ~input:(input : params) =
    React.useEffect1 (fun () -> Js.log2 input.page input.limit; None) [|input|];
    div[@@react.component ]

A declared member does not cover a whole-record use:

  $ cat > input.mlx << 'EOF'
  > type params = { page : int; limit : int }
  > let[@react.component] make ~(input : params) =
  >   React.useEffect1 (fun () -> Js.log input; None) [| input.page |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'input' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  type params = {
    page: int ;
    limit: int }
  let make ~input:(input : params) =
    React.useEffect1 (fun () -> Js.log input; None) [|(input.page)|]; div
    [@@react.component ]

Stable roots cover their fields (ref.current):

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let r = React.useRef 0 in
  >   React.useEffect0 (fun () -> Js.log r.current; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make () =
    let r = React.useRef 0 in
    React.useEffect0 (fun () -> Js.log r.current; None); div[@@react.component
                                                              ]

Unnecessary member deps report the full path:

  $ cat > input.mlx << 'EOF'
  > type params = { page : int }
  > let config : params = { page = 1 }
  > let[@react.component] make () =
  >   React.useEffect1 (fun () -> Js.log config.page; None) [| config.page |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: React.useEffect1 has an unnecessary dependency: 'config.page'. Outer scope values like 'config.page' aren't valid dependencies because they are constant and never change between renders.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  type params = {
    page: int }
  let config : params = { page = 1 }
  let make () =
    React.useEffect1 (fun () -> Js.log config.page; None) [|(config.page)|];
    div[@@react.component ]

A member write (setfield) is covered by the declared member path:

  $ cat > input.mlx << 'EOF2'
  > type params = { mutable page : int }
  > let[@react.component] make ~(input : params) =
  >   React.useEffect1 (fun () -> input.page <- 1; None) [| input.page |];
  >   div
  > EOF2

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  type params = {
    mutable page: int }
  let make ~input:(input : params) =
    React.useEffect1 (fun () -> input.page <- 1; None) [|(input.page)|]; div
    [@@react.component ]

When both a record and one of its members are missing, only the record is
reported and corrected (the prefix subsumes the member):

  $ cat > input.mlx << 'EOF2'
  > type params = { page : int; limit : int }
  > let[@react.component] make ~(input : params) ~send =
  >   React.useEffect1 (fun () -> send input; Js.log input.page; None) [||];
  >   div
  > EOF2

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E '^[+-].*useEffect|Missing'
    "exhaustive-deps: Missing dependencies 'send', 'input' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  -  React.useEffect1 (fun () -> send input; Js.log input.page; None) [||]; div
  +  React.useEffect2 (fun () -> send input; Js.log input.page; None) (send, input); div
