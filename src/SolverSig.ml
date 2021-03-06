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

(* This file defines some of the input signatures of the functor [Solver.Make]. *)

(* -------------------------------------------------------------------------- *)

(* The type of term variables is described to the solver as follows. *)

(* This signature is isomorphic to [Map.OrderedType] in OCaml's standard
   library. *)

module type TEVAR = sig

  (* The type of term variables. *)
  type tevar

  (* A total ordering. *)
  val compare: tevar -> tevar -> int

end

(* -------------------------------------------------------------------------- *)

(* The structure of types *after decoding* is described to the solver as
   follows. *)

module type OUTPUT = sig

  (* The user may choose a representation of decoded type variables. *)
  type tyvar

  (* The solver represents type variables as unique integer identifiers,
     and needs to be able to inject them into decoded type variables. *)
  val solver_tyvar : int -> tyvar

  (* The solver works with first-order types whose structure is defined by
     the type ['a structure], as in the signature [Unifier.STRUCTURE]. *)
  type 'a structure

  (* The user may choose a representation of decoded types. The solver
     constructs decoded types and never deconstructs them. So,
     the solver requires constructors for the type [ty]: see
     {!variable}, {!structure}, and {!mu} below. *)
  type ty

  (* [variable v] is a representation of the type variable [v] as a decoded
     type. In other words, [variable] is an injection of [tyvar] into [ty]. *)
  val variable: tyvar -> ty

  (* [structure t] turns [t], an application of type constructor to children
     of type [ty], into something of type [ty]. In other words, when [variable]
     and [structure] are combined, we see that [ty] must contain the fixed point
     of the functor [\X. tyvar + t X]. *)
  val structure: ty structure -> ty

  (* If [v] is a type variable and [t] is a type, then [mu v t] is a
     representation of the recursive type [mu v.t]. This function is used in
     one of two situations: 1- the occurs check is disabled, so the solver
     produces recursive types; or 2- the occurs check is enabled, but the
     types carried by the exceptions [Unify] and [Cycle] can still be cyclic,
     and one may wish to decode and display them. *)
  val mu: tyvar -> ty -> ty

  (* A decoded type scheme consists of a list of quantifiers and a body. *)
  type scheme = tyvar list * ty

end
