(lang dune 3.16)
(using melange 0.1)

(name react-rules-of-hooks-ppx)
(generate_opam_files true)

(dialect
 (name mlx)
 (implementation
  (extension mlx)
  (merlin_reader mlx)
  (format
   (run ocamlformat-mlx %{input-file}))
  (preprocess
   (run mlx-pp %{input-file}))))

(license MIT)
(maintainers "David Sancho <dsnxmoreno@gmail.com>")
(authors "David Sancho <dsnxmoreno@gmail.com>")
(source (github ml-in-barcelona/react-rules-of-hooks-ppx))

(package
 (name react-rules-of-hooks-ppx)
 (synopsis "ppx that validates the rules of React hooks")
 (depends
  (ocaml (>= 4.14))
  (ppxlib (>= 0.25.0))
  (reason (and :with-test (>= 3.10.0)))
  (melange :with-dev-setup)
  (ocamlformat :with-dev-setup)
  (ocaml-lsp-server :with-dev-setup)
  (mlx :with-dev-setup)
  (ocamlformat-mlx :with-dev-setup)
  (ocamlmerlin-mlx :with-dev-setup)
))
