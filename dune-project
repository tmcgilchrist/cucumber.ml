(lang dune 3.2)
(name cucumber)
(generate_opam_files true)
(source (github cucumber/cucumber.ml))
(license MIT)
(authors "Christopher Guy Yocum" "Tim McGilchrist")
(maintainers "cyocum@gmail.com" "timmcgil@gmail.com")
(using menhir 2.0)

(package
 (name cucumber)
 (synopsis "Cucumber BDD for OCaml")
 (description "Cucumber BDD for OCaml providing a pure OCaml or C-based Gherkin parser or using a pure OCaml Gherkin parser.
 Uses OCaml 5.x effect handlers for running steps.")
 (depends
  (ocaml (>= 5.0.0))
  (re (>= 1.9.0))
  (cmdliner (>= 1.1))
  (menhir (>= 20180523))
  (sedlex (>= 2.0))
  (ppxlib (>= 0.32.0))
  (alcotest :with-test)))

(package
 (name ppx_cucumber)
 (synopsis "PPX extension for Cucumber step definitions")
 (description "PPX rewriter providing let%given, let%when, and let%then syntax for step definitions")
 (depends
  (ocaml (>= 5.0.0))
  (ppxlib (>= 0.32.0))
  (cucumber (= :version))))

(package
 (name cucumber-c)
 (synopsis "C-based Gherkin parser for Cucumber.ml")
 (description "Provides a parser module using the gherkin-c library via Ctypes.Foreign bindings.
Use with Cucumber.Make(Cucumber_c.Parser) to create a Cucumber instance using the C parser instead of the pure OCaml parser.")
 (depends
  (ocaml (>= 5.0.0))
  (cucumber (= :version))
  (ctypes (>= 0.20.0))
  (ctypes-foreign (>= 0.20.0))))
