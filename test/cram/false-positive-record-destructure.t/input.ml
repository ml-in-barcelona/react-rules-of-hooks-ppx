type person = { name : string; age : int }

let[@react.component] make () =
  React.useEffect1
    (fun () ->
      let { name; age } = { name = "test"; age = 1 } in
      Js.log name;
      Js.log age;
      None)
    [||];
  div
