(lang dune 3.0)
(name react-rules-of-hooks-ppx)
(cram enable)
(generate_opam_files true)

(license MIT)
(maintainers "David Sancho <dsnxmoreno@gmail.com>")
(authors "David Sancho <dsnxmoreno@gmail.com>")
(source (github ml-in-barcelona/react-rules-of-hooks-ppx))

(package
 (name react-rules-of-hooks-ppx)
 (synopsis "PPX that validates the rules of React hooks")
 (depends
  (ocaml (>= 4.14))
  (ppxlib (>= 0.25.0))
  (reason (and :with-test (>= 3.10.0)))))
