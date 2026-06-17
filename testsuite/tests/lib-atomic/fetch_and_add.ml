(* TEST
 { bytecode; }
 { native; }
*)

(* Semantics of [Atomic.fetch_and_add], with code shapes deliberately
   chosen to provoke register-allocator coalescing between the result
   and the address / increment arguments of the native
   [Iatomic_fetch_add] instruction (see ocaml/ocaml#14575).

   On an LL/SC backend (arm64, power), if the allocator assigns the
   result the same register as the address, the loop stores through the
   *loaded value*; if it shares with the increment, the increment is
   lost.  Coalescing is only possible when the argument's last use is
   the fetch-and-add itself, hence the [last use] shapes below. *)

let check msg b =
  if not b then begin print_string "FAIL: "; print_endline msg; exit 1 end

(* 1. Returns the OLD value; the new value is visible afterwards. *)
let () =
  let a = Atomic.make 41 in
  check "returns old value" (Atomic.fetch_and_add a 1 = 41);
  check "stores new value" (Atomic.get a = 42)

(* 2. Negative increments. *)
let () =
  let a = Atomic.make 10 in
  check "negative: old" (Atomic.fetch_and_add a (-15) = 10);
  check "negative: new" (Atomic.get a = -5)

(* 3. Wraparound: the tagged-representation arithmetic
      ((2m+1) + 2n) must wrap exactly like native int addition. *)
let () =
  let a = Atomic.make max_int in
  check "wrap max_int: old" (Atomic.fetch_and_add a 1 = max_int);
  check "wrap max_int: new" (Atomic.get a = min_int);
  let b = Atomic.make min_int in
  check "wrap min_int: old" (Atomic.fetch_and_add b (-1) = min_int);
  check "wrap min_int: new" (Atomic.get b = max_int)

(* 4. Address register dies at the instruction.
      [a] is dead after the fetch-and-add, so the allocator is free to
      coalesce the result into the address register.  A miscompiled
      LL/SC sequence typically crashes or corrupts the heap here. *)
let[@inline never] addr_last_use n =
  let a = Atomic.make 1000 in
  Atomic.fetch_and_add a n          (* last use of [a] *)

let () =
  for i = 0 to 999 do
    check "address last-use" (addr_last_use i = 1000)
  done

(* 5. Increment register dies at the instruction. *)
let[@inline never] incr_last_use a =
  let n = Sys.opaque_identity 7 in
  Atomic.fetch_and_add a n          (* last use of [n] *)

let () =
  let a = Atomic.make 0 in
  for i = 0 to 99 do
    check "increment last-use" (incr_last_use a = 7 * i)
  done;
  check "increment last-use: total" (Atomic.get a = 700)

(* 6. Both die: fresh atomic, fresh opaque increment, result returned. *)
let[@inline never] both_last_use () =
  let a = Atomic.make 123 in
  let n = Sys.opaque_identity 5 in
  Atomic.fetch_and_add a n

let () =
  for _ = 1 to 1000 do
    check "both last-use" (both_last_use () = 123)
  done

(* 7. Result discarded (dead-result path; on amd64 this is where an
      unlocked-XADD or lock-ADD shortcut would kick in if ever added). *)
let () =
  let a = Atomic.make 0 in
  for _ = 1 to 1000 do
    ignore (Atomic.fetch_and_add a 3)
  done;
  check "discarded result" (Atomic.get a = 3000)

(* 8. High register pressure around the instruction, forcing spills and
      unusual assignments.  The arithmetic is replicated below to check
      both the returned value and the side effect. *)
let[@inline never] pressure a seed =
  let x0 = seed in
  let x1 = (x0 * 3) + 1 in
  let x2 = x1 lxor 0x55 in
  let x3 = x2 + x0 in
  let x4 = x3 * 7 in
  let x5 = x4 - x1 in
  let x6 = x5 lor 1 in
  let x7 = x6 + x2 in
  let x8 = x7 lxor x3 in
  let x9 = x8 + x4 in
  let x10 = x9 * 5 in
  let x11 = x10 - x5 in
  let old = Atomic.fetch_and_add a x6 in
  old + x0 + x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9 + x10 + x11

let () =
  let a = Atomic.make 100 in
  let seed = Sys.opaque_identity 42 in
  let before = Atomic.get a in
  let r = pressure a seed in
  let after = Atomic.get a in
  (* Reference computation, kept in sync with [pressure]. *)
  let x0 = seed in
  let x1 = (x0 * 3) + 1 in
  let x2 = x1 lxor 0x55 in
  let x3 = x2 + x0 in
  let x4 = x3 * 7 in
  let x5 = x4 - x1 in
  let x6 = x5 lor 1 in
  let x7 = x6 + x2 in
  let x8 = x7 lxor x3 in
  let x9 = x8 + x4 in
  let x10 = x9 * 5 in
  let x11 = x10 - x5 in
  check "pressure: side effect" (after - before = x6);
  check "pressure: result"
    (r = before + x0 + x1 + x2 + x3 + x4 + x5
         + x6 + x7 + x8 + x9 + x10 + x11)

(* 9. Address computed through a data structure (derived pointer /
      computed field address on the Cmm side). *)
let () =
  let arr = Array.init 10 (fun i -> Atomic.make (i * 10)) in
  for i = 0 to 9 do
    check "array cell: old" (Atomic.fetch_and_add arr.(i) 1 = i * 10)
  done;
  for i = 0 to 9 do
    check "array cell: new" (Atomic.get arr.(i) = (i * 10) + 1)
  done

(* 10. Old value flows into further arithmetic (result register kept
       live and used, rather than immediately moved/discarded). *)
let () =
  let a = Atomic.make 0 in
  let total = ref 0 in
  for i = 1 to 100 do
    total := !total + Atomic.fetch_and_add a i
  done;
  (* After adding 1..k, the value is k(k+1)/2; we sum the values
     *before* each addition, i.e. sum_{k=0}^{99} k(k+1)/2. *)
  let expected = ref 0 in
  let acc = ref 0 in
  for i = 1 to 100 do
    expected := !expected + !acc;
    acc := !acc + i
  done;
  check "old value used downstream" (!total = !expected);
  check "final accumulator" (Atomic.get a = 5050)

(* 11. [Atomic.incr] / [Atomic.decr] go through the same primitive. *)
let () =
  let a = Atomic.make 0 in
  for _ = 1 to 500 do Atomic.incr a done;
  for _ = 1 to 200 do Atomic.decr a done;
  check "incr/decr" (Atomic.get a = 300)

let () = print_endline "OK"
