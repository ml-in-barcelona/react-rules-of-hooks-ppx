open Ppxlib;

/* Merlin_helpers.hide_expression */

let locatedRaise = (~loc, msg) => Location.raise_errorf(~loc, msg);

let expand = (e: Parsetree.expression) =>
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
    ignore(locatedRaise(~loc, "lident"));
    None;
  | _ => None
  };

let () =
  Driver.register_transformation(
    ~rules=[Context_free.Rule.special_function("useEffect1", expand)],
    "react-rules-of-hooks",
  );
