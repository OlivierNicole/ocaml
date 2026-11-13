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

type code = out_channel -> Environments.t -> Test_result.t * Environments.t

type t = code list

let null = []

module Table = Hashtbl.Make(String)

type table = t Table.t

let

let run_actions log testenv actions =
  let total = List.length actions in
  let rec run_actions_aux action_number env = function
    | [] -> (Test_result.pass, env)
    | action::remaining_actions ->
      begin
        Printf.fprintf log "\nRunning action %d/%d (%s)\n%!"
          action_number total (Actions.name action);
        let (result, env') = Actions.run log env action in
        Printf.fprintf log "Action %d/%d (%s) %s\n%!"
          action_number total (Actions.name action)
          (Test_result.string_of_result result);
        if Test_result.is_pass result
        then run_actions_aux (action_number+1) env' remaining_actions
        else (result, env')
      end in
  run_actions_aux 1 testenv actions

let run log env test =
  Printf.fprintf log "Running test %s with %d actions\n%!"
    test.test_name
    (List.length test.test_actions);
  run_actions log env test.test_actions

module TestSet = Set.Make
(struct
  type nonrec t = t
  let compare = compare
end)
