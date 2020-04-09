open Client

(* A few manually constructed terms. *)

let x =
  ML.Var "x"

let y =
  ML.Var "y"

let id =
  ML.Abs ("x", x)

let delta =
  ML.Abs ("x", ML.App (x, x))

let deltadelta =
  ML.App (delta, delta)

let idid =
  ML.App (id, id)

let k =
  ML.Abs ("x", ML.Abs ("y", x))

let genid =
  ML.Let ("x", id, x)

let genidid =
  ML.Let ("x", id, ML.App (x, x))

let genkidid =
  ML.Let ("x", ML.App (k, id), ML.App (x, id))

let genkidid2 =
  ML.Let ("x", ML.App (ML.App (k, id), id), x)

let app_pair = (* ill-typed *)
  ML.App (ML.Pair (id, id), id)

let () =
  assert (Test.test idid);
  assert (Test.test genid);
  assert (Test.test genidid);
  assert (Test.test genkidid);
  assert (Test.test genkidid2)
