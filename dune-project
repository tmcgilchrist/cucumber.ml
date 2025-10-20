(lang dune 3.2)
(name cucumber)
(generate_opam_files true)
(source (github cucumber/cucumber.ml))
(license MIT)
(authors "Christopher Guy Yocum")
(maintainers "cyocum@gmail.com")
(using menhir 2.0)

(package
 (name cucumber)
 (synopsis "Cucumber BDD for OCaml")
 (description "Cucumber BDD for OCaml using a pure OCaml Gherkin parser with OCaml 5.x effect handlers")
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
