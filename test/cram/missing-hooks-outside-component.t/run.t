Hooks outside components or custom hooks should be detected
NOTE: This feature requires more sophisticated context tracking and is deferred
to a future version.
  $ ../../../src/standalone.exe input.ml 2>&1 || true
  let _ = React.useState (fun () -> 0)
  let regularFunction () = let _ = React.useState (fun () -> 0) in ()
  let make () = div[@@react.component ]
