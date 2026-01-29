  $ cat > input.mlx << 'EOF'
  > let useMyCustomHook () =
  >   let (state, setState) = React.useState (fun () -> 0) in
  >   (state, setState)
  > 
  > let[@react.component] make () =
  >   let _ = useMyCustomHook () in
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

Custom hook definitions should allow hooks inside (useX naming convention)
  $ ../src/standalone.exe input.ml 2>&1
  let useMyCustomHook () =
    let (state, setState) = React.useState (fun () -> 0) in (state, setState)
  let make () = let _ = useMyCustomHook () in div[@@react.component ]
