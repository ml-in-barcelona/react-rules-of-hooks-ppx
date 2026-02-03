JSX in default argument should not cause false positive on hooks in the body

  $ cat > input.ml << 'EOF'
  > let[@react.component] make ?(header = ((H4.createElement () ~children:[])[@JSX])) ~children =
  >   let (state, setState) = React.useState (fun () -> 0) in
  >   ((Div.createElement () ~children:[header; children])[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(header= ((H4.createElement () ~children:[])[@JSX ]))  ~children  =
    let (state, setState) = React.useState (fun () -> 0) in
    ((Div.createElement () ~children:[header; children])[@JSX ])[@@react.component
                                                                  ]

Multiple JSX default arguments should not affect hooks in body

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(header = ((H4.createElement () ~children:[])[@JSX]))
  >   ?(footer = ((Footer.createElement () ~children:[])[@JSX]))
  >   ~children =
  >   let (count, setCount) = React.useState (fun () -> 0) in
  >   let onClick = React.useCallback1 (fun _ -> setCount (fun n -> n + 1)) [|setCount|] in
  >   ((Div.createElement () ~children:[header; children; footer])[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(header= ((H4.createElement () ~children:[])[@JSX ]))  ?(footer=
    ((Footer.createElement () ~children:[])[@JSX ]))  ~children  =
    let (count, setCount) = React.useState (fun () -> 0) in
    let onClick =
      React.useCallback1 (fun _ -> setCount (fun n -> n + 1)) [|setCount|] in
    ((Div.createElement () ~children:[header; children; footer])[@JSX ])
    [@@react.component ]

Nested JSX in default argument

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(wrapper = ((Outer.createElement ()
  >       ~children:[((Inner.createElement () ~children:[])[@JSX])])[@JSX]))
  >   () =
  >   let (state, _) = React.useState (fun () -> 0) in
  >   wrapper
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(wrapper=
    ((Outer.createElement ()
        ~children:[((Inner.createElement () ~children:[])[@JSX ])])
    [@JSX ]))  () = let (state, _) = React.useState (fun () -> 0) in wrapper
    [@@react.component ]

JSX in Some() wrapper as default argument

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(icon = Some ((Icon.createElement () ~children:[])[@JSX]))
  >   ~children =
  >   let (visible, setVisible) = React.useState (fun () -> true) in
  >   ((Div.createElement () ~children:[children])[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(icon= Some ((Icon.createElement () ~children:[])[@JSX ])) 
    ~children  =
    let (visible, setVisible) = React.useState (fun () -> true) in
    ((Div.createElement () ~children:[children])[@JSX ])[@@react.component ]

JSX in tuple as default argument

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(icons = (((Left.createElement () ~children:[])[@JSX]),
  >              ((Right.createElement () ~children:[])[@JSX])))
  >   () =
  >   let (active, setActive) = React.useState (fun () -> 0) in
  >   let (left, right) = icons in
  >   ((Div.createElement () ~children:[left; right])[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(icons=
    (((Left.createElement () ~children:[])[@JSX ]),
      ((Right.createElement () ~children:[])[@JSX ])))
     () =
    let (active, setActive) = React.useState (fun () -> 0) in
    let (left, right) = icons in
    ((Div.createElement () ~children:[left; right])[@JSX ])[@@react.component ]

JSX in list as default argument

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(items = [((Item1.createElement () ~children:[])[@JSX]);
  >              ((Item2.createElement () ~children:[])[@JSX])])
  >   () =
  >   let (selected, setSelected) = React.useState (fun () -> None) in
  >   ((List.createElement () ~children:items)[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(items=
    [((Item1.createElement () ~children:[])
    [@JSX ]);
    ((Item2.createElement () ~children:[])
    [@JSX ])])  () =
    let (selected, setSelected) = React.useState (fun () -> None) in
    ((List.createElement () ~children:items)[@JSX ])[@@react.component ]

JSX with props containing expressions in default argument

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(button = ((Button.createElement ()
  >       ~onClick:(fun _ -> ())
  >       ~disabled:false
  >       ~children:["Click"])[@JSX]))
  >   () =
  >   let (count, setCount) = React.useState (fun () -> 0) in
  >   ((Div.createElement () ~children:[button])[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(button=
    ((Button.createElement () ~onClick:(fun _ -> ()) ~disabled:false
        ~children:["Click"])
    [@JSX ]))  () =
    let (count, setCount) = React.useState (fun () -> 0) in
    ((Div.createElement () ~children:[button])[@JSX ])[@@react.component ]

Mixed JSX and non-JSX default arguments

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(header = ((Header.createElement () ~children:[])[@JSX]))
  >   ?(className = "default")
  >   ?(footer = ((Footer.createElement () ~children:[])[@JSX]))
  >   ?(onClick = fun _ -> ())
  >   () =
  >   let (state, setState) = React.useState (fun () -> 0) in
  >   let memo = React.useMemo1 (fun () -> state * 2) [|state|] in
  >   ((Div.createElement () ~className ~children:[header; footer])[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(header= ((Header.createElement () ~children:[])[@JSX ])) 
    ?(className= "default")  ?(footer= ((Footer.createElement () ~children:[])
    [@JSX ]))  ?(onClick= fun _ -> ())  () =
    let (state, setState) = React.useState (fun () -> 0) in
    let memo = React.useMemo1 (fun () -> state * 2) [|state|] in
    ((Div.createElement () ~className ~children:[header; footer])[@JSX ])
    [@@react.component ]

Multiple hooks after JSX default arguments

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(element = ((Span.createElement () ~children:[])[@JSX]))
  >   () =
  >   let (a, setA) = React.useState (fun () -> 0) in
  >   let (b, setB) = React.useState (fun () -> "") in
  >   let ref = React.useRef None in
  >   let callback = React.useCallback1 (fun () -> setA (fun x -> x + 1)) [|setA|] in
  >   let memo = React.useMemo2 (fun () -> a + String.length b) (a, b) in
  >   React.useEffect1 (fun () -> None) [|a|];
  >   ((Div.createElement () ~children:[element])[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(element= ((Span.createElement () ~children:[])[@JSX ]))  () =
    let (a, setA) = React.useState (fun () -> 0) in
    let (b, setB) = React.useState (fun () -> "") in
    let ref = React.useRef None in
    let callback =
      React.useCallback1 (fun () -> setA (fun x -> x + 1)) [|setA|] in
    let memo = React.useMemo2 (fun () -> a + (String.length b)) (a, b) in
    React.useEffect1 (fun () -> None) [|a|];
    ((Div.createElement () ~children:[element])
    [@JSX ])[@@react.component ]

Deeply nested JSX in default argument

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(content = ((A.createElement ()
  >       ~children:[((B.createElement ()
  >           ~children:[((C.createElement ()
  >               ~children:[((D.createElement () ~children:[])[@JSX])])[@JSX])])[@JSX])])[@JSX]))
  >   () =
  >   let (depth, setDepth) = React.useState (fun () -> 0) in
  >   content
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(content=
    ((A.createElement ()
        ~children:[((B.createElement ()
                       ~children:[((C.createElement ()
                                      ~children:[((D.createElement ()
                                                     ~children:[])
                                                [@JSX ])])
                                 [@JSX ])])
                  [@JSX ])])
    [@JSX ]))  () =
    let (depth, setDepth) = React.useState (fun () -> 0) in content[@@react.component
                                                                     ]

JSX default arg with conditional expression inside

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(element = if true then ((A.createElement () ~children:[])[@JSX]) else ((B.createElement () ~children:[])[@JSX]))
  >   () =
  >   let (flag, setFlag) = React.useState (fun () -> true) in
  >   element
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(element=
    if true
    then ((A.createElement () ~children:[])[@JSX ])
    else ((B.createElement () ~children:[])[@JSX ]))  () =
    let (flag, setFlag) = React.useState (fun () -> true) in element[@@react.component
                                                                      ]

JSX default arg with match expression

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(element = match None with
  >     | Some _ -> ((A.createElement () ~children:[])[@JSX])
  >     | None -> ((B.createElement () ~children:[])[@JSX]))
  >   () =
  >   let (opt, setOpt) = React.useState (fun () -> None) in
  >   element
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(element=
    match None with
    | Some _ -> ((A.createElement () ~children:[])[@JSX ])
    | None -> ((B.createElement () ~children:[])[@JSX ]))  () =
    let (opt, setOpt) = React.useState (fun () -> None) in element[@@react.component
                                                                    ]

Custom hook with JSX default arguments

  $ cat > input.ml << 'EOF'
  > let useCustomHook ?(fallback = ((Loading.createElement () ~children:[])[@JSX])) () =
  >   let (data, setData) = React.useState (fun () -> None) in
  >   let (loading, setLoading) = React.useState (fun () -> true) in
  >   (data, loading, fallback)
  > EOF

  $ ../src/standalone.exe input.ml
  let useCustomHook ?(fallback= ((Loading.createElement () ~children:[])
    [@JSX ]))  () =
    let (data, setData) = React.useState (fun () -> None) in
    let (loading, setLoading) = React.useState (fun () -> true) in
    (data, loading, fallback)

JSX in record field as default argument

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(config = { header = ((H.createElement () ~children:[])[@JSX]); footer = ((F.createElement () ~children:[])[@JSX]) })
  >   () =
  >   let (expanded, setExpanded) = React.useState (fun () -> false) in
  >   ((Div.createElement () ~children:[config.header; config.footer])[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(config=
    {
      header = ((H.createElement () ~children:[])[@JSX ]);
      footer = ((F.createElement () ~children:[])[@JSX ])
    })  () =
    let (expanded, setExpanded) = React.useState (fun () -> false) in
    ((Div.createElement () ~children:[config.header; config.footer])[@JSX ])
    [@@react.component ]

Combination: JSX default args and JSX in body with multiple hooks

  $ cat > input.ml << 'EOF'
  > let[@react.component] make
  >   ?(prefix = ((Prefix.createElement () ~children:[])[@JSX]))
  >   ?(suffix = ((Suffix.createElement () ~children:[])[@JSX]))
  >   ~value
  >   () =
  >   let (internal, setInternal) = React.useState (fun () -> value) in
  >   let (focused, setFocused) = React.useState (fun () -> false) in
  >   let handleFocus = React.useCallback0 (fun () -> setFocused (fun _ -> true)) in
  >   let handleBlur = React.useCallback0 (fun () -> setFocused (fun _ -> false)) in
  >   React.useEffect1 (fun () -> setInternal (fun _ -> value); None) [|value|];
  >   ((Container.createElement ()
  >       ~children:[
  >         prefix;
  >         ((Input.createElement ()
  >             ~value:internal
  >             ~onFocus:handleFocus
  >             ~onBlur:handleBlur
  >             ~children:[])[@JSX]);
  >         suffix
  >       ])[@JSX])
  > EOF

  $ ../src/standalone.exe input.ml
  let make ?(prefix= ((Prefix.createElement () ~children:[])[@JSX ])) 
    ?(suffix= ((Suffix.createElement () ~children:[])[@JSX ]))  ~value  () =
    let (internal, setInternal) = React.useState (fun () -> value) in
    let (focused, setFocused) = React.useState (fun () -> false) in
    let handleFocus = React.useCallback0 (fun () -> setFocused (fun _ -> true)) in
    let handleBlur = React.useCallback0 (fun () -> setFocused (fun _ -> false)) in
    React.useEffect1 (fun () -> setInternal (fun _ -> value); None) [|value|];
    ((Container.createElement ()
        ~children:[prefix;
                  ((Input.createElement () ~value:internal ~onFocus:handleFocus
                      ~onBlur:handleBlur ~children:[])
                  [@JSX ]);
                  suffix])
    [@JSX ])[@@react.component ]
