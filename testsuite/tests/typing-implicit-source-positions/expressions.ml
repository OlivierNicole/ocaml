(* TEST
   expect;
*)

let x = (fun ?(pos = [%call_pos]) () -> pos) ()
[%%expect{|
val x : lexing_position =
  {pos_fname = ""; pos_lnum = 1; pos_bol = 23; pos_cnum = 31}
|}]

let f = fun ?(call_pos = [%call_pos]) () -> call_pos
[%%expect{|
val f : ?call_pos:[%call_pos] -> unit -> lexing_position = <fun>
|}]

let _ = f ~call_pos:x () ;;
[%%expect{|
- : lexing_position =
{pos_fname = ""; pos_lnum = 1; pos_bol = 23; pos_cnum = 31}
|}]

let _ = "Increment line count"
let _ = f ~call_pos:(f ()) () ;;
[%%expect{|
- : string = "Increment line count"
- : lexing_position =
{pos_fname = ""; pos_lnum = 2; pos_bol = 469; pos_cnum = 489}
|}]
