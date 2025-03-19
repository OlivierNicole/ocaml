(* TEST
   native-compiler;
   setup-ocamlopt.byte-build-env;
   set BUILD_PATH_PREFIX_MAP="app/foo=${test_build_directory}";
   ocamlopt.byte;
   run;
   check-program-output;
*)

let f = fun ?(call_pos = [%call_pos]) () -> call_pos
let _ = print_endline (f ()).pos_fname;;
