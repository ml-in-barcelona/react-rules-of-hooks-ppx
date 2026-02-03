SVG <use> element is not a hook - JSX elements (with [@JSX] attribute) are excluded from hook detection

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ~svgRef =
  >   ((svg () ~children:[
  >     (use () ~children:[] ~href:"#icon")[@JSX];
  >     (use () ~children:[] ~href:"#" ~ref:(ReactDOM.Ref.domRef svgRef))[@JSX]
  >   ] ())[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ~svgRef  =
    ((svg ()
        ~children:[((use () ~children:[] ~href:"#icon")
                  [@JSX ]);
                  ((use () ~children:[] ~href:"#"
                      ~ref:(ReactDOM.Ref.domRef svgRef))
                  [@JSX ])] ())
    [@JSX ])[@@react.component ]
