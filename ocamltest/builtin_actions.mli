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

(* Definition of a few built-in actions *)

val pass : Tests.t
val skip : Tests.t
val fail : Tests.t

val dumpenv : Tests.t

val hasunix : Tests.t
val libunix : Tests.t
val libwin32unix : Tests.t

val windows : Tests.t
val bsd : Tests.t

val arch32 : Tests.t
val arch64 : Tests.t

(** Whether the compiler target is POWER architecture. *)
val arch_power : Tests.t

val has_symlink : Tests.t

val setup_build_env : Tests.t

val setup_simple_build_env : Tests.t

val run : Tests.t
val script : Tests.t

val check_program_output : Tests.t

val file_exists : Tests.t

val copy : Tests.t
