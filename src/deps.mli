(** Member-path dependency extraction for exhaustive-deps.

    Given a hook callback (or a dependency array), collect the dependency paths
    it uses and the names it binds locally; the difference is what a dependency
    array must cover. Follows only client-executed code across platform
    constructs ([%platform] Client branch, [%browser_only] payload).

    A path is a chain of record-field accesses over a (possibly
    module-qualified) identifier: [input.page.size] is root [input] with fields
    [["page"; "size"]]. Module qualification ([Module.value]) is part of the
    root, never a field step. Any expression that is not a plain field chain
    degrades to the paths of its sub-expressions. A field assignment [r.x <- e]
    counts as a use of the written path [r.x] (so stable roots exempt writes
    through them) plus the uses of [e].

    Both lists preserve source order and may contain duplicates; callers dedupe
    as needed. Operators are not collected. *)

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
