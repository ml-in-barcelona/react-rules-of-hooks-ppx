(** server-reason-react platform constructs.

    The analysis follows only the code that executes in the browser: the
    [Client] branch of a [%platform match ...] switch and the payload of
    [%browser_only ...]. Every rule about "looking through" these constructs
    lives here — callers never pattern-match the extension payloads themselves.
*)

open Ppxlib

val match_payload : expression -> (expression * case list) option
(** The scrutinee and cases of a [[%platform match ...]] expression. *)

val browser_only_payload : expression -> expression option
(** The payload of a [[%browser_only ...]] expression. *)

val browser_only_value_bindings : structure_item -> value_binding list option
(** The bindings of a top-level [let%browser_only ...] structure item. *)

val client_case : expression -> case option
(** The [Client] branch of a [[%platform match ...]], if the expression is one.
    Recognises the [Client] constructor through module paths, aliases,
    constraints and [Ppat_open]. *)

val client_view : expression -> expression
(** The expression as executed on the client: the body of the [Client] branch
    when the expression is a platform switch, the expression itself otherwise.
*)
