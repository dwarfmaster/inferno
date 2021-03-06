(******************************************************************************)
(*                                                                            *)
(*                                  Inferno                                   *)
(*                                                                            *)
(*                       François Pottier, Inria Paris                        *)
(*                                                                            *)
(*  Copyright Inria. All rights reserved. This file is distributed under the  *)
(*  terms of the MIT License, as described in the file LICENSE.               *)
(*                                                                            *)
(******************************************************************************)

open UnifierSig
open SolverSig

module Make
  (X : TEVAR)
  (S : STRUCTURE)
  (O : OUTPUT with type 'a structure = 'a S.structure)
= struct

(* -------------------------------------------------------------------------- *)

(* We rely on the low-level solver interface. *)

module Lo =
  SolverLo.Make(X)(S)(O)

open Lo

type variable =
  Lo.variable

(* -------------------------------------------------------------------------- *)

(* We now set up the applicative functor API, or combinator API, to the
   solver. The constraint construction phase and the witness decoding phase
   are packaged together, with two benefits: 1- the syntax of constraints and
   witnesses, as well as the details of write-once references, are hidden; 2-
   the client can write code in a compositional and declarative style, under
   the illusion that constructing a query immediately gives rise to an
   answer. *)

(* The client is allowed to construct objects of type ['a co]. Such an object is
   a pair of a constraint and a continuation. It is evaluated in two phases. In
   the first phase, the constraint is solved. In the second phase, the continuation
   is invoked. It is allowed to examine the witness, and must produce a value of
   type ['a]. *)

(* The continuation has access to an environment of type [env]. For the moment,
   the environment is just a type decoder. *)

type env =
  decoder

type 'a co =
  rawco * (env -> 'a)

(* -------------------------------------------------------------------------- *)

(* The type ['a co] forms an applicative functor. *)

let pure a =
  CTrue,
  fun _env -> a

let (^&) (rc1, k1) (rc2, k2) =
  CConj (rc1, rc2),
  fun env -> (k1 env, k2 env)

let map f (rc, k) =
  rc,
  fun env -> f (k env)

(* The function [<$$>] is just [map] with reversed argument order. *)

let (<$$>) a f =
  map f a

(* The function [^^], a variation of [^&], also builds a conjunction constraint,
   but drops the first component of the resulting pair, and keeps only the second
   component. [f ^^ g] is equivalent to [f ^& g <$$> snd]. *)

let (^^) (rc1, k1) (rc2, k2) =
  CConj (rc1, rc2),
  fun env ->
    let _ = k1 env in
    k2 env

(* The type ['a co] does not form a monad. Indeed, there is no way of defining
   a [bind] combinator. *)

(* A note on syntax. We need [--] to bind tighter than [^&], which in turn
   must bind tighter than [<$$>]. This explains in part our choice of operator
   names. *)

(* -------------------------------------------------------------------------- *)

(* Existential quantification. *)

let exist_aux t f =
  (* Create a fresh unifier variable [v]. *)
  let v = fresh t in
  (* Pass [v] to the client. *)
  let rc, k = f v in
  (* Wrap the constraint [c] in an existential quantifier, *)
  CExist (v, rc),
  (* and construct a continuation which returns a pair of the witness for [v]
     and the value of the underlying continuation [k]. *)
  fun env ->
    let decode = env in
    (decode v, k env)

let exist f =
  exist_aux None f

let construct t f =
  exist_aux (Some t) f

let exist_aux_ t f =
  let v = fresh t in
  let rc, k = f v in
  CExist (v, rc),
  (* Keep the original continuation. The client doesn't need the witness. *)
  k

let exist_ f =
  exist_aux_ None f
  (* This is logically equivalent to [exist f <$$> snd], but saves a
     call to [decode] as well as some memory allocation. *)

let construct_ t f =
  exist_aux_ (Some t) f

let lift f v1 t2 =
  construct_ t2 (fun v2 ->
    f v1 v2
  )

(* -------------------------------------------------------------------------- *)

(* Deep types. *)

type deep_ty =
  | DeepVar of variable
  | DeepStructure of deep_ty S.structure

(* Conversion of deep types to shallow types. *)

(* Our API is so constrained that this seems extremely difficult to implement
   from the outside. So, we provide it, for the user's convenience. In fact,
   even here, inside the abstraction, implementing this conversion is slightly
   tricky. *)

let build dty f =
  (* Accumulate a list of the fresh variables that we create. *)
  let vs = ref [] in
  (* [convert] converts a deep type to a variable. *)
  let rec convert dty =
    match dty with
    | DeepVar v ->
        v
    | DeepStructure s ->
        (* First recursively convert our children, then allocate a fresh
           variable [v] to stand for the root. Record its existence in the
           list [vs]. *)
        let v = fresh (Some (S.map convert s)) in
        vs := v :: !vs;
        v
  in
  (* Convert the deep type [dty] and pass the variable that stands for its
     root the user function [f]. *)
  let rc, k = f (convert dty) in
  (* Then, create a bunch of existential quantifiers, in an arbitrary order. *)
  List.fold_left (fun rc v -> CExist (v, rc)) rc !vs,
  (* Keep an unchanged continuation. *)
  k

(* -------------------------------------------------------------------------- *)

(* Equations. *)

let (--) v1 v2 =
  CEq (v1, v2),
  fun _env -> ()

let (---) v t =
  lift (--) v t

(* If [construct_] was not exposed, [lift] could also be defined (outside this
   module) in terms of [exist_] and [---], as follows. This definition seems
   slower, though; its impact on the test suite is quite large. *)

let _other_lift f v1 t2 =
  exist_ (fun v2 ->
    v2 --- t2 ^^
    f v1 v2
  )

(* -------------------------------------------------------------------------- *)

(* Instantiation constraints. *)

let instance x v =
  (* In the constraint construction phase, create a write-once reference,
     and stick it into the constraint, for the solver to fill. *)
  let witnesses = WriteOnceRef.create() in
  CInstance (x, v, witnesses),
  fun env ->
    let decode = env in
    (* In the decoding phase, read this write-once reference, so as to
       obtain the list of witnesses. Decode them, and return them to
       the user. *)
    List.map decode (WriteOnceRef.get witnesses)

(* [instance_ x v] is equivalent to [instance x v <$$> ignore]. *)

let instance_ x v =
  let witnesses = WriteOnceRef.create() in
  CInstance (x, v, witnesses),
  fun _env ->
    (* In the decoding phase, there is nothing to do. *)
    ()

(* -------------------------------------------------------------------------- *)

(* Constraint abstractions. *)

(* The [CDef] form is so trivial that it deserves its own syntax. Viewing it
   as a special case of [CLet] would be more costly (by a constant factor). *)

let def x v (rc, k) =
  CDef (x, v, rc),
  k

(* The general form of [CLet] involves two constraints, the left-hand side and
   the right-hand side, yet it defines a *family* of constraint abstractions,
   bound the term variables [xs]. *)

let letn xs f1 (rc2, k2) =
  (* For each term variable [x], create a fresh type variable [v], as in
     [CExist]. Also, create an uninitialized scheme hook, which will receive
     the type scheme of [x] after the solver runs. *)
  let xvss = List.map (fun x ->
    x, fresh None, WriteOnceRef.create()
  ) xs in
  (* Pass the vector of type variables to the user-supplied function [f1],
     as in [CExist]. *)
  let vs = List.map (fun (_, v, _) -> v) xvss in
  let rc1, k1 = f1 vs in
  (* Create one more write-once reference, which will receive the list of
     all generalizable variables in the left-hand side. *)
  let generalizable_hook = WriteOnceRef.create() in
  (* Build a [CLet] constraint. *)
  CLet (xvss, rc1, rc2, generalizable_hook),
  fun env ->
    (* In the decoding phase, read the write-once references, *)
    let decode = env in
    let generalizable =
      List.map decode_variable (WriteOnceRef.get generalizable_hook)
    and ss =
      List.map (fun (_, _, scheme_hook) ->
        decode_scheme decode (WriteOnceRef.get scheme_hook)
      ) xvss
    in
    (* and return their values to the user, in addition to the values
       produced by the continuations [k1] and [k2]. *)
    ss, generalizable, k1 env, k2 env

(* The auxiliary function [single] asserts that its argument [xs] is a
   singleton list, and extracts its unique element. *)

let single xs =
  match xs with
  | [ x ] ->
      x
  | _ ->
      assert false

(* [let1] is a special case of [letn], where only one term variable is bound. *)

let let1 x f1 c2 =
  letn [ x ] (fun vs -> f1 (single vs)) c2 <$$>
  fun (ss, generalizable, v1, v2) -> (single ss, generalizable, v1, v2)

(* [let0] is a special case of [letn], where no term variable is bound, and
   the right-hand side is [CTrue]. We require using this form at the toplevel
   of every constraint. *)

let let0 c1 =
  letn [] (fun _ -> c1) (pure ()) <$$>
  fun (_, generalizable, v1, ()) -> (generalizable, v1)

(* -------------------------------------------------------------------------- *)

(* Correlation with the source code. *)

type range =
  Lexing.position * Lexing.position

let correlate range (rc, k) =
  CRange (range, rc), k

(* -------------------------------------------------------------------------- *)

(* Running a constraint. *)

(* The constraint [c] should have been constructed by [let0], otherwise we
   risk encountering variables that we cannot register. Recall that
   [G.register] must not be called unless [G.enter] has been invoked first. Of
   course, we could accept any old constraint from the user and silently wrap
   it in [let0], but then, what would we do with the toplevel quantifiers? *)

include struct
  [@@@warning "-4"] (* yes, I know the following pattern matching is fragile *)

let ok rc =
  match rc with
  | CLet (_, _, CTrue, _) ->
      (* The argument of [solve] should be constructed by [let0]. *)
      true
  | _ ->
      false

end

(* Solving, or running, a constraint. *)

exception Unbound = Lo.Unbound
exception Unify of range * O.ty * O.ty
exception Cycle of range * O.ty

let solve rectypes (rc, k) =
  assert (ok rc);
  begin try
    (* Solve the constraint. *)
    Lo.solve rectypes rc
  with
    (* Catch the unifier's exceptions and decode their arguments on the fly.
       This may be a waste of time, as the client may not need us to do this
       decoding, but this allows us to offer a nice & simple interface. Note
       that the cyclic decoder is required here, even if [rectypes] is [false],
       as recursive types can appear before the occurs check is successfully
       run. *)
  | Lo.Unify (range, v1, v2) ->
      let decode = new_decoder true (* cyclic decoder *) in
      raise (Unify (range, decode v1, decode v2))
  | Lo.Cycle (range, v) ->
      let decode = new_decoder true (* cyclic decoder *) in
      raise (Cycle (range, decode v))
  end;
  (* Create a suitable decoder. *)
  let decode = new_decoder rectypes in
  (* Invoke the client continuation. *)
  let env = decode in
  k env

end
