# Member-path dependency tracking & component attribute markers

Status: proposal (part 1) + documentation of in-progress work (part 2)
Author: davesnx
Date: 2026-07-22
Companions: `PLATFORM_BRANCHES.md`, `STABLE_HOOKS.md`, `NO_DEPS_EFFECTS.md`
Origin: ahrefs monorepo PR #31653 — after shipping 1.3.0, an offline audit
re-derived the diagnostic behind every remaining `[@disable_exhaustive_deps]`
annotation (1,703 diagnostics across 881 files, obtained by running the
standalone driver over refmt-converted sources with suppressions renamed
away). Two of the discovered classes are ppx defects, specified here.

---

## Part 1 — Member-path dependency tracking

### The bug

`Deps.of_expression` (`src/deps.ml:92`) flattens record-field access to its
root identifier:

```ocaml
| Pexp_field (expr, _) -> collect expr (ids_rev, values_rev)
(*                ^ field name discarded *)
```

Every dependency and every body use of `input.page`, `input.limit`,
`state.filters`… is tracked as just `input` / `state`. Three consequences:

**1. False positive — "duplicate dependency" (114 sites in the corpus).**
The single largest defect class found by the audit. Real example
(`account-settings/src/pages/AsAuditLog.re:413`):

```reason
React.useEffect6(
  () => ...,
  (subscriptions, input.period, input.tools, input.userIds, input.page, input.limit),
);
```

Five distinct member paths normalize to `input` five times →
`exhaustive-deps: Duplicate dependency 'input' in the dependency array.`
The code is *correct*; each entry is a distinct reactive value.

**2. False negative — wrong coverage (unmeasured, latent).** With roots
only, deps `[|input.limit|]` "covers" a body that reads `input.page`: both
normalize to `input`, so no missing-dep is reported even though the effect
goes stale when `page` changes but `limit` doesn't. The current
implementation silently accepts genuinely wrong dependency arrays.

**3. Imprecise "unnecessary dependency" reports.** The outer-scope check
reports roots, so `value`/`Int64.to_string` mixes in the same message and
suggested corrections can't distinguish which member was meant.

### What eslint does

`exhaustive-deps` treats member chains as first-class dependency paths:
`props.foo` and `props.bar` are distinct; a declared `props.foo` satisfies
deeper uses (`props.foo.bar`); using the whole object (`props` passed as a
value) requires `props` itself; duplicates are exact-path duplicates only.
Suggestions are emitted at member-path granularity.

### Spec

Represent both declared deps and body uses as **paths**:
`root.field₁.field₂…`.

1. **Path extraction.** A path is a chain of `Pexp_field` over a
   `Pexp_ident`. The root's `Longident` may itself be module-qualified
   (`Module.value`) — module qualification is part of the root, not a field
   step (`Pexp_field` vs `Ldot` distinguishes these syntactically). Any
   other shape inside a dep entry (function application, array access,
   `##` send, etc.) degrades to its root identifiers, preserving today's
   behavior.
2. **Coverage.** A body use `u` is satisfied iff some declared path `d` is
   a prefix of `u` (equal counts). Declared `input.page` covers
   `input.page.size` but not `input.limit` and not bare `input`.
3. **Duplicates.** Two declared entries are duplicates iff their paths are
   identical. `(input.page, input.limit)` is not a duplicate.
   `(input.page, input.page)` still is.
4. **Missing deps.** Report and suggest the paths as used in the body
   (`Missing dependency 'input.page'`), matching eslint. `-corrections`
   output writes member paths into the generated array.
5. **Unnecessary deps.** A declared `d` with no use it prefixes is
   unnecessary; report the full path.
6. **Stability.** A stable root (setters, refs, `STABLE_HOOKS.md` results)
   makes every path under it stable — `ref.current` stays exempt because
   `ref` is.
7. **Bound-name shadowing.** `Bindings`-tracked local names shadow whole
   path families by root, as today.

### Implementation sketch

`Deps.t` becomes path-based:

```ocaml
type path = { root : Longident.t; fields : string list }
type t = { used_paths : path list; bound_names : string list }

let rec path_of_expression (e : Parsetree.expression) : path option =
  match e.pexp_desc with
  | Pexp_ident { txt; _ } -> Some { root = txt; fields = [] }
  | Pexp_field (inner, { txt = Lident field; _ }) ->
      Option.map
        (fun p -> { p with fields = p.fields @ [ field ] })
        (path_of_expression inner)
  | Pexp_constraint (inner, _) -> path_of_expression inner
  | _ -> None

(* in collect: *)
| Pexp_field _ as _desc -> (
    match path_of_expression expression with
    | Some p -> (p :: paths_rev, values_rev)
    | None -> (* degrade: descend as today *) collect_children ...)

let is_prefix ~(declared : path) ~(used : path) =
  Longident.compare declared.root used.root = 0 (* by name *)
  && List.length declared.fields <= List.length used.fields
  && List.for_all2 String.equal declared.fields
       (List.filteri (fun i _ -> i < List.length declared.fields) used.fields)
```

