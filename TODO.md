* Apparently, the code builds with ocaml 4.04.0, but not 4.05.0 or later.
  Find out why.

* BUG? Activating `-rectypes` at the end of `Client.ml` causes `make main` to
  fail at line 275 of `Generalization.ml`.

* Think about the treatment of unreachable type variables. Could it
  be simplified? Do we really need a let form that binds several names at once?

* License.

* Headers.

* Working `Makefile`.

* The unifier could be more abstract: it doesn't need to know that the ranks
  are integers, does it? It could be just (abstract type of ranks, abstract
  min function). But then, why not merge the structure and rank fields
  (again)? Maybe because the unifier needs to know the difference between no
  structure and some structure.

* Think about type error reporting.
  - Keep track of type variable names.
  - Keep track of source code locations.
  - Possibly implement several solvers with different strategies.
  - Possibly continue after a unification error (just not unifying this
    particular pair of types) and report a list of mismatches at the end.

* Test families of terms of increasing size.

* Possible extensions:
  - support universal quantification
  - support rows
  - support the relaxed value restriction

* Note that although decoded types cannot be obtained until the whole constraint
  solving process is over, some information could be obtained earlier (e.g.,
  where the type abstractions and type applications are placed, as it becomes
  available during the run of the solver). Not sure if this is important, though.