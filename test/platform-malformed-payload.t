Only the exact shapes browser_ppx rewrites are recognized; anything else
falls back to today's behavior, silently.

if%platform is not a browser_ppx construct: the conditional inside is
treated as a real conditional:

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~cond =
  >   (if%platform cond then ignore (React.useState (fun () -> 0)));
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  [%%ocaml.error
    "Hooks can't be called conditionally and must be called at the top level of your component or custom hook. Move this hook call outside of conditionals, loops, or nested functions."]
  let make ~cond =
    [%platform if cond then ignore (React.useState (fun () -> 0))]; div
    [@@react.component ]

A non-match %platform payload is traversed normally, no crash, no special
casing:

  $ cat > input2.ml << 'EOF'
  > let[@react.component] make () =
  >   let x = [%platform 42] in
  >   ignore x;
  >   ignore (React.useState (fun () -> 0));
  >   div
  > EOF

  $ ../src/standalone.exe input2.ml
  let make () =
    let x = [%platform 42] in
    ignore x; ignore (React.useState (fun () -> 0)); div[@@react.component ]

An empty %platform payload is ignored:

  $ cat > input3.ml << 'EOF'
  > let[@react.component] make () =
  >   let x = [%platform] in
  >   ignore x;
  >   ignore (React.useState (fun () -> 0));
  >   div
  > EOF

  $ ../src/standalone.exe input3.ml
  let make () =
    let x = [%platform ] in
    ignore x; ignore (React.useState (fun () -> 0)); div[@@react.component ]
