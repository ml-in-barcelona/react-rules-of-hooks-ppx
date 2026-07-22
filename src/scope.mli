(** Binding-scope tracking for the analysis.

    Tracks, at each point of the traversal:
    - {b component bindings} — names bound inside the current component or
      custom hook: the candidate dependencies;
    - {b outer bindings} — names bound at the module level: constant between
      renders, never valid dependencies;
    - {b static deps} — names that are referentially stable ([Stable]) and hence
      omittable from dependency arrays;
    - {b stable wrappers} — locally-defined hooks that inherit a stability
      shape;
    - {b browser-only hooks} — names bound by [%browser_only] hook wrappers,
      which count as hook calls for the rules of hooks.

    Protocol, mirrored by the traversal in [Ppx]:
    + [enter_binding] when a value binding is met: the bound names shadow any
      stale stable/browser-only info, plain bindings are routed to component or
      outer scope, and stability facts are recorded;
    + [binding_body] before traversing the binding's body: a Component or
      Custom_hook opens a fresh scope (its parameters become the component
      bindings, static deps reset);
    + [exit_binding] after the body: a Component/Custom_hook discards the scope
      it opened (restoring the state recorded at [enter_binding]); other kinds
      keep the traversed state. Outer bindings and browser-only hooks always
      persist. *)

open Ppxlib

type t
type kind = Component | Custom_hook | Function | Value

val classify : value_binding -> kind
(** [Component] for [@react.component], [@react.client.component] or
    [@react.async.component] function bindings (also detected across [%platform]
    cases), [Custom_hook] for function bindings named like a hook, [Function]
    for other functions, [Value] otherwise. *)

val initial : t
val enter_binding : kind -> in_component_or_hook:bool -> value_binding -> t -> t
val binding_body : kind -> value_binding -> t -> t
val exit_binding : kind -> entered:t -> traversed:t -> t
val static_deps : t -> Set.Make(String).t
val outer_bindings : t -> Set.Make(String).t
val component_bindings : t -> Set.Make(String).t

val is_browser_only_hook_wrapper : value_binding -> bool
(** A [%browser_only] binding that wraps a hook: either a function whose body
    calls hooks, or a direct alias of a hook. *)

val track_browser_only_wrappers : value_binding list -> t -> t
(** Record the names of the browser-only hook wrappers among [vbs]. *)

val is_tracked_browser_only_hook : t -> Longident.t -> bool

val browser_only_snapshot : t -> Set.Make(String).t
(** Pair with [restore_browser_only] to scope browser-only tracking to an
    expression-level [let%browser_only ... in ...]. *)

val restore_browser_only : Set.Make(String).t -> t -> t