Comparison sites to convert from `StringSet` of names to path logic:
`missing_deps` diff (`src/ppx.ml:141-147`), duplicate detection
(`src/ppx.ml:~99` message site), outer-scope/unnecessary reporting, and the
corrections formatter (`format_deps`). A path renders as
`Longident.name root ^ "." ^ String.concat "." fields` for messages.

### Cram tests

`test/member-path-deps.t`:

```cram
Distinct member paths of the same record are not duplicates:

  $ cat > input.mlx << 'EOF'
  > type params = { page : int; limit : int }
  > let[@react.component] make ~(input : params) =
  >   React.useEffect2
  >     (fun () -> Js.log2 input.page input.limit; None)
  >     (input.page, input.limit);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  type params = { page : int; limit : int }
  let make ~(input : params) =
    React.useEffect2 (fun () -> Js.log2 input.page input.limit; None)
      (input.page, input.limit);
    div[@@react.component]

Identical paths are still duplicates:

  $ cat > input.mlx << 'EOF'
  > type params = { page : int; limit : int }
  > let[@react.component] make ~(input : params) =
  >   React.useEffect2 (fun () -> Js.log input.page; None) (input.page, input.page);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Duplicate dependency 'input.page' in the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  ...

Root-flattening false negative is fixed — a sibling field is missing:

  $ cat > input.mlx << 'EOF'
  > type params = { page : int; limit : int }
  > let[@react.component] make ~(input : params) =
  >   React.useEffect1 (fun () -> Js.log input.page; None) [| input.limit |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  [@@@ocaml.ppwarning
    "exhaustive-deps: Missing dependency 'input.page' from the dependency array.\nTo suppress this warning, add [@disable_exhaustive_deps] to the expression"]
  ...

A declared prefix covers deeper uses; whole-record use requires the root:

  $ cat > input.mlx << 'EOF'
  > type inner = { size : int }
  > type params = { page : inner }
  > let[@react.component] make ~(input : params) ~send =
  >   React.useEffect1 (fun () -> Js.log input.page.size; None) [| input.page |];
  >   React.useEffect1 (fun () -> send input; None) [| input |];
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  ... (no exhaustive-deps warnings besides 'send' handling per existing rules)

Stable roots cover their fields (ref.current):

  $ cat > input.mlx << 'EOF'
  > let[@react.component] make () =
  >   let r = React.useRef 0 in
  >   React.useEffect0 (fun () -> Js.log r.current; None);
  >   div
  > EOF

  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  ... (no warnings)
```

(Expected outputs are the specification; settle exact layout with
`dune promote`. Extend `test/corrections-flag.t` with a member-path case:
the generated array must contain `input.page`, not `input`.)

### Acceptance criteria (part 1)

1. The 114 duplicate-dependency suppressions in the ahrefs monorepo become
   removable with a green build.
2. New false negatives caught: introducing `[| input.limit |]` deps over a
   body using `input.page` errors (add a monorepo canary or rely on the
   cram test).
3. All existing tests green; corrections emit member paths.

---

## Part 2 — Component attribute markers (`react.client.component`, `react.async.component`)

### Status

Partially implemented in the uncommitted modular refactor:
`src/scope.ml:15` has
`component_attributes = [ "react.component"; "react.client.component" ]`
and `test/client-component-attribute.t` covers both acceptance and the
conditional-hook error inside such components. The released 1.3.0 only
recognizes `react.component`.

### Why

server-reason-react defines **three** component attributes (verified in
`packages/reason-react-ppx` of server-reason-react 0.4.1):

- `[@react.component]`
- `[@react.client.component]` — client components under RSC; hydrated on
  the client, so every hook rule applies fully. Corpus evidence:
  `admin-support/src/shared/pages/SiteInspector.re` carries a
  `[@disable_order_of_hooks]` with a "ppx doesn't recognize
  react.client.component" comment solely because of this gap.
- `[@react.async.component]` — **missing from the current list.** Async
  server components render once per request; hook usage is atypical but a
  binding marked as a component must classify as one, otherwise any hook
  inside reports the misleading "can only be called from
  [@react.component] functions" instead of a real diagnostic (or nothing).

### Spec

1. `Scope.component_attributes` includes all three names.
2. Order-of-hooks semantics inside all three are identical: hooks allowed
   at top level, conditional calls still error (already demonstrated by
   `client-component-attribute.t` for the client variant — add the same
   pair of cases for `react.async.component`).
3. Documentation: README lists the recognized attributes.

### Cram test to add

`test/async-component-attribute.t` — same shape as
`client-component-attribute.t` with `[@react.async.component]`.

### Acceptance criteria (part 2)

1. `SiteInspector.re`'s annotation and its explanatory comment become
   removable in the ahrefs monorepo with a green build.
2. Both attribute tests pass; conditional hooks inside client/async
   components still error.
