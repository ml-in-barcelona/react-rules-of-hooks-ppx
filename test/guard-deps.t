A `when` guard inside a match in the callback body uses its identifiers:
`limit` must be declared.

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~(value : int option) ~(limit : int) =
  >   React.useEffect1
  >     (fun () ->
  >       (match value with Some x when x > limit -> Js.log x | _ -> ());
  >       None)
  >     [| value |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'limit' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~value:(value : int option) ~limit:(limit : int) =
    React.useEffect1
      (fun () ->
         (match value with | Some x when x > limit -> Js.log x | _ -> ()); None)
      [|value|];
    div[@@react.component ]

Declaring the guard dependency satisfies the check; case-bound names (`x`)
are not dependencies.

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~(value : int option) ~(limit : int) =
  >   React.useEffect2
  >     (fun () ->
  >       (match value with Some x when x > limit -> Js.log x | _ -> ());
  >       None)
  >     (value, limit);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make ~value:(value : int option) ~limit:(limit : int) =
    React.useEffect2
      (fun () ->
         (match value with | Some x when x > limit -> Js.log x | _ -> ()); None)
      (value, limit);
    div[@@react.component ]
