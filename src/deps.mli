open Ppxlib

type path = { root : Longident.t; fields : string list }
type t = { used_paths : path list; bound_names : string list }

val of_expression : expression -> t

val path_of_expression : expression -> path option
(** [path_of_expression e] is the dependency path of [e] when it is a plain
    field chain over an identifier (allowing type constraints), [None]
    otherwise. Field labels must be unqualified: [x.M.f] is not a path and
    degrades to [x]. *)

val root_name : path -> string
(** Name of the path's root identifier, e.g. ["Module.value"] for a qualified
    root. *)

val is_qualified : path -> bool
(** Whether the path's root is module-qualified. *)

val path_to_string : path -> string
(** Rendering for diagnostics and corrections, e.g. ["input.page"]. *)

val is_prefix : prefix:path -> path:path -> bool
(** [is_prefix ~prefix ~path] holds when [prefix] covers [path]: same root (by
    name) and [prefix]'s fields are a prefix of [path]'s. A declared
    [input.page] covers a use of [input.page.size] but not [input.limit] and not
    bare [input]. *)

val is_strict_prefix : prefix:path -> path:path -> bool
(** Like {!is_prefix} but excluding equal paths: [input] strictly prefixes
    [input.page] but not [input]. *)
