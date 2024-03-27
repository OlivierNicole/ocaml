(* TEST
 readonly_files = "contexts_1.ml contexts_2.ml contexts_3.ml";
 flags = "-dsource -dlambda";
 expect;
*)

#use "contexts_1.ml";;
(* Notice that (field_mut 1 input) occurs twice, it
   is evaluated once in the 'false' branch and once in the 'true'
   branch. The compiler does not assume that its static knowledge about the
   first read (it cannot be a [Right] as we already matched against it
   and failed) also applies to the second read, and it inserts a Match_failure
   case if [Right] is read again.
*)
[%%expect {|

#use  "contexts_1.ml";;

type u = {
  a: bool ;
  mutable b: (bool, int) Either.t };;
0
type u = { a : bool; mutable b : (bool, int) Either.t; }

let example_1 () =
  let input = { a = true; b = (Either.Left true) } in
  match input with
  | { a = false; b = _ } -> Result.Error 1
  | { a = _; b = Either.Right _ } -> Result.Error 2
  | { a = _; b = _ } when input.b <- (Either.Right 3); false ->
      Result.Error 3
  | { a = true; b = Either.Left y } -> Result.Ok y;;
(let
<<<<<<< HEAD
  (example_1/311 =
     (function param/335[int]
       (let (input/313 = (makemutable 0 (int,*) 1 [0: 1]))
         (if (field_int 0 input/313)
           (let (*match*/338 =o (field_mut 1 input/313))
             (switch* *match*/338
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
  (example_1/310 =
     (function param/334[int]
       (let (input/312 = (makemutable 0 (int,*) 1 [0: 1]))
         (if (field_int 0 input/312)
           (let (*match*/337 =o (field_mut 1 input/312))
             (switch* *match*/337
=======
  (example_1/312 =
     (function param/336[int]
       (let (input/314 = (makemutable 0 (int,*) 1 [0: 1]))
         (if (field_int 0 input/314)
           (let (*match*/339 =o (field_mut 1 input/314))
             (switch* *match*/339
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
              case tag 0:
<<<<<<< HEAD
               (if (seq (setfield_ptr 1 input/313 [1: 3]) 0) [1: 3]
                 (let (*match*/340 =o (field_mut 1 input/313))
                   (switch* *match*/340
                    case tag 0: (makeblock 0 (int) (field_imm 0 *match*/340))
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
               (if (seq (setfield_ptr 1 input/312 [1: 3]) 0) [1: 3]
                 (let (*match*/339 =o (field_mut 1 input/312))
                   (switch* *match*/339
                    case tag 0: (makeblock 0 (int) (field_imm 0 *match*/339))
=======
               (if (seq (setfield_ptr 1 input/314 [1: 3]) 0) [1: 3]
                 (let (*match*/341 =o (field_mut 1 input/314))
                   (switch* *match*/341
                    case tag 0: (makeblock 0 (int) (field_imm 0 *match*/341))
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
                    case tag 1:
                     (raise
<<<<<<< HEAD
                       (makeblock 0 (global Match_failure/20!)
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
                       (makeblock 0 (global Match_failure/18!)
=======
                       (makeblock 0 (global Match_failure/19!)
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
                         [0: "contexts_1.ml" 17 2])))))
              case tag 1: [1: 2]))
           [1: 1]))))
<<<<<<< HEAD
  (apply (field_mut 1 (global Toploop!)) "example_1" example_1/311))
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
  (apply (field_mut 1 (global Toploop!)) "example_1" example_1/310))
=======
  (apply (field_mut 1 (global Toploop!)) "example_1" example_1/312))
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
val example_1 : unit -> (bool, int) Result.t = <fun>
|}]

#use "contexts_2.ml";;
[%%expect {|

#use  "contexts_2.ml";;

type 'a myref = {
  mutable mut: 'a };;
0
type 'a myref = { mutable mut : 'a; }

type u = {
  a: bool ;
  b: (bool, int) Either.t myref };;
0
type u = { a : bool; b : (bool, int) Either.t myref; }

let example_2 () =
  let input = { a = true; b = { mut = (Either.Left true) } } in
  match input with
  | { a = false; b = _ } -> Result.Error 1
  | { a = _; b = { mut = Either.Right _ } } -> Result.Error 2
  | { a = _; b = _ } when (input.b).mut <- (Either.Right 3); false ->
      Result.Error 3
  | { a = true; b = { mut = Either.Left y } } -> Result.Ok y;;
(let
<<<<<<< HEAD
  (example_2/347 =
     (function param/351[int]
       (let (input/349 = (makeblock 0 (int,*) 1 (makemutable 0 [0: 1])))
         (if (field_int 0 input/349)
           (let (*match*/355 =o (field_mut 0 (field_imm 1 input/349)))
             (switch* *match*/355
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
  (example_2/346 =
     (function param/350[int]
       (let (input/348 = (makeblock 0 (int,*) 1 (makemutable 0 [0: 1])))
         (if (field_int 0 input/348)
           (let (*match*/354 =o (field_mut 0 (field_imm 1 input/348)))
             (switch* *match*/354
=======
  (example_2/348 =
     (function param/352[int]
       (let (input/350 = (makeblock 0 (int,*) 1 (makemutable 0 [0: 1])))
         (if (field_int 0 input/350)
           (let (*match*/356 =o (field_mut 0 (field_imm 1 input/350)))
             (switch* *match*/356
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
              case tag 0:
<<<<<<< HEAD
               (if (seq (setfield_ptr 0 (field_imm 1 input/349) [1: 3]) 0)
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
               (if (seq (setfield_ptr 0 (field_imm 1 input/348) [1: 3]) 0)
=======
               (if (seq (setfield_ptr 0 (field_imm 1 input/350) [1: 3]) 0)
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
                 [1: 3]
<<<<<<< HEAD
                 (let (*match*/358 =o (field_mut 0 (field_imm 1 input/349)))
                   (switch* *match*/358
                    case tag 0: (makeblock 0 (int) (field_imm 0 *match*/358))
                    case tag 1:
                     (raise
                       (makeblock 0 (global Match_failure/20!)
                         [0: "contexts_2.ml" 11 2])))))
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
                 (let (*match*/357 =o (field_mut 0 (field_imm 1 input/348)))
                   (makeblock 0 (int) (field_imm 0 *match*/357))))
=======
                 (let (*match*/359 =o (field_mut 0 (field_imm 1 input/350)))
                   (makeblock 0 (int) (field_imm 0 *match*/359))))
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
              case tag 1: [1: 2]))
           [1: 1]))))
<<<<<<< HEAD
  (apply (field_mut 1 (global Toploop!)) "example_2" example_2/347))
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
  (apply (field_mut 1 (global Toploop!)) "example_2" example_2/346))
=======
  (apply (field_mut 1 (global Toploop!)) "example_2" example_2/348))
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
val example_2 : unit -> (bool, int) Result.t = <fun>
|}]

#use "contexts_3.ml";;
[%%expect {|

#use  "contexts_3.ml";;

type 'a myref = {
  mutable mut: 'a };;
0
type 'a myref = { mutable mut : 'a; }

type u = (bool * (bool, int) Either.t) myref;;
0
type u = (bool * (bool, int) Either.t) myref

let example_3 () =
  let input = { mut = (true, (Either.Left true)) } in
  match input with
  | { mut = (false, _) } -> Result.Error 1
  | { mut = (_, Either.Right _) } -> Result.Error 2
  | { mut = (_, _) } when input.mut <- (true, (Either.Right 3)); false ->
      Result.Error 3
  | { mut = (true, Either.Left y) } -> Result.Ok y;;
(let
<<<<<<< HEAD
  (example_3/364 =
     (function param/368[int]
       (let (input/366 =mut [0: 1 [0: 1]] *match*/369 =o *input/366)
         (if (field_imm 0 *match*/369)
           (switch* (field_imm 1 *match*/369)
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
  (example_3/363 =
     (function param/367[int]
       (let (input/365 =mut [0: 1 [0: 1]] *match*/368 =o *input/365)
         (if (field_imm 0 *match*/368)
           (switch* (field_imm 1 *match*/368)
=======
  (example_3/365 =
     (function param/369[int]
       (let (input/367 =mut [0: 1 [0: 1]] *match*/370 =o *input/367)
         (if (field_imm 0 *match*/370)
           (switch* (field_imm 1 *match*/370)
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
            case tag 0:
<<<<<<< HEAD
             (if (seq (assign input/366 [0: 1 [1: 3]]) 0) [1: 3]
               (makeblock 0 (int) (field_imm 0 (field_imm 1 *match*/369))))
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
             (if (seq (assign input/365 [0: 1 [1: 3]]) 0) [1: 3]
               (makeblock 0 (int) (field_imm 0 (field_imm 1 *match*/368))))
=======
             (if (seq (assign input/367 [0: 1 [1: 3]]) 0) [1: 3]
               (makeblock 0 (int) (field_imm 0 (field_imm 1 *match*/370))))
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
            case tag 1: [1: 2])
           [1: 1]))))
<<<<<<< HEAD
  (apply (field_mut 1 (global Toploop!)) "example_3" example_3/364))
||||||| parent of 3b8d1ddfc8 (Immutable array tests)
  (apply (field_mut 1 (global Toploop!)) "example_3" example_3/363))
=======
  (apply (field_mut 1 (global Toploop!)) "example_3" example_3/365))
>>>>>>> 3b8d1ddfc8 (Immutable array tests)
val example_3 : unit -> (bool, int) Result.t = <fun>
|}]
