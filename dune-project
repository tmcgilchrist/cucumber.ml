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
 (description "Cucumber BDD for OCaml using a pure OCaml Gherkin parser")
 (depends
  (re (>= 1.9.0))
  (cmdliner (>= 1.1))
  (menhir (>= 20180523))
  (sedlex (>= 2.0))
  (alcotest :with-test)))
