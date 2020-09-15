open Migrate_parsetree;
open Ast_410;
open Ast_mapper;
open Parsetree;

let rulesOfHooksMapper = (_, _) => {
  ...default_mapper,
  expr: (mapper, expr) =>
    switch (expr.pexp_desc) {
    | _ => default_mapper.expr(mapper, expr)
    },
};

let () =
  Driver.register(
    ~name="rules-of-hooks-ppx",
    Versions.ocaml_410,
    rulesOfHooksMapper,
  );
