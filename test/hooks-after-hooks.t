  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~value =
  >   let (state, setState) = React.useState (fun () -> 0) in
  >   let (count, _) = React.useState (fun () -> state) in
  >   let memoized = React.useMemo2 (fun () -> state + count) (state, count) in
  >   let callback = React.useCallback1 (fun () -> setState (fun s -> s + 1)) [| setState |] in
  >   let ref = React.useRef 0 in
  >   let (reducerState, _) = React.useReducer (fun s _ -> s + 1) 0 in
  >   let layout = React.useLayoutEffect1 (fun () -> None) [||] in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Multiple different hooks in sequence should all be valid
  $ ../src/standalone.exe input.ml 2>&1
  let make ~value =
    let (state, setState) = React.useState (fun () -> 0) in
    let (count, _) = React.useState (fun () -> state) in
    let memoized = React.useMemo2 (fun () -> state + count) (state, count) in
    let callback =
      React.useCallback1 (fun () -> setState (fun s -> s + 1)) [|setState|] in
    let ref = React.useRef 0 in
    let (reducerState, _) = React.useReducer (fun s _ -> s + 1) 0 in
    let layout = React.useLayoutEffect1 (fun () -> None) [||] in div[@@react.component
                                                                      ]
