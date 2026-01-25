let useMouseHook () = ()

let[@react.component] make ~randomProp =
  if randomProp = "state" then ((useMouseHook ())[@reason.preserve_braces ]);
  div
