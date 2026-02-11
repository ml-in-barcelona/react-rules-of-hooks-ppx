  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~value =
  >   let result = match value with
  >     | Some x -> x
  >     | None -> 0
  >   in
  >   let (state, _) = React.useState (fun () -> result) in
  >   let adjusted = if state > 0 then state else 0 in
  >   let (count, _) = React.useState (fun () -> adjusted) in
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Hooks after match/if expressions should be valid (conditional context should not leak)
  $ ../src/standalone.exe input.ml 2>&1
  let make ~value =
    let result = match value with | Some x -> x | None -> 0 in
    let (state, _) = React.useState (fun () -> result) in
    let adjusted = if state > 0 then state else 0 in
    let (count, _) = React.useState (fun () -> adjusted) in div[@@react.component
                                                                 ]
