  $ cat > input.mlx << 'EOF'
  > let _useNotAHook () = ()
  > 
  > let[@react.component] make ~condition =
  >   if condition then _useNotAHook ();
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Functions starting with _use are not hooks (underscore prefix)
  $ ../src/standalone.exe input.ml 2>&1
  let _useNotAHook () = ()
  let make ~condition = if condition then _useNotAHook (); div[@@react.component
                                                                ]
