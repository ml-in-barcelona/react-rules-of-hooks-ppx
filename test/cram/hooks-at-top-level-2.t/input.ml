let[@react.component] make () =
  let state, setState = React.useState () in
  ((div ~onClick:((fun _evt -> useMouseHook ())[@reason.preserve_braces ]) ())
  [@JSX ])
