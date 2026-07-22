open Ppxlib

val is_hook_name : string -> bool
(** ["use"], or [use] followed by an uppercase letter, ['_'], ['\''] or a digit.
    The same rule as eslint-plugin-react-hooks. *)

val last_component : Longident.t -> string option
(** The last component of a path: [Lident x] and [Ldot (_, x)] give [x],
    [Lapply] gives [None]. *)

val is_hook_ident : Longident.t -> bool
(** [is_hook_name] on the last component of the path. *)

val is_jsx : attributes -> bool
(** JSX elements carry a [@JSX] attribute; they are function applications
    syntactically but are never hook calls. *)

val call_ident : expression -> Longident.t option
(** The callee ident of a function application, excluding JSX elements: the
    candidates for hook calls. *)

val hook_call : expression -> Longident.t option
(** [call_ident] restricted to idents that satisfy [is_hook_ident]. *)

val expression_has_hook_calls : expression -> bool

val structure_has_hook_calls : structure -> bool
(** Early-exit scan used to skip the analysis on hook-free files. *)

(** Hooks that take a dependency array: [useEffect], [useLayoutEffect],
    [useInsertionEffect], [useMemo] and [useCallback], bare or under the
    [React.] prefix, with an optional arity-variant suffix [0]..[7]
    ([useEffect2] takes a 2-tuple of dependencies, ...). *)
module With_deps : sig
  type t = { prefix : string; base : string; variant : int option }

  val decode : string -> t option
  val takes_deps : string -> bool

  val with_variant : t -> int -> string
  (** [with_variant d n] renders [d]'s full name with arity variant [n], e.g.
      [with_variant { prefix = "React."; base = "useEffect"; _ } 2] is
      ["React.useEffect2"]. *)
end
