open Ppxlib;

let exhaustiveDeps = ref(true);
let orderOfHooks = ref(true);

let raiseWithLoc = (~loc, msg, variables) =>
  Location.raise_errorf(~loc, msg, variables) |> ignore;

let diff = (list1, list2) => List.filter(x => !List.mem(x, list2), list1);

let rec unique = lst =>
  switch (lst) {
  | [] => []
  | [h, ...t] => [h, ...unique(List.filter(x => x != h, t))]
  };

let quotes = str => "'" ++ str ++ "'";

type meta = {
  ids: list(longident), /* List of identifiers */
  values: list(string) /* List of values in scope of useEffect */
};

let getIdents = (expression: Parsetree.expression) => {
  let rec getIdentsInner = (expression: Parsetree.expression, meta: meta) => {
    let pushIdentList = exprs => {
      let newIds =
        List.concat_map(expr => [getIdentsInner(expr, meta)], exprs)
        |> List.concat_map(meta => meta.ids);

      {...meta, ids: List.append(meta.ids, newIds)};
    };

    switch (expression.pexp_desc) {
    | Pexp_ident({txt: ident, _}) => {...meta, ids: [ident, ...meta.ids]}
    | Pexp_let(_, valueBindings, expr) =>
      let exprs = List.map(value => value.pvb_expr, valueBindings);
      let values =
        valueBindings
        |> List.map(value =>
             switch (value.pvb_pat.ppat_desc) {
             | Ppat_var({txt, _}) => Some(txt)
             | _ => None
             }
           )
        |> List.filter(Option.is_some)
        |> List.map(Option.get);

      let newMeta = pushIdentList([expr, ...exprs]);
      {...newMeta, values};
    | Pexp_function(case) =>
      let exprs = List.map(case => case.pc_rhs, case);
      pushIdentList(exprs);
    | Pexp_fun(_, _, _, expr) => getIdentsInner(expr, meta)
    | Pexp_apply(_expr, labeledExpr) =>
      let exprs = List.map(snd, labeledExpr);
      pushIdentList(exprs);
    | Pexp_match(expr, cases) =>
      let exprs = [expr, ...List.map(case => case.pc_rhs, cases)];
      pushIdentList(exprs);
    | Pexp_try(expr, cases) =>
      let exprs = [expr, ...List.map(case => case.pc_rhs, cases)];
      pushIdentList(exprs);
    | Pexp_tuple(exprs) => pushIdentList(exprs)
    | Pexp_construct({txt: Lident("None"), _}, _) => meta
    | Pexp_construct(_, Some(expr)) => getIdentsInner(expr, meta)
    | Pexp_variant(_, Some(expr)) => getIdentsInner(expr, meta)
    | Pexp_record(fields, Some(expr)) =>
      let exprs = List.map(snd, fields);
      pushIdentList([expr, ...exprs]);
    | Pexp_record(fields, None) =>
      let exprs = List.map(snd, fields);
      pushIdentList(exprs);
    | Pexp_field(expr, _) => getIdentsInner(expr, meta)
    | Pexp_setfield(expr1, _, expr2) => pushIdentList([expr1, expr2])
    | Pexp_array(exprs) => pushIdentList(exprs)
    | Pexp_ifthenelse(expr1, expr2, None) => pushIdentList([expr1, expr2])
    | Pexp_ifthenelse(expr1, expr2, Some(expr3)) =>
      pushIdentList([expr1, expr2, expr3])
    | Pexp_sequence(expr, seqExpr) => pushIdentList([expr, seqExpr])
    | Pexp_while(expr1, expr2) => pushIdentList([expr1, expr2])
    | Pexp_for(_, expr1, expr2, _, expr3) =>
      pushIdentList([expr1, expr2, expr3])
    | Pexp_constraint(expr, _) => getIdentsInner(expr, meta)
    | Pexp_coerce(expr, _, _) => getIdentsInner(expr, meta)
    | Pexp_send(expr, _) => getIdentsInner(expr, meta)
    | Pexp_setinstvar(_, expr) => getIdentsInner(expr, meta)
    | Pexp_override(fields) =>
      let exprs = List.map(snd, fields);
      pushIdentList(exprs);
    | Pexp_letmodule(_, _, expr) => getIdentsInner(expr, meta)
    | Pexp_letexception(_, expr) => getIdentsInner(expr, meta)
    | Pexp_assert(expr) => getIdentsInner(expr, meta)
    | Pexp_lazy(expr) => getIdentsInner(expr, meta)
    | Pexp_poly(expr, _) => getIdentsInner(expr, meta)
    | Pexp_newtype(_, expr) => getIdentsInner(expr, meta)
    | Pexp_open(_, expr) => getIdentsInner(expr, meta)
    | _ => meta
    };
  };

  getIdentsInner(expression, {ids: [], values: []});
};

let useEffectLint = (e: Parsetree.expression) =>
  switch (e.pexp_desc) {
  | Pexp_apply(
      {
        pexp_desc: Pexp_ident(_),
        _,
      },
      args,
    ) =>
    {
      let bodyExpression =
        switch (List.nth_opt(args, 0)) {
        | Some((_label, {pexp_desc: Pexp_fun(_, _, _, expression), _})) =>
          Some(expression)
        | _ => None
        };

      let bodyIdents =
        bodyExpression
        |> Option.map(getIdents)
        |> Option.value(~default={ids: [], values: []});

      let bodyIdentsInsideScope =
        diff(bodyIdents.ids |> List.map(Longident.name), bodyIdents.values);

      let dependenciesIdents =
        List.nth_opt(args, 1)
        |> Option.map(a => snd(a))
        |> Option.map(deps => getIdents(deps))
        |> Option.value(~default={ids: [], values: []});

      let dependenciesNames =
        dependenciesIdents.ids |> List.map(Longident.name);

      let result = diff(bodyIdentsInsideScope, dependenciesNames);

      let missingDependencies =
        result |> unique |> List.map(quotes) |> String.concat(", ");

      List.length(result) > 0
        ? raiseWithLoc(
            ~loc=e.pexp_loc,
            "ExhaustiveDeps: Missing %s in the dependency array",
            missingDependencies,
          )
        : ();
    };
    None;
  | _ => None
  };

