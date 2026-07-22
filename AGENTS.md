# Agent instructions

## Keep the design document current

`docs/design.md` is the canonical description of how the ppx works.

- Read `docs/design.md` before changing ppx behavior or architecture.
- Update `docs/design.md` in the same change whenever implementation behavior, architecture, invariants, diagnostics, supported syntax, flags, or edge-case handling changes.
- Every bug fix must update `docs/design.md` to describe the corrected behavior and, when useful, include an example and the implementation detail that prevents the regression.
- Keep the document aligned with the current implementation. Remove stale claims instead of preserving historical proposals or outdated file and line references.
- Do not create separate design documents for individual features. Fold the relevant material into `docs/design.md`.
- Treat a code change as incomplete until its tests pass and `docs/design.md` reflects the resulting behavior.

## Code organization

- Keep `src/ppx.ml` focused on traversal orchestration, diagnostics, caching, and driver registration. Put cohesive syntax or domain logic in the existing support modules.
- Give each parsetree encoding one owner. `Platform` recognizes platform extensions, `Hook` recognizes hooks, `Bindings` handles names and function bodies, `Deps` extracts dependency paths, `Stable` infers stable values, and `Scope` tracks binding state. Do not repeat raw AST patterns across callers when one of these modules can expose the operation.
- When multiple AST forms share semantics, route them through one typed helper instead of maintaining parallel branches. For example, function, `match`, `try`, and platform cases share case traversal where their binding and guard rules match.
- Use `Ast_traverse` for ordinary whole-tree traversal. Use explicit recursion when order, binding, fallback, or target-specific semantics matter.
- Thread traversal and scope state through immutable records. Keep enter/body/exit and save/restore behavior explicit. Process-level flags and the per-file analysis cache are the intentional exceptions.
- Use domain names (`client_case`, `path_of_expression`, `wrapper_shape`) and labelled arguments for relationships that are easy to reverse (`~prefix`, `~path`, `~entered`, `~traversed`). Short AST-local names such as `e`, `pat`, and `vbs` are fine.

## Interfaces and comments

- Add an `.mli` when extracting a reusable support module. Do not require one for entry points such as `ppx.ml` or `standalone.ml`.
- Do not add module or file header comments. Put architecture in `docs/design.md`.
- Add declaration-level doc comments only when they explain a non-obvious contract, invariant, fallback, or error mode. Do not comment code that is already clear from its name and pattern match.

## Tests

- Add feature-scoped Cram tests in `test/*.t`. Include concrete source, the exact `standalone.exe` command, and the complete transformed output or diagnostic text.
- Test the reported regression and its nearest valid and boundary cases. Include interactions with existing flags, platform handling, stability, shadowing, or corrections when the change touches those rules.
- Prefer explicit test cases over helpers, loops, or conditional logic inside tests. Group related positive and negative cases in one feature file.
- Use `.mlx`, then `mlx-pp -print-ml`, for normal Reason syntax. Use direct `.ml` for raw extension nodes or behavior that should not depend on preprocessing.
- Use `make test-promote` only to regenerate Cram output. Review every promoted change before accepting it.

## Verification

- Run `make format`, `make format-check`, `make build`, and `make test` after code changes.
- Edit `dune-project`, not the generated `react-rules-of-hooks-ppx.opam` file.

## Performance

- Keep the ppx as fast as possible. Preserve the hook-free early exit and the single cached analysis shared by `~impl` and `~lint_impl`.
- Avoid adding whole-tree passes when the existing fold or a focused local traversal can do the work. Reuse facts already carried in `analysis_state` or `Scope` instead of recomputing them.
- Use sets and maps for repeated membership and lookup operations. Keep source-order lists only where diagnostics or corrections require stable ordering.
- For changes that add traversal or per-expression work, compare timing with `REACT_HOOKS_PPX_TIMING=1` and document any intentional cost in `docs/design.md`.
