(lang dune 3.24)

(name remote_dev)

(generate_opam_files true)

(source
 (github y2k/remote-dev))

(authors "y2k <itwisterlx@gmail.com>")

(maintainers "y2k <itwisterlx@gmail.com>")

(license GPL-3.0-only)

(pin
 (url "git+https://github.com/y2k/ppx_deriving_yojson.git")
 (package (name ppx_deriving_yojson)))

(package
 (name remote_dev)
 (synopsis "Remote development tool with an Android client")
 (description
  "Browse Git worktrees from an Android client and send prompts to the locally installed Claude CLI.")
  (depends
    (ocaml (>= 5.3))
   eio
   eio_main
   httpun-eio
   yojson
   ppx_deriving_yojson)
 (tags
  ("development" "git" "android")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