let useEffectExpand = (e: Parsetree.expression) =>
  if (exhaustiveDeps^ == true) {
    useEffectLint(e);
  } else {
    None;
  };

let startsWith = (affix, str) => {
  let start =
    try(String.sub(str, 0, String.length(affix))) {
    | _ => ""
    };

  start == affix;
};

type acc = {
  isInsideConditional: bool,
  isInsideJSX: bool,
  locations: list(Location.t),
};

let findConditionalHooks = {
  let getName = lident => {
    switch (lident) {
    | Lident(l) => l
    | Ldot(_, l) => l
    | _ => ""
    };
  };

  let isAHook = lident => {
    let name = getName(lident);
    startsWith("use", name);
  };

  let containsJSX = (attrs: attributes) => {
    let someAttrIsJsx =
      List.find_opt(({attr_name, _}) => attr_name.txt == "JSX", attrs);

    Option.is_some(someAttrIsJsx);
  };

  let linter = {
    as _;
    inherit class Ast_traverse.fold(acc) as super;
    pub! expression = (t, acc) => {
      let acc =
        super#expression(
          t,
          {
            ...acc,
            isInsideJSX: acc.isInsideJSX || containsJSX(t.pexp_attributes),
          },
        );

      switch (t.pexp_desc) {
      | Pexp_apply({pexp_desc: Pexp_ident({txt: lident, _}), _}, _args)
          when isAHook(lident) && acc.isInsideConditional => {
          ...acc,
          locations: [t.pexp_loc, ...acc.locations],
        }
      | Pexp_apply({pexp_desc: Pexp_ident({txt: lident, _}), _}, _args)
          when isAHook(lident) && acc.isInsideJSX => {
          ...acc,
          locations: [t.pexp_loc, ...acc.locations],
          isInsideJSX: false,
        }
      | Pexp_sequence(_, exp) =>
        let acc =
          super#expression(
            exp,
            {...acc, isInsideJSX: containsJSX(exp.pexp_attributes)},
          );

        acc;
      | Pexp_match(_expr, listOfExpr) =>
        List.fold_left(
          (acc, expr) =>
            super#expression(
              expr.pc_rhs,
              {...acc, isInsideConditional: true},
            ),
          acc,
          listOfExpr,
        )
      | Pexp_while(_cond, expr) =>
        super#expression(expr, {...acc, isInsideConditional: true})
      | Pexp_for(_, _, _, _, expr) =>
        super#expression(expr, {...acc, isInsideConditional: true})
      | Pexp_ifthenelse(ifExpr, thenExpr, elseExpr)
          when !acc.isInsideConditional =>
        let acc =
          super#expression(ifExpr, {...acc, isInsideConditional: true});
        let acc =
          super#expression(thenExpr, {...acc, isInsideConditional: true});

        let acc =
          switch (elseExpr) {
          | Some(expr) =>
            super#expression(expr, {...acc, isInsideConditional: true})
          | None => acc
          };

        {...acc, isInsideConditional: true};
      | _ => super#expression(t, acc)
      };
    }
  };

  linter#structure;
};

let conditionalHooksLinter = (structure: Parsetree.structure) => {
  let {locations, _} =
    findConditionalHooks(
      structure,
      {isInsideConditional: false, isInsideJSX: false, locations: []},
    );

  let lintErrors =
    locations
    |> unique
    |> List.iter(loc =>
         raiseWithLoc(
           ~loc,
           "Hooks can't be inside conditionals, neither loops.",
           "",
         )
       );

  orderOfHooks^ == true ? lintErrors : ();

  structure;
};

let () =
  Driver.add_arg(
    "-exhaustive-deps",
    Set(exhaustiveDeps),
    ~doc="If set, checks for 'exhaustive dependencies' in UseEffects",
  );

let () =
  Driver.add_arg(
    "-orderOfHooks-of-hooks",
    Set(orderOfHooks),
    ~doc="If set, checks for hooks being called at the top level",
  );

let () =
  Driver.register_transformation(
    ~impl=conditionalHooksLinter,
    ~rules=[
      /* useEffect */
      Context_free.Rule.special_function("React.useEffect", useEffectExpand),
      Context_free.Rule.special_function("useEffect", useEffectExpand),
      Context_free.Rule.special_function("React.useEffect1", useEffectExpand),
      Context_free.Rule.special_function("useEffect1", useEffectExpand),
      Context_free.Rule.special_function("React.useEffect2", useEffectExpand),
      Context_free.Rule.special_function("useEffect2", useEffectExpand),
      Context_free.Rule.special_function("React.useEffect3", useEffectExpand),
      Context_free.Rule.special_function("useEffect3", useEffectExpand),
      Context_free.Rule.special_function("React.useEffect4", useEffectExpand),
      Context_free.Rule.special_function("useEffect4", useEffectExpand),
      Context_free.Rule.special_function("React.useEffect5", useEffectExpand),
      Context_free.Rule.special_function("useEffect5", useEffectExpand),
      Context_free.Rule.special_function("React.useEffect6", useEffectExpand),
      Context_free.Rule.special_function("useEffect6", useEffectExpand),
      Context_free.Rule.special_function("React.useEffect7", useEffectExpand),
      Context_free.Rule.special_function("useEffect7", useEffectExpand),
    ],
    "react-rules-of-hooks",
  );
