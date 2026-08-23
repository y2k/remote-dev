(lang dune 3.24)

(name remote_dev)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Author Name <author@example.com>")

(maintainers "Maintainer Name <maintainer@example.com>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name remote_dev)
 (synopsis "A short synopsis")
 (description "A longer description")
  (depends
   ocaml
   eio
   eio_main
   httpun-eio
   yojson)
 (tags
  ("add topics" "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
