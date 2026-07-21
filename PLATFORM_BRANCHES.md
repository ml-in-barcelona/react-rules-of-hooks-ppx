# Platform branches (`switch%platform` / `let%browser_only`) and rules-of-hooks false positives

Status: design accepted (reviewed 2026-07-21), ready to implement
Author: davesnx
Date: 2026-07-21
Origin: ahrefs monorepo PR #31653 (repo-wide adoption of react-rules-of-hooks-ppx 1.2.0)

## Summary

Codebases built with [server-reason-react](https://github.com/ml-in-barcelona/server-reason-react)
use `switch%platform` and `let%browser_only` / `[%browser_only ...]` to write
universal components that compile to two targets (native SSR and Melange/JS).
These constructs look conditional in the parsetree, but they are resolved **at
compile time, per build target**: exactly one branch survives in each emitted
bundle. Hooks called inside a `| Client =>` branch are therefore
*unconditional* in the client bundle and *dead code* in the server bundle.

react-rules-of-hooks-ppx 1.2.0 does not know this. It sees a `Pexp_match` (or
a non-`use*`-named binding) and reports:

- `Hooks can't be called conditionally and must be called at the top level ...`
- `React hooks can only be called from [@react.component] functions or custom hooks`

While enforcing the ppx across the ahrefs monorepo (~900 frontend files
touched), every violation class was either fixed for real or suppressed.
After fixing everything fixable, **20 annotations remain whose only cause is
platform branching**. They are suppressed with `[@disable_order_of_hooks]`
today and can be removed once the ppx understands these constructs.

## Background: what the constructs mean

server-reason-react's `browser_ppx` (registered in the monorepo as
`server-reason-react.browser_ppx -js -melange` for the Melange target, and
without `-js` for native) rewrites:

- `switch%platform (Runtime.platform) { | Server => a | Client => b }` —
  statically replaced by `a` on native and `b` on Melange. No runtime branch
  exists in either bundle.
- `let%browser_only f = ...` — the body is kept on the Melange target; on
  native the binding becomes a stub (raises / returns unit). Again: no runtime
  branch.
- `[%browser_only () => ...]` — expression form of the same.

A typical pps pipeline in the monorepo:

```clojure
(preprocess
 (pps
  melange.ppx
  melange-react-intl.ppx
  reason-react-ppx
  react-rules-of-hooks-ppx
  server-reason-react.browser_ppx
  -js
  -melange
  server-reason-react.ppx
  styled-ppx))
```

Note that react-rules-of-hooks-ppx runs **before** `browser_ppx`, so it lints
the original source with both branches still present. This is also the useful
order: linting the pre-elimination source covers both targets in one pass and
reports locations in the code the user wrote.

## Why the ppx flags these sites

In `src/ppx.ml` (1.2.0):

1. `collect_hook_order_errors` marks all `Pexp_match` cases as conditional
   (`mark_conditional`). `switch%platform ...` parses as
   `Pexp_extension ({txt = "platform"}, PStr [Pstr_eval (Pexp_match ..., _)])`
   and the default `Ast_traverse` recursion descends into the extension
   payload, so its cases are treated like any runtime `switch` — hooks inside
   any branch become "called conditionally".
2. Component/custom-hook scoping is keyed on `[@react.component]` and
   `use*`-named bindings. A hook called inside
   `let%browser_only makeChargebee = () => Chargebee.useScript()` sits in a
   lambda bound to a non-`use*` name inside an extension node, so it is
   "outside a component or custom hook" — even though the wrapper exists only
   to erase the hook from the native bundle.

## Real-world corpus (ahrefs monorepo, 2026-07)

The 20 surviving `[@disable_order_of_hooks]` annotations, grouped by pattern.

### Pattern 1 — hook calls inside a `switch%platform` branch (13 sites)

