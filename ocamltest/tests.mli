(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Sebastien Hinderer, projet Gallium, INRIA Paris            *)
(*                                                                        *)
(*   Copyright 2016 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Definition of tests, built from actions *)

(*
type t = {
  test_name : string;
  test_run_by_default : bool;
  test_actions : Actions.t list;
  test_description : string
}
*)

type code = out_channel -> Environments.t -> Test_result.t * Environments.t

type t = code list

val null : t

module Table : Hashtbl.S with type key = string

type table = t Table.t

val run_by_default : table

val default_tests : unit -> t list

val lookup : string -> t option

val run : out_channel -> Environments.t -> t -> Test_result.t * Environments.t

(*
val test_of_action : Actions.t -> t
*)

module TestSet : Set.S with type elt = t
