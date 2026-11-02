# Tasks

## 1. Fix test dependencies

- [x] 1.1 Remove `eio_main` from the `test_folder_tabs` stanza in `test/dune`; verify with `make test`.
- [x] 1.2 Review the implementation diff and fix all obvious or important findings; verify only the unused dependency was removed and `git diff --check` passes.

## Workflow follow-up

- Archive the change after verification; no delta specs need syncing.
- Squash unpublished commits and push as requested.
