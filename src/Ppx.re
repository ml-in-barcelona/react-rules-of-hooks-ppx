open Ppxlib;

/* Merlin_helpers.hide_expression */

let locatedRaise = (~loc, msg) => Location.raise_errorf(~loc, msg) |> ignore;

let useEffect1Expand = (e: Parsetree.expression) =>
  switch (e.pexp_desc) {
  | Pexp_apply(
      {
        pexp_desc: Pexp_ident({loc, txt: _lident, _}),
        pexp_loc: _pexp_loc,
        pexp_attributes: _,
        pexp_loc_stack: _,
      },
      _args,
    ) =>
    locatedRaise(~loc, "lident");
    None;
  | _ => None
  };

let () =
  /* TODO: Instead of register_transformation, try register_correction
     which suggest the corrected AST to the user. In the useEffect dependency
     case, it should print the expression with the new dependency array. */
  Driver.register_transformation(
    ~rules=[
      /* TODO: Add all useEffects as rules */
      Context_free.Rule.special_function(
        "React.useEffect1",
        useEffect1Expand,
      ),
      Context_free.Rule.special_function("useEffect1", useEffect1Expand),
    ],
    "react-rules-of-hooks",
  );
