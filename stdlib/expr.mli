static val of_int : int -> int expr
static val of_float : float -> float expr
val foo : int
static val of_string : string -> string expr
static val of_list : ('a -> 'a expr) -> 'a list -> 'a list expr