| File | Line(s) | Hook in branch |
|---|---|---|
| `toolkit/src/hooks/UseScroll.re` | 18 | `UseScrollListener.use` in `\| Client` |
| `ahkit/src/shared/UseMediaScreen.re` | 27, 29 | `RR.useStateValue`, `React.useEffect0` in `\| Client` |
| `wordcount/.../shared/UseMediaScreen.re` | 33, 35 | same pattern, duplicated module |
| `ahkit/src/shared/CustomizableNavigationBar.re` | 414, 1296 | `RR.useStateValue`, `UseMediaScreen.use` in `\| Client` |
| `static/.../components/Header.re` | 61 | `UseScroll.use` in `\| Client` |
| `static/.../components/MainMenu.re` | 325, 326 | `React.useRef` in `\| Server`, `UseOutsideClick.use` in `\| Client` |
| `admin-support/src/shared/pages/SiteInspector.re` | 50 | `React.useEffect1` in `\| Client` (inside `[@react.client.component]`) |
| `static/.../pages/SignupCheckout.re` | 450 | `PricingSharedT.ReferrerParameter.use` in `\| Client` |
| `static/.../components/LandingStickyNavigation.re` | 15 | `UseScrollPercentage.useScrollPercentage` — see "residual" note below |

Representative example (`UseMediaScreen.re`):

```reason
let use = () => {
  switch%platform (Runtime.platform) {
  | Server => Screen.Desktop
  | Client =>
    let (media, setMedia) = RR.useStateValue(getMedia());   // flagged today
    React.useEffect0(...);                                   // flagged today
    media->Screen.fromMedia;
  };
};
```

Both hooks are unconditional in the JS bundle; the `Server` branch is the
whole function body on native. There is nothing to fix in user code.

### Pattern 2 — hook *implementations* selected per platform (2 sites)

| File | Line(s) | Shape |
|---|---|---|
| `static/.../helpers/UseUrl.re` | 29, 30 | `let use = switch%platform () { \| Server => Context.use \| Client => ReasonReactRouter.useUrl };` |

Each branch is an eta-form hook value; per bundle, `UseUrl.use` *is* one
concrete hook. Same compile-time-resolution argument as Pattern 1.

### Pattern 3 — `let%browser_only` wrappers around hooks (2 sites)

| File | Line(s) | Shape |
|---|---|---|
| `static/.../pages/SignupCheckout.re` | 146 | `let%browser_only makeChargebee = () => Chargebee.useScript();` then `let chargebeeInstance = makeChargebee();` |
| `static/.../pages/SignupCheckout.re` | 323 | `let%browser_only makeStripe = () => Stripe.WithDynamicPublishableKey.useStripe(~publishableKey);` then `let stripe = makeStripe();` |

The wrapper exists solely so the native bundle never references the
browser-only hook. On the client the wrapper is invoked unconditionally right
after its definition, so the hook order is stable. The ppx flags the hook as
"outside a component or custom hook" because `makeChargebee` doesn't start
with `use`.

### Pattern 4 — helpers on platform-guarded call paths (3 sites)

| File | Line | Shape |
|---|---|---|
| `static/.../components/SignUpButton.re` | 67 | `renderSignup` helper calls `useUtm(...)` |
| `static/.../components/BannerRotation.re` | 126 | `render` helper calls `useImpression(...)` |
| `static/.../components/plans-pricing/PPUrlHelper.re` | 34 | `makeUrlToSignupPage` calls `UseUrl.use()` |

These are ordinary non-`use*` helpers that call hooks; their call sites are
unconditional in component renders (some behind `%browser_only` chains). They
could alternatively be fixed in user code by renaming to `use*` (the fix
applied to ~24 similar sites elsewhere in the monorepo); they are listed here
because the monorepo kept the annotation, and because Pattern 3 support would
still not cover them. Consider them secondary motivation only.

### Residual genuine violation worth knowing about

`LandingStickyNavigation.re` is a double conditional:

```reason
switch%platform (Runtime.platform) {
| Server => false
| Client =>
  switch (hideTriggerRef) {           // <- REAL runtime conditional
  | Some(hideTriggerRef) =>
    UseScrollPercentage.useScrollPercentage(~elRef=hideTriggerRef, ...) > 0.
  | None => false
  }
};
```

Even with `%platform` support, the inner `switch (hideTriggerRef)` is a
genuine rules-of-hooks violation (hook called only when the optional ref is
`Some`). The ppx should keep flagging it; the annotation (or a user-code fix
such as an unconditional `useScrollPercentageOpt`) remains warranted. Any
implementation of this proposal must not accidentally whitelist nested
runtime conditionals inside platform branches.

