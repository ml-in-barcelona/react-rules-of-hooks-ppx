open Ppxlib

let match_payload (expr : Parsetree.expression) :
    (Parsetree.expression * Parsetree.case list) option =
  match expr.pexp_desc with
  | Pexp_extension
      ( { txt = "platform"; _ },
        PStr
          [
            {
              pstr_desc =
                Pstr_eval ({ pexp_desc = Pexp_match (scrut, cases); _ }, _);
              _;
            };
          ] ) ->
      Some (scrut, cases)
  | _ -> None

let browser_only_payload (expr : Parsetree.expression) :
    Parsetree.expression option =
  match expr.pexp_desc with
  | Pexp_extension
      ( { txt = "browser_only"; _ },
        PStr [ { pstr_desc = Pstr_eval (payload, _); _ } ] ) ->
      Some payload
  | _ -> None

let browser_only_value_bindings (item : Parsetree.structure_item) :
    Parsetree.value_binding list option =
  match item.pstr_desc with
  | Pstr_extension
      ( ( { txt = "browser_only"; _ },
          PStr [ { pstr_desc = Pstr_value (_, vbs); _ } ] ),
        _ ) ->
      Some vbs
  | _ -> None

let rec is_client_pattern (pat : Parsetree.pattern) =
  match pat.ppat_desc with
  | Ppat_construct ({ txt = Lident "Client" | Ldot (_, "Client"); _ }, None) ->
      true
  | Ppat_constraint (p, _) | Ppat_alias (p, _) | Ppat_open (_, p) ->
      is_client_pattern p
  | _ -> false

let client_case (expr : Parsetree.expression) : Parsetree.case option =
  match match_payload expr with
  | Some (_, cases) ->
      List.find_opt (fun case -> is_client_pattern case.pc_lhs) cases
  | None -> None

let client_view (expr : Parsetree.expression) : Parsetree.expression =
  match client_case expr with Some case -> case.pc_rhs | None -> expr
