Corrections must not add convention-stable setters to the generated deps:

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~value =
  >   let _st, setSt = RR.useStateValue 0 in
  >   React.useEffect0 (fun () -> setSt value; None);
  >   div
  > EOF

  $ ../src/standalone.exe -corrections input.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect0 (fun () -> setSt value; None);
  +  React.useEffect1 (fun () -> setSt value; None) [| value |];

Same for a Layer 1 wrapper:

  $ cat > input2.ml << 'EOF'
  > let useStateValue initial = React.useReducer (fun _ next -> next) initial
  > 
  > let[@react.component] make ~value =
  >   let _st, update = useStateValue 0 in
  >   React.useEffect0 (fun () -> update value; None);
  >   div
  > EOF

  $ ../src/standalone.exe -corrections input2.ml 2>&1 | grep -E "^[+-].*useEffect"
  -  React.useEffect0 (fun () -> update value; None);
  +  React.useEffect1 (fun () -> update value; None) [| value |];
