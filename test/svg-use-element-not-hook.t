SVG <use> element is not a hook - JSX elements (with [@JSX] attribute) are excluded from hook detection

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~svgRef =
  >   <svg>
  >     <use href="#icon" />
  >     <use href="#" ref=(ReactDOM.Ref.domRef svgRef) />
  >   </svg>
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make ~svgRef =
    ((svg ()
        ~children:[((use () ~children:[] ~href:"#icon")
                  [@JSX ]);
                  ((use () ~children:[] ~href:"#"
                      ~ref:(ReactDOM.Ref.domRef svgRef))
                  [@JSX ])])
    [@JSX ])[@@react.component ]
