  $ cat > input.ml << 'EOF'
  > let[@react.component] make () =
  >   Js.log "starting component";
  >   let (state, _) = React.useState (fun () -> 0) in
  >   Js.log state;
  >   div
  > EOF

Hooks in sequence at top level of component should be valid
  $ ../src/standalone.exe input.ml 2>&1
  let make () =
    Js.log "starting component";
    (let (state, _) = React.useState (fun () -> 0) in Js.log state; div)
    [@@react.component ]
