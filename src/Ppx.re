open Ppxlib;

/* Merlin_helpers.hide_expression */

let raiseWithLoc = (~loc, msg, variables) =>
  Location.raise_errorf(~loc, msg, variables) |> ignore;

let diff = (list1, list2) => List.filter(x => !List.mem(x, list2), list1);

let quotes = str => "'" ++ str ++ "'";

let getIdents = (expression: Parsetree.expression) => {
  let rec getIdentsInner =
          (expression: Parsetree.expression, identifiers: list(longident)) => {
    switch (expression.pexp_desc) {
    | Pexp_ident({txt: ident, _}) => [ident, ...identifiers]
    | Pexp_constant(_) => identifiers
    | Pexp_let(_, _, expr) => getIdentsInner(expr, identifiers)
    /* TODO: list(case) */
    | Pexp_function(_) => identifiers
    | Pexp_fun(_, _, _, expr) => getIdentsInner(expr, identifiers)
    /* This ignores any function, since */
    | Pexp_apply(_expr, labeledExpr) =>
      let exprs = List.map(snd, labeledExpr);
      List.concat_map(expr => getIdentsInner(expr, identifiers), exprs);
    /* TODO: list(case) */
    | Pexp_match(expr, _) => getIdentsInner(expr, identifiers)
    /* TODO: list(case) */
    | Pexp_try(expr, _) => getIdentsInner(expr, identifiers)
    | Pexp_tuple(exprs) =>
      List.concat_map(expr => getIdentsInner(expr, identifiers), exprs)
    | Pexp_construct(_, None) => identifiers
    | Pexp_construct({txt: Lident("None")}, _) => identifiers
    | Pexp_construct(_, Some(expr)) => getIdentsInner(expr, identifiers)
    | Pexp_variant(_, Some(expr)) => getIdentsInner(expr, identifiers)
    | Pexp_variant(_, _) => identifiers
    | Pexp_record(fields, Some(expr)) =>
      let exprs = List.map(snd, fields);
      List.concat_map(
        e => getIdentsInner(e, identifiers),
        [expr, ...exprs],
      );
    | Pexp_record(fields, None) =>
      let exprs = List.map(snd, fields);
      List.concat_map(e => getIdentsInner(e, identifiers), exprs);
    | Pexp_field(expr, _) => getIdentsInner(expr, identifiers)
    | Pexp_setfield(expr1, _, expr2) =>
      List.concat_map(
        expr => getIdentsInner(expr, identifiers),
        [expr1, expr2],
      )
    | Pexp_array(exprs) =>
      List.concat_map(expr => getIdentsInner(expr, identifiers), exprs)
    | Pexp_ifthenelse(expr1, expr2, None) =>
      List.concat_map(
        expr => getIdentsInner(expr, identifiers),
        [expr1, expr2],
      )
    | Pexp_ifthenelse(expr1, expr2, Some(expr3)) =>
      List.concat_map(
        expr => getIdentsInner(expr, identifiers),
        [expr1, expr2, expr3],
      )
    | Pexp_sequence(expr, seqExpr) =>
      List.concat_map(
        expr => getIdentsInner(expr, identifiers),
        [expr, seqExpr],
      )
    | Pexp_while(expr1, expr2) =>
      List.concat_map(
        expr => getIdentsInner(expr, identifiers),
        [expr1, expr2],
      )
    | Pexp_for(_, expr1, expr2, _, expr3) =>
      List.concat_map(
        expr => getIdentsInner(expr, identifiers),
        [expr1, expr2, expr3],
      )
    | Pexp_constraint(expr, _) => getIdentsInner(expr, identifiers)
    | Pexp_coerce(expr, _, _) => getIdentsInner(expr, identifiers)
    | Pexp_send(expr, _) => getIdentsInner(expr, identifiers)
    | Pexp_setinstvar(_, expr) => getIdentsInner(expr, identifiers)
    | Pexp_override(fields) =>
      let exprs = List.map(snd, fields);
      List.concat_map(e => getIdentsInner(e, identifiers), exprs);
    | Pexp_letmodule(_, _, expr) => getIdentsInner(expr, identifiers)
    | Pexp_letexception(_, expr) => getIdentsInner(expr, identifiers)
    | Pexp_assert(expr) => getIdentsInner(expr, identifiers)
    | Pexp_lazy(expr) => getIdentsInner(expr, identifiers)
    | Pexp_poly(expr, _) => getIdentsInner(expr, identifiers)
    | Pexp_newtype(_, expr) => getIdentsInner(expr, identifiers)
    | Pexp_open(_, expr) => getIdentsInner(expr, identifiers)
    /* TODO: Do we need this new X? */
    | Pexp_new(_) => identifiers
    | Pexp_object(_) => identifiers
    | Pexp_pack(_) => identifiers
    | Pexp_letop(_) => identifiers
    | Pexp_extension(_) => identifiers
    | Pexp_unreachable => identifiers
    };
  };

  getIdentsInner(expression, []);
};

let useEffectExpand = (e: Parsetree.expression) =>
  switch (e.pexp_desc) {
  | Pexp_apply(
      {
        pexp_desc: Pexp_ident({loc, txt: _, _}),
        pexp_loc,
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
        bodyExpression |> Option.map(getIdents) |> Option.value(~default=[]);

      let dependenciesIdents =
        List.nth_opt(args, 1)
        |> Option.map(a => snd(a))
        |> Option.map(deps => getIdents(deps))
        |> Option.value(~default=[]);

      let result = diff(bodyIdents, dependenciesIdents);

      let missingDependencies =
        result
        |> List.map(Longident.name)
        |> List.map(quotes)
        |> String.concat(", ");

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
