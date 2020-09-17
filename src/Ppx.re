open Migrate_parsetree;
open Ast_410;
open Ast_mapper;
open Parsetree;

exception MissingDependencyOnEffectArray(string);

let rulesOfHooksMapper = (_, _) => {
  ...default_mapper,
  expr: (mapper, expr) =>
    switch (expr.pexp_desc) {
    /* Map to every function call with the name
         - React.useEffect
         - React.useLayoutEffect
         - useEffect
         - useLayoutEffect
       */
    | Pexp_ident({loc: _, txt: Ldot(Lident("React"), useEffect)}) =>
      failwith("React." ++ useEffect)
    | Pexp_apply(
        {
          pexp_desc:
            Pexp_ident({loc: _, txt: Ldot(Lident("React"), useEffect)}),
          pexp_loc: _,
          pexp_attributes: _,
          pexp_loc_stack: _,
        },
        [_arguments],
      ) =>
      failwith("React. " ++ useEffect)
    | _ => default_mapper.expr(mapper, expr)
    },
};

let () =
  Driver.register(
    ~name="rules-of-hooks-ppx",
    Versions.ocaml_410,
    rulesOfHooksMapper,
  );
