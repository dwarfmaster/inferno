open Client

(* -------------------------------------------------------------------------- *)

(* A wrapper over the client's [translate] function. We consider ill-typedness
   as normal, since our terms are randomly generated, so we translate the client
   exceptions to [None]. *)

let print_type ty =
  PPrint.(ToChannel.pretty 0.9 80 stdout (FPrinter.print_type ty ^^ hardline))

let translate t =
  try
    Some (Infer.translate t)
  with
  | Infer.Cycle ty ->
      if Config.verbose then begin
        Printf.fprintf stdout "Type error: a cyclic type arose.\n";
        print_type ty
      end;
      None
  | Infer.Unify (ty1, ty2) ->
      if Config.verbose then begin
        Printf.fprintf stdout "Type error: type mismatch.\n";
        Printf.fprintf stdout "Type error: mismatch between the type:\n";
        print_type ty1;
        Printf.fprintf stdout "and the type:\n";
        print_type ty2
      end;
      None

(* -------------------------------------------------------------------------- *)

(* Running all passes over a single ML term. *)

let test (t : ML.term) : bool =
  let log = Log.create_log() in
  let outcome =
    Log.attempt log
      "Type inference and translation to System F...\n"
      translate t
  in
  match outcome with
  | None ->
      (* This term is ill-typed. This is considered a normal outcome, since
         our terms can be randomly generated. *)
      false
  | Some (t : F.nominal_term) ->
      Log.log_action log (fun () ->
        Printf.printf "Formatting the System F term...\n%!";
        let doc = PPrint.(FPrinter.print_term t ^^ hardline) in
        Printf.printf "Pretty-printing the System F term...\n%!";
        PPrint.ToChannel.pretty 0.9 80 stdout doc
      );
      let t : F.debruijn_term =
        Log.attempt log
          "Converting the System F term to de Bruijn style...\n"
          F.translate t
      in
      let _ty : F.debruijn_type =
        Log.attempt log
          "Type-checking the System F term...\n"
          FTypeChecker.typeof t
      in
      (* Everything seems to be OK. *)
      if Config.verbose then
        Log.print_log log;
      true
