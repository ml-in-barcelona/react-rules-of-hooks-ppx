  $ cat > input.mlx << 'EOF'
  > let _useNotAHook () = ()
  > 
  > let[@react.component] make ~condition =
  >   if condition then _useNotAHook ();
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

Functions starting with _use are not hooks and should be allowed in conditionals
  $ ../src/standalone.exe input.ml 2>&1
  let _useNotAHook () = ()
  let make ~condition  = if condition then _useNotAHook (); div[@@react.component
                                                                 ]

  $ cat > input.mlx << 'EOF'
  > let use_not_a_hook () = ()
  > 
  > let[@react.component] make ~condition =
  >   if condition then use_not_a_hook ();
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

Functions with use_ (underscore after use) should not be hooks
  $ ../src/standalone.exe input.ml 2>&1
  let use_not_a_hook () = ()
  let make ~condition  = if condition then use_not_a_hook (); div[@@react.component
                                                                   ]

  $ cat > input.mlx << 'EOF'
  > let userFetch () = ()
  > 
  > let[@react.component] make ~condition =
  >   if condition then userFetch ();
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

Functions starting with 'user' (not 'use') should not be hooks
  $ ../src/standalone.exe input.ml 2>&1
  let userFetch () = ()
  let make ~condition  = if condition then userFetch (); div[@@react.component
                                                              ]
