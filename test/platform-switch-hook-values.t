let use = switch%platform ... selecting a hook implementation per target
(UseUrl shape): per bundle, `use` *is* one concrete hook.

Bare hook idents per branch (eta-form):

  $ cat > input.ml << 'EOF'
  > let use =
  >   match%platform () with
  >   | Server -> Context.use
  >   | Client -> ReasonReactRouter.useUrl
  > 
  > let[@react.component] make () =
  >   let url = use () in
  >   ignore url;
  >   div
  > EOF

  $ ../src/standalone.exe input.ml
  let use =
    [%platform
      match () with
      | Server -> Context.use
      | Client -> ReasonReactRouter.useUrl]
  let make () = let url = use () in ignore url; div[@@react.component ]

Lambda per branch: the binding classifies as a custom hook (any branch with a
function body), so hook calls inside are neither conditional nor "outside a
component or custom hook":

  $ cat > input2.ml << 'EOF'
  > let use =
  >   match%platform () with
  >   | Server -> (fun () -> Context.use ())
  >   | Client -> (fun () -> ReasonReactRouter.useUrl ())
  > EOF

  $ ../src/standalone.exe input2.ml
  let use =
    [%platform
      match () with
      | Server -> (fun () -> Context.use ())
      | Client -> (fun () -> ReasonReactRouter.useUrl ())]
