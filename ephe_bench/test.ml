module E = Ephemeron.K1
(*
module E = struct
  type ('a, 'b) t = 'a * 'b

  let make k v = (k, v)
end
*)

let size = 50_000
let spread = 1

let keys = Array.init size ref

type tree = Node of (int ref, tree) E.t list

let rec mk n : tree =
  if n = 0 then Node []
  else
    let e = E.make keys.(n) (mk (n - 1)) in
    Node [e]

let () =
  let tree = Array.init spread (fun _ -> mk ((size - 1) / spread)) in
  for _ = 1 to 10 do
    Gc.major ();
    Printf.printf ".%!";
  done;
  ignore (Sys.opaque_identity tree);
  print_newline ();
;;
