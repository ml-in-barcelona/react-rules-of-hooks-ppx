(** Referentially-stable values returned by hooks (see STABLE_HOOKS.md).

    React guarantees stability for [useState]'s setter, [useReducer]'s dispatch
    and the [useRef] box, so they never need to appear in a dependency array.
    Stability propagates through local hook wrappers
    ([let useX = ... useState ...]), and a [setX] / [dispatch...] naming
    convention covers values returned by custom hooks.

    Callers provide already-known stable wrappers through the [lookup] function;
    scope tracking owns that table. *)

open Ppxlib

type shape =
  | Snd
      (** the second element of the returned tuple is stable ([useState],
          [useReducer]) *)
  | All  (** every name bound from the call is stable ([useRef]) *)

val shape_of_call :
  lookup:(string -> shape option) -> expression -> shape option
(** The stability shape of a hook call expression: hardcoded for
    [useState]/[useReducer]/[useRef] (bare or [React.]-prefixed), [lookup] for
    locally-defined stable wrappers. *)

val wrapper_shape :
  lookup:(string -> shape option) -> value_binding -> (string * shape) option
(** [let useX = ...] whose fun-chain body is a stable hook call: a local hook
    wrapper that inherits the callee's stability shape. *)

val static_deps_of_binding :
  lookup:(string -> shape option) -> value_binding -> string list
(** The names bound by a value binding that are referentially stable and hence
    omittable from dependency arrays. Looks through the platform [Client]
    branch. For calls to unknown custom hooks, falls back to the setter naming
    convention on the second tuple element and on record fields. *)
