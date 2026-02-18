Module-level values used in effect body without being in deps should not warn
(OCaml values are immutable, so outer scope bindings are referentially stable)
  $ cat > input.mlx << 'EOF'
  > let globalValue = 42
  > 
  > let[@react.component] make () =
  >   React.useEffect
  >     (fun () -> Js.log globalValue; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml 2>&1
  let globalValue = 42
  let make () = React.useEffect (fun () -> Js.log globalValue; None); div
    [@@react.component ]

Stdlib functions (not, ignore) used in effect body should not warn as missing deps
  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~skip ~fetcher ~memoDeps =
  >   React.useEffect2
  >     (fun () ->
  >       if not skip then fetcher () |> ignore;
  >       None)
  >     (memoDeps, skip);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'fetcher' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~skip ~fetcher ~memoDeps =
    React.useEffect2 (fun () -> if not skip then (fetcher ()) |> ignore; None)
      (memoDeps, skip);
    div[@@react.component ]

Module-level functions used in effect body without being in deps should not warn
  $ cat > input.mlx << 'EOF'
  > let helper x = x + 1
  > 
  > let[@react.component] make () =
  >   React.useEffect
  >     (fun () -> Js.log (helper 1); None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml 2>&1
  let helper x = x + 1
  let make () = React.useEffect (fun () -> Js.log (helper 1); None); div
    [@@react.component ]

  $ cat > input.mlx << 'EOF'
  > let globalValue = 42
  > 
  > let[@react.component] make () =
  >   React.useEffect1
  >     (fun () -> Js.log globalValue; None)
  >     [| globalValue |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

Module-level values in deps should warn as unnecessary
(outer scope values don't trigger re-renders, since they can't be mutated)
  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "exhaustive-deps: React.useEffect1 has an unnecessary dependency: 'globalValue'. Outer scope values like 'globalValue' aren't valid dependencies because they are constant and never change between renders.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let globalValue = 42
  let make () =
    React.useEffect1 (fun () -> Js.log globalValue; None) [|globalValue|]; div
    [@@react.component ]

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   React.useEffect1
  >     (fun () -> Js.log Js.log; None)
  >     [| Js.log |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

External module values (like Js.log) in deps are unnecessary
  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "exhaustive-deps: React.useEffect1 has an unnecessary dependency: 'Js.log'. Outer scope values like 'Js.log' aren't valid dependencies because they are constant and never change between renders.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make () =
    React.useEffect1 (fun () -> Js.log Js.log; None) [|Js.log|]; div[@@react.component
                                                                      ]

Qualified module refs and Stdlib functions should not be treated as missing deps
  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~key ~query ~alwaysInUrl =
  >   React.useEffect2
  >     (fun () ->
  >       ignore (List.fromArray(Js.Dict.entries(query)));
  >       if not alwaysInUrl then ignore (String.equal(key, key));
  >       None)
  >     (query, alwaysInUrl);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml 2>&1
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'key' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  let make ~key ~query ~alwaysInUrl =
    React.useEffect2
      (fun () ->
         ignore (List.fromArray (Js.Dict.entries query));
         if not alwaysInUrl then ignore (String.equal (key, key));
         None) (query, alwaysInUrl);
    div[@@react.component ]
