static x = 42
;;

let y = succ x (* Error: phase mismatch *)
;;

static () = Printf.printf "%d\n" x (* Error: this module is at phase 0 *)
;;

static () = ^Printf.printf "%d\n" x
;;

static x = << string_of_int "42" >>
;;

let () = Printf.printf "%d\n" $x
;;
