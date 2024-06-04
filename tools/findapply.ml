let first_elem_printed = ref false

let rec print_apply =
  let print_node typ text arity =
    if !first_elem_printed then
      Format.printf ",@,"
    else
      first_elem_printed := true;
    Format.printf "{\"type\":\"%s\",\"text\":\"%s\",\"arity\":%d}"
      typ
      text
      arity;
  in
  let open Tast_iterator in
  let open Typedtree in
  { default_iterator with
    expr = (fun iter e ->
      match e.exp_desc with
      | Texp_apply (f, args) ->
          let open Format in
          let text =
            asprintf "%a" Pprintast.expression (Untypeast.untype_expression e)
            |> String.escaped
          in
          print_node "apply" text (List.length args);
          (* Recurse on sub-expressions *)
          print_apply.expr iter f;
          List.iter (fun (_label, e) -> Option.iter (print_apply.expr iter) e) args;
      | Texp_construct (_constructor, _desc, args) ->
          let open Format in
          let text =
            asprintf "%a" Pprintast.expression (Untypeast.untype_expression e)
            |> String.escaped
          in
          print_node "construct" text (List.length args);
          (* Recurse on sub-expressions *)
          List.iter (print_apply.expr iter) args;
      | _ ->
          default_iterator.expr iter e
    );
    pat = (fun (type k) iter (pat : k Typedtree.general_pattern) ->
      match pat.pat_desc with
      | Tpat_construct (_ident, _desc, params, _type_annots) ->
          let open Format in
          let text =
            asprintf "%a" Pprintast.pattern (Untypeast.untype_pattern pat)
            |> String.escaped
          in
          print_node "pat_construct" text (List.length params);
          (* Recurse on sub-expressions *)
          List.iter (print_apply.pat iter) params;
      | _ ->
          default_iterator.pat iter pat
    );
  }

let () =
  let filename =
    try Sys.argv.(1) with Failure _ -> invalid_arg "usage: findapply <file>"
  in
  if not (
    Filename.check_suffix filename ".cmt" ||
      Filename.check_suffix filename ".cmti"
  ) then
    invalid_arg "File extension is not `.cmt` or `.cmti`";
  let cmt = Cmt_format.read_cmt filename in
  match cmt.Cmt_format.cmt_annots with
  | Cmt_format.Implementation typedtree ->
      Format.printf "@[<v>@[<v 2>[@,";
      print_apply.structure print_apply typedtree;
      Format.printf "@]@,]@]";
  | Cmt_format.Interface _ ->
      invalid_arg "expected implementation, got signature"
  | _ -> assert false
