open Ppxlib;

/* Merlin_helpers.hide_expression */

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
             | Ppat_var({txt}) => Some(txt)
             | _ => None
             }
           )
        |> List.filter(Option.is_some)
        |> List.map(Option.get);

      let newMeta = pushIdentList([expr, ...exprs]);
      {...newMeta, values};
    /* TODO: list(case) */
    | Pexp_function(_) => meta
    | Pexp_fun(_, _, _, expr) => getIdentsInner(expr, meta)
    /* This ignores any function expression, since those aren't checked */
    | Pexp_apply(_expr, labeledExpr) =>
      let exprs = List.map(snd, labeledExpr);
      pushIdentList(exprs);
    /* TODO: list(case) */
    | Pexp_match(expr, _) => getIdentsInner(expr, meta)
    /* TODO: list(case) */
    | Pexp_try(expr, _) => getIdentsInner(expr, meta)
    | Pexp_tuple(exprs) => pushIdentList(exprs)
    | Pexp_construct({txt: Lident("None"), _}, _) => meta
    | Pexp_construct(_, Some(expr)) => getIdentsInner(expr, meta)
    | Pexp_variant(_, Some(expr)) => getIdentsInner(expr, meta)
    | Pexp_record(fields, Some(expr)) =>
      let exprs = List.map(snd, fields);
      pushIdentList(exprs);
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

let useEffectExpand = (e: Parsetree.expression) =>
  switch (e.pexp_desc) {
  | Pexp_apply(
      {
        pexp_desc: Pexp_ident({loc: _loc, txt: _, _}),
        pexp_loc: _,
        pexp_attributes: _,
        pexp_loc_stack: _,
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

let () =
  /* TODO: Instead of register_transformation, try register_correction
     which suggest the corrected AST to the user. In the useEffect dependency
     case, it should print the expression with the new dependency array. */
  Driver.register_transformation(
    ~rules=[
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
