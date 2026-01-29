  $ cat > input.mlx << 'EOF'
  > type person = { name : string; age : int }
  > 
  > let[@react.component] make () =
  >   React.useEffect1
  >     (fun () ->
  >       let { name; age } = { name = "test"; age = 1 } in
  >       Js.log name;
  >       Js.log age;
  >       None)
  >     [||];
  >   div
  > EOF
  $ mlx-pp -print-ml input.mlx > input.ml

Record destructuring inside effect should NOT trigger missing deps (name, age are local)
  $ ../src/standalone.exe input.ml 2>&1
  type person = {
    name: string ;
    age: int }
  let make () =
    React.useEffect1
      (fun () ->
         let { name; age } = { name = "test"; age = 1 } in
         Js.log name; Js.log age; None) [||];
    div[@@react.component ]
