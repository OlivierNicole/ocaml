(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                      Anmol Sahoo, Purdue University                    *)
(*                                                                        *)
(*   Copyright 2022 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Asttypes
open Cmm
module V = Backend_var
module VP = Backend_var.With_provenance

type read_or_write = Read | Write

let init_code () =
  Cmm_helpers.return_unit Debuginfo.none @@
  Cop (Cextcall ("__tsan_init", typ_void, [], false), [], Debuginfo.none)

let bit_size memory_chunk =
  match memory_chunk with
  | Byte_unsigned
  | Byte_signed -> 8
  | Sixteen_unsigned
  | Sixteen_signed -> 16
  | Thirtytwo_unsigned
  | Thirtytwo_signed -> 32
  | Word_int
  | Word_val -> Sys.word_size
  | Single -> 32
  | Double -> 64

let select_function read_or_write memory_chunk =
  let bit_size = bit_size memory_chunk in
  let acc_string =
    match read_or_write with Read -> "read" | Write -> "write"
  in
  Printf.sprintf "__tsan_%s%d" acc_string (bit_size / 8)

module TSan_memory_order = struct
  (* Constants defined in the LLVM ABI *)
  let acquire = Cconst_int (2, Debuginfo.none)
end

let machtype_of_memory_chunk = function
  | Byte_unsigned
  | Byte_signed
  | Sixteen_unsigned
  | Sixteen_signed
  | Thirtytwo_unsigned
  | Thirtytwo_signed
  | Word_int -> typ_int
  | Word_val -> typ_val
  | Single
  | Double -> typ_float

let dbg_none = Debuginfo.none

(* Decides whether an expression {i probably} evaluates to a value of type
   [Addr]. This is not intended to be foolproof, but only aims to catch the
   cases that should happen in practice. *)
let rec has_type_addr = function
  | Cconst_int (_, _) | Cconst_natint (_, _) | Cconst_float (_, _)
  | Cconst_symbol (_, _) | Cassign (_, _) | Ctuple _ | Cswitch (_, _, _, _)
  | Ccatch (_, _, _) | Cexit (_, _) | Ctrywith (_, _, _, _) | Creturn_addr
  | Cvar _ -> false
  | Clet (_, _, body)
  | Clet_mut (_, _, _, body)
  | Cphantom_let (_, _, body) -> has_type_addr body
  | Csequence (_, e) -> has_type_addr e
  | Cifthenelse (_, _, e1, _, e2, _) -> has_type_addr e1 || has_type_addr e2
  | Cop (op, _, _) ->
      begin match op with
      | Capply [|Addr|] | Cextcall (_, [|Addr|], _, _) | Cadda -> true
      | Capply _ | Cextcall _ | Cload _ | Calloc | Cstore (_, _) | Caddi | Csubi
      | Cmuli | Cmulhi | Cdivi | Cmodi | Cand | Cor | Cxor | Clsl | Clsr | Casr
      | Ccmpi _ | Caddv | Ccmpa _ | Cnegf | Cabsf | Caddf | Csubf | Cmulf
      | Cdivf | Cfloatofint | Cintoffloat | Ccmpf _ | Craise _ | Ccheckbound
      | Copaque | Cdls_get -> false
      end

type replace_or_not = Keep of Cmm.expression | Replace of VP.t * Cmm.expression

let wrap_entry_exit expr =
  let call_entry =
    Cmm_helpers.return_unit dbg_none @@
    Cop
      (Cextcall ("__tsan_func_entry", typ_void, [], false),
       [Creturn_addr],
       dbg_none)
  in
  let call_exit = Cmm_helpers.return_unit dbg_none @@ Cop (
      Cextcall ("__tsan_func_exit", typ_void, [], false), [], dbg_none)
  in
  (* [is_tail] is true when the expression is in tail position *)
  let rec insert_call_exit is_tail = function
    | Clet (v, e, body) -> Clet (v, e, insert_call_exit is_tail body)
    | Clet_mut (v, typ, e, body) ->
        Clet_mut (v, typ, e, insert_call_exit is_tail body)
    | Cphantom_let (v, e, body) ->
        Cphantom_let (v, e, insert_call_exit is_tail body)
    | Cassign (v, body) -> Cassign (v, insert_call_exit is_tail body)
    | Csequence (op1, op2) -> Csequence (op1, insert_call_exit is_tail op2)
    | Cifthenelse (cond, t_dbg, t, f_dbg, f, dbg_none) ->
        Cifthenelse (cond, t_dbg, insert_call_exit is_tail t, f_dbg,
          insert_call_exit is_tail f, dbg_none)
    | Cswitch (e, cases, handlers, dbg_none) ->
        let handlers = Array.map
          (fun (handler, handler_dbg) ->
            (insert_call_exit is_tail handler, handler_dbg))
          handlers
        in
        Cswitch (e, cases, handlers, dbg_none)
    | Ccatch (isrec, handlers, next) ->
        let handlers = List.map
            (fun (id, args, e, dbg_none) ->
              (id, args, insert_call_exit is_tail e, dbg_none))
            handlers
        in
        Ccatch (isrec, handlers, insert_call_exit is_tail next)
    | Cexit (ex, args) ->
        (* A [Cexit] is like a goto to the beginning of a handler. Therefore,
           it is never the last thing evaluated in a function; there is no need
           to insert a call to [__tsan_func_exit] here. *)
        Cexit (ex, args)
    | Ctrywith (e, v, handler, dbg_none) ->
        (* We need to insert a call to [__tsan_func_exit] at the tail of both
           the body and the handler. If this is a [try ... with] in tail
           position, then the body expression is not in tail position (as code
           is inserted at the end of it to pop the exception handler), the
           handler expression is. *)
        Ctrywith
          (insert_call_exit false e,
           v,
           insert_call_exit is_tail handler,
           dbg_none)
    | Cop (Capply fn, args, dbg_none) when is_tail ->
        (* This is a tail call. We insert the call to [__tsan_func_exit] right
           before the call, but after evaluating the arguments. We make an
           exception for arguments which evaluate to a value of type [Addr], as
           such values should never be live across a function call or
           allocation point. *)
        let fun_ = List.hd args in
        let replace_args =
          List.map
            (fun e ->
              if has_type_addr e
              then Keep e
              else Replace (VP.create (V.create_local "arg"), e))
            (List.tl args)
        in
        let tail =
          Csequence
            (call_exit,
             (Cop
              (Capply fn,
               fun_
               :: List.map
                    (function
                      | Replace (id,_) -> Cvar (VP.var id)
                      | Keep e -> e)
                    replace_args,
                dbg_none)))
        in
        List.fold_right
          (fun keep_or_replace acc ->
            match keep_or_replace with
            | Keep _ -> acc
            | Replace (id,arg) -> Clet (id, arg, acc))
          replace_args
          tail
    | Cconst_int (_, _) | Cconst_natint (_, _) | Cconst_float (_, _)
    | Cconst_symbol (_, _) | Cvar _ | Ctuple _ | Cop (_, _, _)
    | Creturn_addr as expr ->
        let id = VP.create (V.create_local "res") in
        Clet (id, expr, Csequence (call_exit, Cvar (VP.var id)))
  in
  Csequence (call_entry, insert_call_exit true expr)

let instrument _label body =
  let rec aux = function
    | Cop (Cload {memory_chunk; mutability=Mutable; is_atomic=false} as load_op,
            [loc], dbginfo) ->
        (* Emit a call to [__tsan_readN] before the load *)
        let loc_id = VP.create (V.create_local "loc") in
        let loc_exp = Cvar (VP.var loc_id) in
        Clet (loc_id, loc,
          Csequence
            (Cmm_helpers.return_unit dbg_none (Cop
              (Cextcall (select_function Read memory_chunk, typ_void,
                          [], false),
                [loc_exp], dbg_none)),
            Cop (load_op, [loc_exp], dbginfo)))
    | Cop (Cload {memory_chunk; mutability=Mutable; is_atomic=true},
            [loc], dbginfo) ->
        (* Replace the atomic load with a call to [__tsan_atomicN_load] *)
        let ret_typ = machtype_of_memory_chunk memory_chunk in
        Cop (Cextcall
               (Printf.sprintf "__tsan_atomic%d_load" (bit_size memory_chunk),
               ret_typ, [], false),
          [loc; TSan_memory_order.acquire], dbginfo)
    | Cop (Cload {memory_chunk=_; mutability=Mutable; is_atomic=_},
            _ :: _, _) ->
        invalid_arg "instrument: wrong number of arguments for operation Cload"
    | Cop (Cstore(memory_chunk, init_or_assn), [loc;v], dbginfo) as c ->
        (* Emit a call to [__tsan_writeN] before the store *)
        begin match init_or_assn with
        | Assignment ->
            (* We make sure that 1. the location and value expressions are
               evaluated before the call to TSan, and 2. the location
               expression is evaluated right before that call, as it might not
               be a valid OCaml value (e.g. a pointer into an array), in which
               case it must not be live across a function call or allocation
               point. *)
            let loc_id = VP.create (V.create_local "loc") in
            let loc_exp = Cvar (VP.var loc_id) in
            let v_id = VP.create (V.create_local "newval") in
            let v_exp = Cvar (VP.var v_id) in
            let args = [loc_exp; v_exp] in
            Clet (v_id, v,
              Clet (loc_id, loc,
                Csequence
                  (Cmm_helpers.return_unit dbg_none (Cop (Cextcall
                         (select_function Write memory_chunk, typ_void, [],
                           false),
                         [loc_exp], dbg_none)),
                  Cop (Cstore (memory_chunk, init_or_assn), args, dbginfo))))
        | Heap_initialization | Root_initialization ->
            (* Initializing writes need not be instrumented as they are always
               domain-safe *)
            c
        end
    | Cop (Cstore _, _, _) ->
        invalid_arg "instrument: wrong number of arguments for operation Cstore"
    | Cop (op, es, dbg_none) -> Cop (op, List.map aux es, dbg_none)
    | Clet (v, e, body) -> Clet (v, aux e, aux body)
    | Clet_mut (v, k, e, body) -> Clet_mut (v, k, aux e, aux body)
    | Cphantom_let (v, e, body) -> Cphantom_let (v, e, aux body)
    | Cassign (v, e) -> Cassign (v, aux e)
    | Ctuple es -> Ctuple (List.map aux es)
    | Csequence(c1,c2) -> Csequence(aux c1, aux c2)
    | Ccatch (isrec, cases, body) ->
        let cases =
          List.map (fun (nfail, ids, e, dbg_none) ->
            (nfail, ids, aux e, dbg_none))
          cases
        in
        Ccatch (isrec, cases, aux body)
    | Cexit (ex, args) -> Cexit (ex, List.map aux args)
    | Cifthenelse (cond, t_dbg, t, f_dbg, f, dbg_none) ->
        Cifthenelse (aux cond, t_dbg, aux t, f_dbg, aux f, dbg_none)
    | Ctrywith (e, ex, handler, dbg_none) ->
        Ctrywith (aux e, ex, aux handler, dbg_none)
    | Cswitch (e, cases, handlers, dbg_none) ->
        let handlers =
          handlers |> Array.map (fun (handler, handler_dbg) ->
                                  (aux handler, handler_dbg))
        in
        Cswitch(aux e, cases, handlers, dbg_none)
    (* no instrumentation *)
    | Cconst_int _ | Cconst_natint _ | Cconst_float _
    | Cconst_symbol _ | Cvar _ | Creturn_addr as c -> c
  in
  body |> aux |> wrap_entry_exit
