(** Names introduced by patterns, parameters and bindings, and syntactic views
    of function bodies.

    Platform-aware: parameters and labels are collected across [%platform]
    cases, and bodies are found through [%browser_only] payloads and the
    platform [Client] branch, so callers never re-implement that rule. *)

open Ppxlib

val of_pattern : pattern -> string list
(** Every name the pattern binds, through tuples, records, constructors,
    aliases, or-patterns, etc. *)

val of_params : function_param list -> string list

val function_params : expression -> string list
(** All parameter names of a (possibly curried, constrained or
    platform-switched) function expression. *)

val label_names : expression -> string list
(** Labelled/optional argument names of the outermost function. *)

val function_body : expression -> expression option
(** The body of a function expression, looking through constraints and
    [%browser_only]. For [Pfunction_cases] the whole function expression is
    returned (there is no single body). [None] if the expression is not a
    function. *)

val body_of_fun_chain : expression -> expression
(** The innermost body of nested funs and single-case functions, through
    constraints, newtypes and the platform [Client] branch. *)