## Corpus survey addendum (full monorepo scan, 2026-07-21)

A full scan of the ahrefs monorepo (beyond the 20 PR annotations) to
validate the design against every shape in the wild:

- 125 `switch%platform` / `match%platform` sites. Case patterns are always
  the bare constructors `Server` and `Client` — never qualified, no guards,
  no wildcards, no or-patterns; both branch orders occur. Scrutinees are
  `(Runtime.platform)` or `()`. The OCaml expression form
  `[%platform match ...]` (`toolkit/src/shared/Constants.ml:20`) parses to
  the same AST as `match%platform`.
- No `if%platform`, `let%platform`, or structure-level `%%platform` exist
  anywhere.
- 469 `let%browser_only` bindings and ~250 `[%browser_only ...]`
  expressions. **None of the 469 bodies call hooks today** (Pattern 3's two
  sites exist only in PR #31653). They are plain browser utilities, and
  several are legitimately called conditionally (`WcToast.re:108` inside a
  runtime switch case, ternary-guarded IIFE in
  `AcademyCourseCertificate.re:84`). This kills "treat every
  `let%browser_only` binding as a hook wrapper by construction": it would
  convert legal conditional calls into hard errors at hundreds of sites.
  Hence the D4 gate below.
- `let%browser_only rec` exists (`ClientDriver__Base.re:342,464`); no
  `and`-chains anywhere.
- `[@platform native]` / `[@platform js]` structure-item attributes (~46
  sites) drop whole items per target; they do not change expression shape
  and need no ppx support.
- `let (v, setV) = switch%platform { | Client => RR.useStateValue(...) | Server => (default, noop) }`
  (`CustomizableNavigationBar.re:418`) motivates D6's static-deps rule.
- `switch%platform` under a runtime `if` inside a `useEffect` callback
  (`WrapperWithToolSidebar.re:179`) must remain conditional — covered by
  D2's "never clear" rule.

## Design (accepted)

Decisions from the design review, replacing the earlier open P1/P2 options.

### D1. Recognition: hardcoded names, exact shapes, silent fallback

The recognized extension names are hardcoded: `platform` and `browser_only`
(verified stable in server-reason-react `packages/browser-ppx/ppx.ml` 0.4.1,
declared via `Extension.V3.declare`). No `-transparent-extensions` flag: the
two extensions need *different* treatments (branch transparency vs. gated
hook-wrapper handling), so a generic name list is the wrong abstraction. A
flag can be added later, non-breaking, if a second framework appears.

Recognized AST shapes:

| Construct | AST | Treatment |
|---|---|---|
| `switch%platform` (expr) | `Pexp_extension ({txt="platform"}, PStr [Pstr_eval (Pexp_match (scrut, cases), _)])` | D2, D3, D6 |
| `[%browser_only e]` (expr) | `Pexp_extension ({txt="browser_only"}, PStr [Pstr_eval (e, _)])` | D5 |
| `let%browser_only ... in body` (expr) | `Pexp_extension ({txt="browser_only"}, PStr [Pstr_eval (Pexp_let (rec_flag, vbs, body), _)])` | D4 |
| `let%browser_only ...` (module) | `Pstr_extension (({txt="browser_only"}, PStr [Pstr_value (rec_flag, vbs)]), _)` | D4 |

Any `platform`/`browser_only` payload not matching these shapes falls back
to today's behavior (default traversal), silently. No payload validation on
our side — `browser_ppx` is the authority on payload validity and errors at
its own pipeline stage; duplicating its checks would create version coupling
for zero user value.

### D2. `%platform` branches are not conditional

When traversing a recognized `%platform` match: traverse the scrutinee and
every case RHS **without** `mark_conditional`, and **never clear** an
already-set conditional flag. Consequences:

- Hooks in `| Client` and `| Server` branches are legal (`MainMenu.re` uses
  `React.useRef` on the server side).
- A real `match`/`if` nested inside a branch still errors (the
  `LandingStickyNavigation` guard).
- A `%platform` switch nested inside a real conditional or an effect
  callback stays conditional (`WrapperWithToolSidebar.re:179`).
- No cross-branch hook-order consistency is required — free, since the ppx
  tracks no hook sequence, only syntactic context.

### D3. Binding classification sees through `%platform`

`classify_binding` treats `let x = switch%platform ...` as a function if
**any** case RHS has a function body ("any", not "all", because one side may
be a stub constant); the existing name/attribute rules then decide
Component / Custom_hook / Function. This fixes Pattern 2 (`UseUrl.re`)
properly — without it, removing the conditional error would just trade it
for an "outside component" lint, and the annotation could not be deleted.
Bare-ident branches (true eta-form) classify as Value, which is harmless: a
bare hook ident is not a call and triggers nothing.

### D4. `let%browser_only` bindings: gated hook-wrapper treatment

A `let%browser_only`-bound function receives the hook treatment **only if
its body contains at least one hook call, or its RHS is itself a hook ident**
(alias form `let%browser_only use = Mod.useThing`). The scan reuses the
existing `has_any_hooks` iterator.

When gated in:

- The binding classifies as a custom hook regardless of name: hooks inside
  belong to custom-hook scope (fixes Pattern 3 without renames).
- The bound name is tracked in a `StringSet` threaded through
  `analysis_state` with the same save/restore discipline as
  `component_scope_bindings`: module-level names are visible for the rest of
  the module, expression-level names only while traversing the `let` body, a
  plain rebinding removes the name (shadowing), and only `Lident` call sites
  are looked up (`Ldot` cross-module calls are invisible — same limitation
  as custom hooks defined in other files).
- A call to a tracked name is linted **exactly** like a hook call: same
  predicate site, same channels (conditional context → hard error, outside
  component/hook scope → lint warning), same `[@disable_order_of_hooks]`
  opt-out on the call expression, same message text. This verifies the
  define-then-call-immediately pattern instead of assuming it.

When gated out (the ~467 non-hook wrappers in the wild): behavior is
completely unchanged — their conditional call sites stay legal, as they
should, since they are not hooks.

`rec` flags and multi-binding lists are handled; the expression-level and
module-level forms route through the same classification code.
`let%browser_only x = useFoo()` with a non-function RHS gets no special
handling: inside a component it already works (Value bindings don't reset
scope); at module level the "outside component" lint is arguably correct.

### D5. `[%browser_only e]` expressions are transparent

Traverse the payload with no added conditionality, and make `get_idents`
recurse into it so exhaustive-deps sees idents inside `%browser_only` effect
callbacks (a pure false-negative fix today). Effect-callback rules still
apply to the contents: a hook called inside
`useEffect([%browser_only () => ...])` remains an error.

### D6. Exhaustive-deps: Client branch only

`get_idents` recurses **only** into the `%platform` case whose pattern
constructor's last name is `Client` (bare or qualified); if no `Client` case
exists, the switch contributes nothing. Rationale: deps arrays only drive
behavior in the client bundle — `useEffect` callbacks never run during SSR,
and server-side `useMemo`/`useCallback` execute once per render pass, so
staleness-across-rerenders (what missing-deps catches) cannot exist on
native. Requiring Server-branch idents in a shared deps array would
manufacture unsatisfiable warnings.

`extract_static_deps_from_binding` applies the same rule: for
`let (v, setV) = switch%platform { | Client => RR.useStateValue(...) | ... }`
the Client branch is inspected so `setV` registers as a stable, omittable
dep (`CustomizableNavigationBar.re:418`).

### D7. `[@platform native]` / `[@platform js]` attributes

No ppx change: the attributes don't alter expression shape and cannot
introduce conditionality. Mentioned in the README for completeness.

### D8. Documentation

README section: platform branches are compile-time-resolved and treated as
non-conditional; nested runtime conditionals still error;
`[@disable_order_of_hooks]` remains the escape hatch for genuine violations
(like the `LandingStickyNavigation` inner switch); deps analysis inside
`%platform` considers the Client branch only.

## Alternatives considered

- **Reorder pps so `browser_ppx` runs first.** Each target would then lint
  only its surviving branch; both branches still get linted across the two
  builds. Rejected: makes lint results depend on pipeline order, breaks
  single-target setups (Melange-only repos never lint the Server branch —
  fine — but native-only builds would lint browser code never emitted),
  and produces locations in rewritten code.
- **User-code rewrites.** For Pattern 1/2 there is no faithful rewrite: the
  hook cannot be hoisted above the platform switch because it must not exist
  in the other bundle (browser-only APIs on the server, and vice versa).
  Patterns 3/4 are partially rewritable (rename to `use*`), which the ahrefs
  monorepo already applied where it was honest to do so.
- **`-transparent-extensions` flag.** Rejected (D1): the two extensions need
  different semantics, so a generic name list cannot express the feature;
  hardcoding two stable names is simpler and a flag stays available later.
- **Transparent `let%browser_only` (hooks belong to enclosing scope).**
  Rejected (D4): without call-site analysis it silently assumes the
  define-then-call-immediately pattern; tracking the bound name and linting
  its call sites verifies the pattern instead.
- **Unconditional hook treatment for `let%browser_only` bindings.** Rejected
  (D4 gate): the monorepo has 469 such bindings, none of which wrap hooks
  today and several of which are called conditionally on purpose; treating
  them all as hooks would create hundreds of false hard errors.
- **Union of branch idents for exhaustive-deps.** Rejected (D6):
  server-only idents cannot always be listed in a shared deps array,
  producing unsatisfiable warnings; Client-branch-only matches the actual
  semantics of deps.

## Test plan (cram tests, `test/*.t`)

1. `platform-switch-hooks.t` — hooks in `| Client` and `| Server` branches
   of `match%platform`; hook call as the whole branch expression bound by
   tuple destructuring (`CustomizableNavigationBar.re:418` shape);
   unconditional hooks before and after the switch in the same component;
   structure-level bare `switch%platform` (`Toast.re:39` shape): no errors.
2. `platform-switch-nested-conditional.t` — a real `match` nested inside a
   `%platform` branch with a hook inside: still errors (guards the
   `LandingStickyNavigation` case). Also the outer direction:
   `if x then switch%platform ...` and a `%platform` switch inside a
   `useEffect` callback stay conditional (`WrapperWithToolSidebar.re:179`
   shape).
3. `platform-switch-hook-values.t` — `let use = match%platform () with ...`
   selecting hook idents (bare eta-form) and lambdas per branch: no errors
   *and* no "outside component" lint (D3).
4. `browser-only-expression.t` — `[%browser_only fun () -> ...]` as a
   `useEffect` callback: no order errors; exhaustive-deps sees idents inside
   the payload (D5); a hook called inside the wrapped callback still errors.
5. `browser-only-binding.t` — expression-level and module-level
   `let%browser_only`, `use*` and non-`use*` names, `rec`, hook-containing
   and hook-free bodies, hook-ident alias RHS: hook-containing bodies get
   custom-hook scope (no errors); hook-free bodies keep today's behavior
   (D4).
6. `browser-only-callsite.t` — conditional call of a tracked name → hard
   error; unconditional call → clean; shadowed name (plain rebinding) → no
   longer tracked; conditional call of a hook-free `%browser_only` name →
   legal (D4 gate).
7. `platform-switch-deps.t` — `switch%platform` inside a `useEffect`
   callback: Client-branch idents required in deps, Server-branch idents
   not; a switch with no `Client` case contributes nothing; a
   useState-in-Client-branch setter registers as a stable dep (D6).
8. `platform-malformed-payload.t` — `if%platform`, empty payload, non-match
   payload: today's behavior, silently (D1).
9. Regression: existing `conditional-hooks.t`, `hooks-at-top-level*.t`,
   `exhaustive-deps*.t` unchanged.

## Rollout

- Version 1.3.0 (feature, non-breaking).
- CHANGES.md note: deps analysis now sees inside `[%browser_only ...]`
  payloads, which can surface *new* missing-deps lint warnings in code that
  was previously invisible to it — relevant when bumping the ppx under
  warnings-as-errors.
- README section per D8.

## Acceptance criteria

With the feature shipped and the ppx bumped in the ahrefs monorepo
(`react-rules-of-hooks-ppx` 1.3.0), the 17 annotations of Patterns 1–3
listed above can be deleted and `make -C frontend build` stays green.
Pattern 4 sites (3) and the `LandingStickyNavigation` inner conditional are
user-code concerns and stay out of scope. The ~467 hook-free
`let%browser_only` bindings and their (sometimes conditional) call sites
must produce zero new diagnostics.
