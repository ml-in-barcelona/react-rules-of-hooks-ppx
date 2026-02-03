  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let (state, setState) = React.useState (fun () -> 0) in
  >   React.useEffect1
  >     (fun () -> setState (fun _ -> state + 1); None)
  >     [| state |];
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

setState from useState should be omittable from deps (it's stable)
  $ ../src/standalone.exe input.ml 2>&1
  let make () =
    let (state, setState) = React.useState (fun () -> 0) in
    React.useEffect1 (fun () -> setState (fun _ -> state + 1); None) [|state|];
    div[@@react.component ]

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let myRef = React.useRef 0 in
  >   React.useEffect (fun () -> 
  >     Js.log myRef.current;
  >     None
  >   );
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

useRef result should be omittable from deps (ref is stable, ref.current is mutable)
  $ ../src/standalone.exe input.ml 2>&1
  let make () =
    let myRef = React.useRef 0 in
    React.useEffect (fun () -> Js.log myRef.current; None); div[@@react.component
                                                                 ]

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let (state, dispatch) = React.useReducer (fun _ action -> action) 0 in
  >   React.useEffect1
  >     (fun () -> dispatch (state + 1); None)
  >     [| state |];
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

dispatch from useReducer should be omittable from deps (it's stable)
  $ ../src/standalone.exe input.ml 2>&1
  let make () =
    let (state, dispatch) = React.useReducer (fun _ -> fun action -> action) 0 in
    React.useEffect1 (fun () -> dispatch (state + 1); None) [|state|]; div
    [@@react.component ]
