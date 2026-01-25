let[@react.component] make () =
  ((div ~onClick:((fun _evt -> useMouseHook ())[@reason.preserve_braces ])
      ())
  [@JSX ])
